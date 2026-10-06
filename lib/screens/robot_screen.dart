import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../data/robot_devices.dart';
import '../data/robot_modes.dart';
import '../data/seed.dart';
import '../data/signature_options.dart';
import '../data/strings.dart';
import '../models/activity_item.dart';
import '../models/recipe.dart';
import '../providers/library_provider.dart';
import '../providers/robot_provider.dart';
import '../repositories/data_repository.dart';
import '../services/motion_engine.dart';
import '../sim/sim_controller.dart';
import '../sim/sim_host.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_icon.dart';
import '../widgets/pure_button.dart';
import '../widgets/pure_chip.dart';
import '../widgets/pure_list.dart';
import '../widgets/pure_empty.dart';
import '../widgets/pure_sheet.dart';
import '../widgets/pure_toast.dart';
import '../widgets/pure_sidebar.dart';
import '../widgets/pure_top_bar.dart';
import 'signature_screen.dart';

/// 08-1 로봇 — Figma `488:4679`.
///
/// 시안 값: 로봇 카드 250(radius 28) / 모드 카드(radius 24) / 모션 시그니처 행 /
/// 메뉴 넷. 카드 사이 12, 좌우 24.
///
/// 모드 카드(Family · Partner · Focus)는 **보이기만 하는 더미**다 — PRD 에 없는
/// 개념이라 동작은 만들지 않았다 (승아 결정, `data/robot_modes.dart`).
class RobotScreen extends StatelessWidget {
  const RobotScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final robot = context.watch<RobotProvider>();
    const info = kRobotSeedInfo;
    // 메뉴에 마지막 활동 한 줄을 보여 준다 (시안 `488:4753`).
    final activity = context.watch<DataRepository>().activity;
    final last = activity.isEmpty ? null : activity.first;

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      drawer: const PureSidebar(),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PureMenuBar(title: S.robotTitle),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x24,
                  12,
                  AppSpacing.x24,
                  AppSpacing.x24,
                ),
                children: [
                  _RobotCard(
                    name: robot.robot.name,
                    model: robot.robot.model,
                    connection: info.connection,
                    network: info.network,
                    power: info.power,
                  ),
                  const SizedBox(height: AppSpacing.x12),
                  const _ModesCard(),
                  const SizedBox(height: AppSpacing.x12),
                  PureCard(
                    rows: [
                      PureRow(
                        label: S.robotMotionSignature,
                        value: signatureLine(robot.signature),
                        labelOnTop: true,
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.signatureReset,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.x12),
                  PureCard(
                    rows: [
                      PureRow(
                        icon: AppIconName.board,
                        iconSize: 20,
                        label: S.robotActivityHistory,
                        value: last == null
                            ? null
                            : fill(S.robotLastActivity, {
                                'name': last.motionName,
                                'time': _clock(last.at),
                                'how': last.trigger == ActivityTrigger.auto
                                    ? 'auto'
                                    : 'by you',
                              }),
                        onTap: () =>
                            Navigator.pushNamed(context, AppRoutes.robotActivity),
                      ),
                      PureRow(
                        icon: AppIconName.robot,
                        label: S.robotMyRobots,
                        trailingText: '${info.myRobots.length}',
                        onTap: () =>
                            Navigator.pushNamed(context, AppRoutes.robotList),
                      ),
                      PureRow(
                        icon: AppIconName.download,
                        label: 'Firmware update',
                        value: fill(S.robotVersionReady, {
                          'version': info.firmwareAvailable,
                        }),
                        valueIsBrand: true,
                        onTap: () =>
                            Navigator.pushNamed(context, AppRoutes.firmware),
                      ),
                      PureRow(
                        icon: AppIconName.help,
                        label: S.robotHelp,
                        // 전시용 더미 — 도움말 문서는 없다.
                        onTap: () => showPureToast(context, S.robotHelp),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "10:58 AM" 꼴.
String _clock(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// 시안 `Robot card` (`488:4682`) — 흰 카드 250, radius 28.
class _RobotCard extends StatelessWidget {
  const _RobotCard({
    required this.name,
    required this.model,
    required this.connection,
    required this.network,
    required this.power,
  });

  final String name;
  final String model;
  final String connection;
  final String network;
  final String power;

  @override
  Widget build(BuildContext context) => Container(
        height: 250,
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // 시안: 253.33 × 190, 가운데에서 오른쪽으로 73 치우쳐 걸친다.
            Positioned(
              top: 30,
              left: 123,
              child: Image.asset(
                'assets/images/robot_hero.png',
                width: 253.33,
                height: 190,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              left: AppSpacing.x20,
              top: AppSpacing.x20,
              child: Text(name, style: AppTextStyles.titleM),
            ),
            Positioned(
              left: AppSpacing.x20,
              top: 50,
              child: Text(
                model,
                style: AppTextStyles.bodyS.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Positioned(
              left: AppSpacing.x20,
              top: 78,
              child: _StatusBadge(label: connection),
            ),
            Positioned(
              left: AppSpacing.x20,
              top: 192,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _IconLine(icon: AppIconName.wifi, text: network),
                  const SizedBox(height: 6),
                  _IconLine(icon: AppIconName.plug, text: power),
                ],
              ),
            ),
          ],
        ),
      );
}

/// 시안 `Status` (`488:4686`) — `bg/surface-muted`, 왼쪽 10 / 오른쪽 12 / 위아래 5,
/// radius 14, 세이지 점 7, 글자 12 Medium.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(10, 5, AppSpacing.x12, 5),
        decoration: BoxDecoration(
          color: AppColors.bgSurfaceMuted,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: AppColors.bgBrand,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});
  final AppIconName icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: 14, color: AppColors.iconSecondary),
          const SizedBox(width: 6),
          Text(
            text,
            style: AppTextStyles.bodyS.copyWith(color: AppColors.textSecondary),
          ),
        ],
      );
}

/// 시안 `Modes` (`488:4704`) — 흰 카드 radius 24, 위 20 / 아래 12 / 좌우 20, 간격 14.
/// 보이기만 하는 더미다.
class _ModesCard extends StatelessWidget {
  const _ModesCard();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x20,
          AppSpacing.x20,
          AppSpacing.x20,
          AppSpacing.x12,
        ),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        S.robotTriggerNow,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textBrand,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x4),
                      Text(
                        kTriggerNow,
                        style: AppTextStyles.titleM.copyWith(fontSize: 20),
                      ),
                    ],
                  ),
                ),
                Text(
                  S.meEdit,
                  style: AppTextStyles.bodyS.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            for (final mode in kRobotModes) ...[
              const SizedBox(height: 14),
              _ModeRow(mode: mode),
            ],
          ],
        ),
      );
}

