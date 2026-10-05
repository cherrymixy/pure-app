import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../data/seed.dart';
import '../data/strings.dart';
import '../providers/library_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/robot_provider.dart';
import '../repositories/data_repository.dart';
import '../services/thumbnail_store.dart';
import '../widgets/app_shell.dart';
import '../widgets/gray_box.dart';

/// 09-1 마이. 하위 화면은 UI 그대로 껍데기이고 탭 반응만 한다 (PRD §2).
class MeScreen extends StatefulWidget {
  const MeScreen({super.key});

  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> {
  int _versionTaps = 0;
  DateTime _lastTap = DateTime.fromMillisecondsSinceEpoch(0);

  /// 버전을 5번 탭하면 전시 데이터를 초기화한다 (STEP 25 전시 설정).
  Future<void> _onVersionTap() async {
    final now = DateTime.now();
    _versionTaps =
        now.difference(_lastTap) > const Duration(seconds: 2) ? 1 : _versionTaps + 1;
    _lastTap = now;
    if (_versionTaps < 5) return;
    _versionTaps = 0;

    final ok = await showGrayConfirm(
      context,
      title: 'Reset demo data?',
      body: 'Everything goes back to the seed state, including the first-run setup.',
      confirmLabel: 'Reset',
    );
    if (!ok || !mounted) return;

    final repo = context.read<DataRepository>();
    final thumbnails = context.read<ThumbnailStore>();
    await repo.resetDemoData();
    // 참조가 사라진 썸네일을 치운다.
    await thumbnails.pruneExcept({
      for (final m in repo.library)
        if (m.spec.thumbnailPath != null) m.spec.thumbnailPath!,
    });
    if (!mounted) return;

    // 저장소를 통째로 갈아끼웠으니 화면들이 다시 읽게 한다.
    context.read<LibraryProvider>().refresh();
    context.read<ProfileProvider>().refresh();
    context.read<RobotProvider>().refresh();
    context.read<NotificationProvider>().refresh();

    showGrayToast(context, S.toastDemoDataReset);
    Navigator.popUntil(context, (r) => r.isFirst);
  }

  Future<void> _editName() async {
    final profile = context.read<ProfileProvider>();
    final controller = TextEditingController(text: profile.name);

    final next = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SafeArea(
          child: StatefulBuilder(
            builder: (context, setSheet) => Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(S.meYourName,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLength: ProfileProvider.nameMax,
                    onChanged: (_) => setSheet(() {}),
                    decoration: const InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    // 같거나 비면 저장이 열리지 않는다 (09-1a).
                    onPressed: profile.canSaveName(controller.text)
                        ? () => Navigator.pop(context, controller.text.trim())
                        : null,
                    child: const Text(S.actionSave),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(S.actionCancel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (next == null || !mounted) return;
    await profile.rename(next);
    if (!mounted) return;
    showGrayToast(context, S.toastSaved);
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();

    return AppShell(
      title: S.meTitle,
      onBack: () => Navigator.pop(context),
      child: ListView(
        children: [
          const SizedBox(height: 8),
          _Card(children: [
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(profile.name),
              subtitle: Text(profile.email),
              trailing: TextButton(
                onPressed: _editName,
                child: const Text(S.meEdit),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          _Card(children: [
            _Nav(
              label: S.meNotifications,
              onTap: () => Navigator.pushNamed(context, AppRoutes.meNotifications),
            ),
            _Nav(
              label: S.meAccount,
              onTap: () => Navigator.pushNamed(context, AppRoutes.meAccount),
            ),
            _Nav(
              label: S.meHelp,
              onTap: () => Navigator.pushNamed(context, AppRoutes.meHelp),
            ),
            _Nav(
              label: S.meTerms,
              onTap: () => Navigator.pushNamed(context, AppRoutes.meTerms),
            ),
          ]),
          const SizedBox(height: 12),
          Center(
            child: GestureDetector(
              onTap: _onVersionTap,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  fill(S.meVersion, {'version': kAppVersion}),
                  style: const TextStyle(fontSize: 12, color: Gray.dim),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 09-2 알림 설정 — 토글은 로컬에 저장된다.
class MeNotificationsScreen extends StatelessWidget {
  const MeNotificationsScreen({super.key});

  static const _labels = {
    'motionPlayed': 'When Purebot plays a motion',
    'firmware': 'Firmware updates',
    'tips': 'Tips and ideas',
  };

  @override
  Widget build(BuildContext context) {
    final notifications = context.watch<NotificationProvider>();
    return AppShell(
      title: S.meNotifications,
      onBack: () => Navigator.pop(context),
      child: ListView(
        children: [
          const SizedBox(height: 8),
          _Card(children: [
            for (final e in _labels.entries)
              SwitchListTile(
                title: Text(e.value, style: const TextStyle(fontSize: 14)),
                value: notifications.isEnabled(e.key),
                onChanged: (v) => notifications.setEnabled(e.key, v),
              ),
          ]),
        ],
      ),
    );
  }
}

/// 09-3 계정 — Log out · Delete 는 확인 시트만 띄우고 닫는다 (PRD §2).
class MeAccountScreen extends StatelessWidget {
  const MeAccountScreen({super.key});

  @override
  Widget build(BuildContext context) => AppShell(
        title: S.meAccount,
        onBack: () => Navigator.pop(context),
        child: ListView(
          children: [
            const SizedBox(height: 8),
            _Card(children: [
              ListTile(
                title: const Text(S.meLogOut),
                onTap: () => showGrayConfirm(
                  context,
                  title: 'Log out?',
                  confirmLabel: S.meLogOut,
                  destructive: false,
                ),
              ),
              ListTile(
                title: Text(S.meDeleteAccount,
                    style: TextStyle(color: Colors.red.shade600)),
                onTap: () => showGrayConfirm(
                  context,
                  title: 'Delete your account?',
                  body: 'This cannot be undone.',
                  confirmLabel: S.actionDelete,
                ),
              ),
            ]),
          ],
        ),
      );
}

/// 09-4 Help & FAQ — 아코디언.
class MeHelpScreen extends StatelessWidget {
  const MeHelpScreen({super.key});

  static const _faq = {
    'How does Purebot make a motion?':
        'Tell it what happened, or show it a short video. It picks movements that fit '
            'the moment and plays them right away.',
    'What is a motion signature?':
        'Three answers that set how Purebot moves — how lively it is, how it comes to '
            'you, and how big its movements are.',
    'Why does it sometimes say demo?':
        'When there is no network, Purebot uses motions it already knows so it never '
            'stops responding.',
    'Where are my motions saved?':
        'On this phone only. Nothing is uploaded except the words and frames you send '
            'when making a motion.',
  };

  @override
  Widget build(BuildContext context) => AppShell(
        title: S.meHelp,
        onBack: () => Navigator.pop(context),
        child: ListView(
          children: [
            for (final e in _faq.entries)
              ExpansionTile(
                title: Text(e.key, style: const TextStyle(fontSize: 14)),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(e.value,
                        style: const TextStyle(fontSize: 13, color: Gray.dim, height: 1.5)),
                  ),
                ],
              ),
          ],
        ),
      );
}

/// 09-4 Terms & Privacy — 정적 문서.
class MeTermsScreen extends StatelessWidget {
  const MeTermsScreen({super.key});

  @override
  Widget build(BuildContext context) => AppShell(
        title: S.meTerms,
        onBack: () => Navigator.pop(context),
        child: const SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Text(
            'PURE is a graduation-exhibition prototype.\n\n'
            'Everything you make stays on this phone. The only thing that leaves the '
            'device is the text you type and the frames taken from a video you '
            'attach, which are sent to generate a motion and are not stored.\n\n'
            'There is no account, no sync, and no analytics.',
            style: TextStyle(fontSize: 13, height: 1.7, color: Gray.dim),
          ),
        ),
      );
}

/// 10-1 알림.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notifications = context.watch<NotificationProvider>();
    final items = notifications.items;

    return AppShell(
      title: S.notificationsTitle,
      onBack: () => Navigator.pop(context),
      actions: [
        if (notifications.hasUnread)
          TextButton(
            onPressed: notifications.markAllRead,
            child: const Text(S.actionDone),
          ),
      ],
      child: items.isEmpty
          ? const GrayEmptyState(title: S.emptyNotifications, body: '')
          : ListView(
              children: [
                for (final n in items)
                  ListTile(
                    leading: Icon(
                      n.read ? Icons.notifications_none : Icons.notifications_active,
                      color: n.read ? Gray.dim : Gray.accent,
                      size: 20,
                    ),
                    title: Text(n.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: n.read ? FontWeight.w400 : FontWeight.w600,
                        )),
                    subtitle: Text(n.body, style: const TextStyle(fontSize: 12)),
                    onTap: () {
                      notifications.markRead(n.id);
                      final target = n.target;
                      if (target == null) return;
                      Navigator.pushNamed(
                        context,
                        switch (target) {
                          'library' => AppRoutes.library,
                          'robot' => AppRoutes.robot,
                          _ => AppRoutes.home,
                        },
                      );
                    },
                  ),
              ],
            ),
    );
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

class _Nav extends StatelessWidget {
  const _Nav({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(label, style: const TextStyle(fontSize: 14)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      );
}
