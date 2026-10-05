import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../data/seed.dart';
import '../data/signature_options.dart';
import '../data/strings.dart';
import '../models/activity_item.dart';
import '../models/recipe.dart';
import '../providers/robot_provider.dart';
import '../repositories/data_repository.dart';
import '../services/motion_engine.dart';
import '../sim/sim_host.dart';
import '../widgets/app_shell.dart';
import '../widgets/gray_box.dart';
import 'signature_screen.dart';

/// 08-1 로봇 — 시드 더미. 모션 시그니처만 실제 값이고 08-2 로 들어간다.
class RobotScreen extends StatelessWidget {
  const RobotScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final robot = context.watch<RobotProvider>();
    const info = kRobotSeedInfo;

    return AppShell(
      title: S.robotTitle,
      onBack: () => Navigator.pop(context),
      child: ListView(
        children: [
          const GraySectionLabel('Status'),
          _Card(children: [
            _Row(label: robot.robot.model, value: info.connection),
            _Row(label: 'Network', value: info.network),
            _Row(label: 'Power', value: info.power),
          ]),

          const GraySectionLabel('Personality mode'),
          _Card(
            children: [
              for (final mode in info.personalityModes)
                ListTile(
                  dense: true,
                  title: Text(mode),
                  trailing: mode == info.activeMode
                      ? const Icon(Icons.check, size: 18, color: Gray.accent)
                      : null,
                  // 더미 — 탭 반응만 (PRD §2 08 은 UI 그대로).
                  onTap: () => showGrayToast(context, '$mode mode'),
                ),
            ],
          ),

          const GraySectionLabel(S.robotMotionSignature),
          _Card(children: [
            ListTile(
              title: const Text(S.robotMotionSignature),
              subtitle: Text(signatureSummary(robot.signature)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, AppRoutes.signatureReset),
            ),
          ]),

          const GraySectionLabel('More'),
          _Card(children: [
            ListTile(
              title: const Text(S.robotActivityHistory),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, AppRoutes.robotActivity),
            ),
            ListTile(
              title: const Text(S.robotMyRobots),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, AppRoutes.robotList),
            ),
            ListTile(
              title: Text(fill(S.robotFirmwareReady, {'version': info.firmwareAvailable})),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, AppRoutes.firmware),
            ),
          ]),
          const SizedBox(height: 24),
        ],
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