class _ModeRow extends StatelessWidget {
  const _ModeRow({required this.mode});
  final RobotMode mode;

  @override
  Widget build(BuildContext context) => Opacity(
        // 시안: 켜지지 않은 모드는 흐리다.
        opacity: mode.active ? 1 : 0.55,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              SvgPicture.asset(mode.aura, width: 48, height: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      mode.name,
                      // 시안 16 SemiBold.
                      style: AppTextStyles.bodyLStrong.copyWith(
                        fontWeight: AppTextStyles.semiBold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mode.detail,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 12,
                        color: mode.active
                            ? AppColors.textBrand
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              for (final chip in mode.chips) ...[
                const SizedBox(width: AppSpacing.x4),
                _ModeChip(chip: chip),
              ],
            ],
          ),
        ),
      );
}

/// 시안 `Chip` (`488:4716`) — 좌우 8 / 위아래 4, radius 8, 글자 11 Medium.
class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.chip});
  final ModeChip chip;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (chip.tone) {
      ModeChipTone.brandSubtle => (AppColors.bgBrandSubtle, AppColors.textBrand),
      ModeChipTone.brand => (AppColors.bgBrand, AppColors.textOnBrand),
      ModeChipTone.muted => (AppColors.bgSurfaceMuted, AppColors.textPrimary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x8,
        vertical: AppSpacing.x4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        chip.label,
        style: AppTextStyles.caption.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: fg,
        ),
      ),
    );
  }
}

