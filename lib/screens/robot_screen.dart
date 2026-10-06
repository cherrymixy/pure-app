import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../data/robot_modes.dart';
import '../data/seed.dart';
import '../data/signature_options.dart';
import '../data/strings.dart';
import '../models/activity_item.dart';
import '../models/recipe.dart';
import '../providers/robot_provider.dart';
import '../repositories/data_repository.dart';
import '../services/motion_engine.dart';
import '../sim/sim_host.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_icon.dart';
import '../widgets/app_shell.dart';
import '../widgets/gray_box.dart';
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
                  _MenuCard(
                    rows: [
                      _MenuRow(
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
                  _MenuCard(
                    rows: [
                      _MenuRow(
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
                      _MenuRow(
                        icon: AppIconName.robot,
                        label: S.robotMyRobots,
                        trailingText: '${info.myRobots.length}',
                        onTap: () =>
                            Navigator.pushNamed(context, AppRoutes.robotList),
                      ),
                      _MenuRow(
                        icon: AppIconName.download,
                        label: 'Firmware update',
                        value: fill(S.robotVersionReady, {
                          'version': info.firmwareAvailable,
                        }),
                        valueIsBrand: true,
                        onTap: () =>
                            Navigator.pushNamed(context, AppRoutes.firmware),
                      ),
                      _MenuRow(
                        icon: AppIconName.help,
                        label: S.robotHelp,
                        // 전시용 더미 — 도움말 문서는 없다.
                        onTap: () => showGrayToast(context, S.robotHelp),
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
                      // 시안은 16 SemiBold 지만 Pretendard 를 400·500 만 넣어 뒀다.
                      style: AppTextStyles.bodyLStrong,
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

/// 시안 `Frame` (`488:4740` · `488:4747`) — 흰 카드 radius 20, 위아래 4.
class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.rows});
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
        child: Column(children: rows),
      );
}

/// 메뉴 한 줄 — 왼쪽 16 / 오른쪽 14 / 위아래 14, 간격 12, 꺾쇠 18.
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.label,
    required this.onTap,
    this.icon,
    this.iconSize = 18,
    this.value,
    this.trailingText,
    this.valueIsBrand = false,
    this.labelOnTop = false,
  });

  final String label;
  final VoidCallback onTap;
  final AppIconName? icon;
  final double iconSize;

  /// 라벨 아래(또는 위) 한 줄.
  final String? value;

  /// 꺾쇠 왼쪽 작은 글자 (로봇 수 등).
  final String? trailingText;

  final bool valueIsBrand;

  /// 모션 시그니처 행처럼 작은 라벨이 위, 값이 아래인가.
  final bool labelOnTop;

  @override
  Widget build(BuildContext context) {
    final small = AppTextStyles.bodyS.copyWith(
      color: valueIsBrand ? AppColors.textBrand : AppColors.textSecondary,
    );
    final big = AppTextStyles.bodyM.copyWith(fontWeight: FontWeight.w500);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x16,
          14,
          14,
          14,
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              SizedBox(
                width: 36,
                height: 36,
                child: Center(child: AppIcon(icon!, size: iconSize)),
              ),
              const SizedBox(width: AppSpacing.x12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: labelOnTop
                    ? [
                        Text(label, style: small),
                        const SizedBox(height: 2),
                        Text(value ?? '', style: big),
                      ]
                    : [
                        Text(label, style: big),
                        if (value != null) ...[
                          const SizedBox(height: 2),
                          Text(value!, style: small),
                        ],
                      ],
              ),
            ),
            if (trailingText != null) ...[
              const SizedBox(width: AppSpacing.x8),
              Text(
                trailingText!,
                style: AppTextStyles.labelS.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(width: AppSpacing.x12),
            const AppIcon(
              AppIconName.chevron,
              size: 18,
              color: AppColors.iconSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// 08-2 시그니처 재설정 — 항목을 탭하면 05 편집 모드로 간다.
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

  @override
  Widget build(BuildContext context) {
    final robot = context.watch<RobotProvider>();
    final s = robot.signature;

    void edit(SignatureStep step) => Navigator.pushNamed(
          context,
          AppRoutes.signature,
          arguments: SignatureArgs(edit: true, focus: step),
        );

    return AppShell(
      title: S.robotMotionSignature,
      onBack: () => Navigator.pop(context),
      child: ListView(
        children: [
          const SizedBox(height: 8),
          _Card(children: [
            ListTile(
              title: const Text('Personality'),
              subtitle: Text(personalityFor(s).label),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => edit(SignatureStep.personality),
            ),
            ListTile(
              title: const Text('How it comes to you'),
              subtitle: Text(relationshipFor(s.relationship).label),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => edit(SignatureStep.relationship),
            ),
            ListTile(
              title: const Text('How it moves'),
              subtitle: Text(expressionFor(s.expression).label),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => edit(SignatureStep.expression),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _preview(context),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text(S.robotPreviewOnPurebot),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    final ok = await showGrayConfirm(
                      context,
                      title: S.robotResetConfirm,
                      confirmLabel: S.robotResetToDefault,
                      destructive: false,
                    );
                    if (!ok || !context.mounted) return;
                    await context.read<RobotProvider>().resetSignature();
                    if (!context.mounted) return;
                    showGrayToast(context, S.signatureSaved);
                  },
                  child: const Text(S.robotResetToDefault),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 08-3 로봇 목록 — 시드 더미.
class RobotListScreen extends StatelessWidget {
  const RobotListScreen({super.key});

  @override
  Widget build(BuildContext context) => AppShell(
        title: S.robotMyRobots,
        onBack: () => Navigator.pop(context),
        child: ListView(
          children: [
            const SizedBox(height: 8),
            _Card(children: [
              for (final r in kRobotSeedInfo.myRobots)
                ListTile(
                  title: Text(r),
                  trailing: const Icon(Icons.check, size: 18, color: Gray.accent),
                ),
            ]),
          ],
        ),
      );
}

/// 08-4 펌웨어 — Update now 를 누르면 더미 진행 후 완료 토스트.
class FirmwareScreen extends StatefulWidget {
  const FirmwareScreen({super.key});

  @override
  State<FirmwareScreen> createState() => _FirmwareScreenState();
}

class _FirmwareScreenState extends State<FirmwareScreen> {
  double? _progress;
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
        setState(() => _progress = null);
        showGrayToast(context, S.robotUpdateDone);
        return;
      }
      setState(() => _progress = next);
    });
  }

  @override
  Widget build(BuildContext context) {
    const info = kRobotSeedInfo;
    final running = _progress != null;

    return AppShell(
      title: 'Firmware',
      onBack: () => Navigator.pop(context),
      child: ListView(
        children: [
          const SizedBox(height: 8),
          _Card(children: [
            _Row(label: 'Current', value: info.firmwareCurrent),
            _Row(label: 'Available', value: info.firmwareAvailable),
          ]),
          Padding(
            padding: const EdgeInsets.all(16),
            child: running
                ? Column(
                    children: [
                      LinearProgressIndicator(value: _progress),
                      const SizedBox(height: 8),
                      Text('${((_progress ?? 0) * 100).round()}%',
                          style: const TextStyle(fontSize: 12, color: Gray.dim)),
                    ],
                  )
                : FilledButton(
                    onPressed: _start,
                    child: const Text(S.robotUpdateNow),
                  ),
          ),
        ],
      ),
    );
  }
}

/// 08-5 행동 기록 — All / Auto / By you.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  ActivityTrigger? _filter;

  @override
  Widget build(BuildContext context) {
    final all = context.read<DataRepository>().activity;
    final items =
        _filter == null ? all : all.where((a) => a.trigger == _filter).toList();

    return AppShell(
      title: S.robotActivityHistory,
      onBack: () => Navigator.pop(context),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(
              children: [
                for (final f in <(String, ActivityTrigger?)>[
                  (S.robotActivityAll, null),
                  (S.robotActivityAuto, ActivityTrigger.auto),
                  (S.robotActivityByYou, ActivityTrigger.byYou),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GrayChip(
                      label: f.$1,
                      selected: _filter == f.$2,
                      onTap: () => setState(() => _filter = f.$2),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const GrayEmptyState(title: 'Nothing yet', body: '')
                : ListView(
                    children: [
                      for (final a in items)
                        ListTile(
                          leading: Icon(
                            a.trigger == ActivityTrigger.auto
                                ? Icons.bolt
                                : Icons.touch_app_outlined,
                            size: 18,
                            color: a.trigger == ActivityTrigger.auto
                                ? Gray.accent
                                : Gray.dim,
                          ),
                          title: Text(a.motionName),
                          subtitle: Text(
                            [
                              if (a.situationLabel != null) a.situationLabel!,
                              _ago(a.at),
                            ].join(' · '),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}

// ------------------------------------------------------------------ 공용 조각

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Gray.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Gray.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        title: Text(label, style: const TextStyle(fontSize: 14)),
        trailing: Text(value, style: const TextStyle(fontSize: 13, color: Gray.dim)),
      );
}