/// 08-2 시그니처 재설정 — 항목을 탭하면 05 편집 모드로 간다.
/// 08-2 모션 시그니처 — Figma `481:3480`.
///
/// 시안 값: 큰 제목 26 Medium / 설명 15 / 네 줄 카드(radius 20) /
/// 아래 "Reset to default" 와 Primary 버튼. 줄을 누르면 05 편집 모드로 간다.
class SignatureResetScreen extends StatelessWidget {
  const SignatureResetScreen({super.key});

  Future<void> _preview(BuildContext context) async {
    final sim = SimHost.controllerOf(context);
    final params = MotionEngine.signatureToParams(
      context.read<RobotProvider>().signature,
    );
    final recipe = MotionEngine.applySignature(
      Recipe(steps: [
        if (params.greetPrefix != null) RecipeStep(behavior: params.greetPrefix!),
        const RecipeStep(behavior: 'greet'),
      ]),
      params,
    );
    try {
      await sim.playRecipe(recipe.toJson());
      await sim.setFace('smile');
    } catch (_) {}
  }

  Future<void> _reset(BuildContext context) async {
    final ok = await showPureConfirm(
      context,
      title: S.robotResetConfirm,
      confirmLabel: S.robotResetToDefault,
    );
    if (!ok || !context.mounted) return;
    await context.read<RobotProvider>().resetSignature();
    if (!context.mounted) return;
    showPureToast(context, S.signatureSaved);
  }

  @override
  Widget build(BuildContext context) {
    final robot = context.watch<RobotProvider>();
    final s = robot.signature;

    void edit(SignatureStep step) => Navigator.pushNamed(
          context,
          AppRoutes.signature,
          arguments: SignatureArgs(edit: true, focus: step),
        );

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PureBackBar(title: S.robotMotionSignature),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x24,
                  18,
                  AppSpacing.x24,
                  0,
                ),
                children: [
                  Text(
                    S.robotSignatureTitle,
                    style: AppTextStyles.titleL.copyWith(fontSize: 26),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    S.robotSignatureBody,
                    style: AppTextStyles.bodyM.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x24),
                  PureCard(
                    rows: [
                      PureRow(
                        labelOnTop: true,
                        label: S.robotSignaturePersonality,
                        value: fill(S.robotSignaturePersonalityValue, {
                          'lively': s.lively,
                          'bold': s.bold,
                        }),
                        onTap: () => edit(SignatureStep.personality),
                      ),
                      PureRow(
                        labelOnTop: true,
                        label: S.robotSignatureRelationship,
                        value: relationshipFor(s.relationship).label,
                        onTap: () => edit(SignatureStep.relationship),
                      ),
                      PureRow(
                        labelOnTop: true,
                        label: S.robotSignatureMotion,
                        value: fill(S.robotSignatureMotionValue, {
                          'motion': expressionFor(s.expression).label,
                          'richness': s.richness,
                        }),
                        onTap: () => edit(SignatureStep.expression),
                      ),
                      // 소리는 아직 없는 기능이다 — 시안에 있어 자리만 둔다.
                      PureRow(
                        labelOnTop: true,
                        label: S.robotSignatureSound,
                        value: S.robotSignatureSoundValue,
                        onTap: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x24,
                0,
                AppSpacing.x24,
                18,
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => _reset(context),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        S.robotResetToDefault,
                        style: AppTextStyles.labelM.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: PureButton(
                      label: S.robotPreviewOnPurebot,
                      onPressed: () => _preview(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 08-3 내 로봇 — Figma `481:3575`.
///
/// 시안 값: 기기 목록 카드 / `Add a robot` 카드 / 빨간 "Remove … from account".
/// 전부 더미다 — 전시에는 로봇이 하나뿐이다.
class RobotListScreen extends StatelessWidget {
  const RobotListScreen({super.key});

  Future<void> _remove(BuildContext context, String name) async {
    final ok = await showPureConfirm(
      context,
      title: fill(S.robotRemoveTitle, {'name': name}),
      body: S.robotRemoveBody,
      confirmLabel: S.robotRemoveAction,
    );
    if (!ok || !context.mounted) return;
    // 더미 — 실제로 지우지는 않는다.
    showPureToast(context, S.toastDeleted);
  }

  @override
  Widget build(BuildContext context) {
    final primary = kRobotDevices.first;

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PureBackBar(title: S.robotMyRobots),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x24,
                  18,
                  AppSpacing.x24,
                  AppSpacing.x24,
                ),
                children: [
                  PureCard(
                    rows: [
                      for (final d in kRobotDevices)
                        PureRow(
                          icon: AppIconName.robot,
                          label: d.name,
                          value: fill(S.robotDeviceLine, {
                            'model': d.model,
                            'status': d.status,
                          }),
                          valueIsBrand: d.connected,
                          trailingIcon:
                              d.connected ? AppIconName.check : null,
                          showChevron: false,
                          onTap: () {},
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.x16),
                  PureCard(
                    rows: [
                      PureRow(
                        icon: AppIconName.plusRow,
                        label: S.robotAddRobot,
                        // 더미 — 기기를 더 붙일 일은 없다.
                        onTap: () => showPureToast(context, S.robotAddRobot),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                  PureCard(
                    rows: [
                      PureRow(
                        label: fill(S.robotRemoveFromAccount, {
                          'name': primary.name,
                        }),
                        danger: true,
                        showChevron: false,
                        onTap: () => _remove(context, primary.name),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 08-4 펌웨어 — Figma `481:3832`(준비) · `481:3881`(진행) · `481:4161`(최신).
///
/// 시안 값: 버전 카드(흰색 radius 24, 패딩 22, 간격 8) / 안내 한 단락 /
/// 아래 Primary 버튼. 전시용이라 실제로 내려받지는 않고 진행 막대만 돈다.
class FirmwareScreen extends StatefulWidget {
  const FirmwareScreen({super.key});

  @override
  State<FirmwareScreen> createState() => _FirmwareScreenState();
}

class _FirmwareScreenState extends State<FirmwareScreen> {
  double? _progress;
  bool _done = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() => _progress = 0);
    _timer = Timer.periodic(const Duration(milliseconds: 180), (t) {
      if (!mounted) return t.cancel();
      final next = (_progress ?? 0) + 0.04;
      if (next >= 1) {
        t.cancel();
        setState(() {
          _progress = null;
          _done = true;
        });
        showPureToast(context, S.robotUpdateDone);
        return;
      }
      setState(() => _progress = next);
    });
  }

  @override
  Widget build(BuildContext context) {
    const info = kRobotSeedInfo;
    final robot = context.watch<RobotProvider>();
    final running = _progress != null;

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PureBackBar(title: S.robotFirmwareTitle),
            Expanded(
              child: running
                  ? _Updating(progress: _progress!, name: robot.robot.name)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.x24,
                        18,
                        AppSpacing.x24,
                        AppSpacing.x24,
                      ),
                      children: [
                        if (_done)
                          _UpToDateCard(
                            name: robot.robot.name,
                            version: info.firmwareAvailable,
                          )
                        else
                          _VersionCard(
                            version: info.firmwareAvailable,
                            current: info.firmwareCurrent,
                          ),
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            _done
                                ? S.robotFirmwareUpToDateNote
                                : S.robotFirmwareHint,
                            style: AppTextStyles.bodyS.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            if (!running)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x24,
                  0,
                  AppSpacing.x24,
                  18,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: PureButton(
                    label: S.robotUpdateNow,
                    // 최신이면 누를 것이 없다 (시안 08-4.up_to_date).
                    onPressed: _done ? null : _start,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 시안 `Version` (`481:3836`).
class _VersionCard extends StatelessWidget {
  const _VersionCard({required this.version, required this.current});

  final String version;
  final String current;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              fill(S.robotFirmwareVersion, {'version': version}),
              style: AppTextStyles.titleM.copyWith(fontSize: 24),
            ),
            const SizedBox(height: AppSpacing.x8),
            Text(
              fill(S.robotFirmwareMeta, {
                'current': current,
                'size': S.robotFirmwareSize,
              }),
              style: AppTextStyles.bodyS.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.x8),
            Text(
              S.robotFirmwareWhatsNew,
              style: AppTextStyles.labelM.copyWith(height: 22 / 14),
            ),
            for (final note in S.robotFirmwareNotes)
              Text(
                '\u2022 $note',
                style: AppTextStyles.labelM.copyWith(
                  fontWeight: FontWeight.w400,
                  height: 22 / 14,
                ),
              ),
          ],
        ),
      );
}

/// 시안 `08-4.up_to_date` (`481:4161`).
class _UpToDateCard extends StatelessWidget {
  const _UpToDateCard({required this.name, required this.version});

  final String name;
  final String version;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              fill(S.robotFirmwareUpToDate, {'name': name}),
              style: AppTextStyles.titleM.copyWith(fontSize: 24),
            ),
            const SizedBox(height: AppSpacing.x8),
            Text(
              fill(S.robotFirmwareChecked, {'version': version}),
              style: AppTextStyles.bodyS.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
}

/// 시안 `08-4.updating` (`481:3881`) — 가운데 문구 + 진행 막대 + 바닥 안내.
class _Updating extends StatelessWidget {
  const _Updating({required this.progress, required this.name});

  final double progress;
  final String name;

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).round();
    final left = progress > 0.5 ? '1 min' : '2 min';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x24),
      child: Column(
        children: [
          const Spacer(flex: 3),
          Text(
            fill(S.robotFirmwareUpdating, {'name': name}),
            textAlign: TextAlign.center,
            style: AppTextStyles.titleM.copyWith(fontSize: 24),
          ),
          const SizedBox(height: AppSpacing.x24),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  Container(color: AppColors.bgSurface),
                  FractionallySizedBox(
                    widthFactor: progress.clamp(0, 1),
                    child: Container(color: AppColors.bgBrand),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x12),
          Text(
            fill(S.robotFirmwareProgress, {
              'percent': percent,
              'left': left,
            }),
            style: AppTextStyles.bodyS.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(flex: 4),
          Text(
            S.robotFirmwareDontUnplug,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyS.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

/// 08-5 활동 기록 — Figma `481:4269`.
///
/// 시안 값: 뒤로 + 제목 17 Medium / 필터 칩 S(32) / 날짜별 그룹 카드(radius 20) /
/// 항목은 시각 60 + 이름·설명 + 재생 36. 맨 아래 "Kept for 30 days".
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  ActivityTrigger? _filter;
  String? _playingId;
  StreamSubscription<SimEvent>? _sub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _sub = SimHost.controllerOf(context).events.listen((e) {
        if (e is SimEnded && mounted) setState(() => _playingId = null);
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// 저장된 모션이면 다시 틀어 준다. 없으면 아무 일도 하지 않는다.
  Future<void> _replay(ActivityItem a) async {
    final motion = context
        .read<LibraryProvider>()
        .all
        .where((m) => m.name == a.motionName)
        .firstOrNull;
    if (motion == null) {
      showPureToast(context, S.errorSimFailed);
      return;
    }
    setState(() => _playingId = a.id);
    try {
      final sim = SimHost.controllerOf(context);
      await sim.playRecipe(motion.spec.recipe.toJson());
      await sim.setFace(motion.spec.face);
    } catch (_) {
      if (mounted) setState(() => _playingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = context.watch<DataRepository>().activity;
    final items =
        _filter == null ? all : all.where((a) => a.trigger == _filter).toList();

    // 오늘 / 어제 / 그 전으로 묶는다 (시안은 두 덩어리를 보여 준다).
    final now = DateTime.now();
    final groups = <String, List<ActivityItem>>{};
    for (final a in items) {
      groups.putIfAbsent(_groupLabel(a.at, now), () => []).add(a);
    }

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PureBackBar(title: S.robotActivityHistory),
            // 시안: 상단바 아래 14, 칩 32, 그 아래 24.
            const SizedBox(height: 14),
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x24),
                children: [
                  for (final f in <(String, ActivityTrigger?)>[
                    (S.robotActivityAll, null),
                    (S.robotActivityAuto, ActivityTrigger.auto),
                    (S.robotActivityByYou, ActivityTrigger.byYou),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.x8),
                      child: PureChip(
                        label: f.$1,
                        size: PureChipSize.s,
                        state: _filter == f.$2
                            ? PureChipState.selected
                            : PureChipState.normal,
                        onTap: () => setState(() => _filter = f.$2),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.x24),
            Expanded(
              child: items.isEmpty
                  ? const PureNoResults(
                      title: 'Nothing yet',
                      body: 'Purebot has not moved today.',
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.x24,
                        0,
                        AppSpacing.x24,
                        AppSpacing.x24,
                      ),
                      children: [
                        for (final entry in groups.entries) ...[
                          Text(
                            entry.key,
                            style: AppTextStyles.labelS.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.x12),
                          _ActivityGroup(
                            items: entry.value,
                            playingId: _playingId,
                            onReplay: _replay,
                          ),
                          const SizedBox(height: AppSpacing.x12),
                        ],
                        Text(
                          S.activityKept,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static String _groupLabel(DateTime t, DateTime now) {
    final day = DateTime(t.year, t.month, t.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return S.chatHistoryToday;
    if (diff == 1) return S.activityYesterday;
    return S.chatHistoryEarlier;
  }
}

/// 날짜 한 덩어리 — 흰 카드 radius 20, 위아래 4.
class _ActivityGroup extends StatelessWidget {
  const _ActivityGroup({
    required this.items,
    required this.playingId,
    required this.onReplay,
  });

  final List<ActivityItem> items;
  final String? playingId;
  final void Function(ActivityItem) onReplay;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
        child: Column(
          children: [
            for (final a in items)
              _ActivityRow(
                item: a,
                playing: playingId == a.id,
                onReplay: () => onReplay(a),
              ),
          ],
        ),
      );
}

/// 항목 한 줄 — 좌우 16 / 위아래 14, 간격 12, 시각 폭 60, 재생 36.
class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.item,
    required this.playing,
    required this.onReplay,
  });

  final ActivityItem item;
  final bool playing;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    final small = AppTextStyles.caption.copyWith(
      fontSize: 12,
      color: AppColors.textSecondary,
    );

    final line = item.trigger == ActivityTrigger.auto
        ? (item.situationLabel == null
            ? S.activityAutoPlain
            : fill(S.activityAutoLine, {'situation': item.situationLabel}))
        : S.activityByYouLine;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x16,
        vertical: 14,
      ),
      child: Row(
        children: [
          SizedBox(width: 60, child: Text(_clock(item.at), style: small)),
          const SizedBox(width: AppSpacing.x12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.motionName,
                  // 시안 15 SemiBold.
                  style: AppTextStyles.bodyM.copyWith(
                    fontWeight: AppTextStyles.semiBold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(line, style: small),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x12),
          Material(
            color: AppColors.bgSurfaceMuted,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onReplay,
              child: SizedBox(
                width: 36,
                height: 36,
                child: Center(
                  child: playing
                      ? const Icon(Icons.stop, size: 16)
                      : const AppIcon(AppIconName.playThumb, size: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
