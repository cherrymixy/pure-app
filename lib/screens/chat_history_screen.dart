import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../data/strings.dart';
import '../models/message.dart';
import '../providers/chat_provider.dart';
import '../providers/library_provider.dart';
import '../widgets/app_shell.dart';
import '../widgets/gray_box.dart';

/// 06-8 대화 기록 — Today / Earlier, 스와이프 삭제.
class ChatHistoryScreen extends StatelessWidget {
  const ChatHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final library = context.watch<LibraryProvider>();
    final chats = chat.chats.where((c) => c.messages.isNotEmpty).toList();

    final now = DateTime.now();
    final today = <Chat>[];
    final earlier = <Chat>[];
    for (final c in chats) {
      final sameDay = c.lastActiveAt.year == now.year &&
          c.lastActiveAt.month == now.month &&
          c.lastActiveAt.day == now.day;
      (sameDay ? today : earlier).add(c);
    }

    return AppShell(
      title: S.chatHistoryTitle,
      onBack: () => Navigator.pop(context),
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.homeNew,
            (r) => r.isFirst,
          ),
        ),
      ],
      child: chats.isEmpty
          ? const GrayEmptyState(
              title: S.emptyChatHistory,
              body: S.emptyLibraryBody,
            )
          : ListView(
              children: [
                if (today.isNotEmpty) const GraySectionLabel(S.chatHistoryToday),
                ...today.map((c) => _Row(chat: c, library: library, current: chat.currentId)),
                if (earlier.isNotEmpty) const GraySectionLabel(S.chatHistoryEarlier),
                ...earlier.map((c) => _Row(chat: c, library: library, current: chat.currentId)),
              ],
            ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.chat, required this.library, this.current});

  final Chat chat;
  final LibraryProvider library;
  final String? current;

  @override
  Widget build(BuildContext context) {
    final savedCount = library.all.where((m) => m.chatId == chat.id).length;
    final firstText = chat.messages
        .firstWhere(
          (m) => m.sender == Sender.user && (m.text ?? '').isNotEmpty,
          orElse: () => chat.messages.first,
        )
        .text;
    final isCurrent = chat.id == current;

    return Dismissible(
      key: ValueKey(chat.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red.shade600,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => showGrayConfirm(
        context,
        title: 'Delete this chat?',
        body: 'Saved motions stay in your library.',
      ),
      onDismissed: (_) => context.read<ChatProvider>().deleteChat(chat.id),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        decoration: BoxDecoration(
          color: Gray.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isCurrent ? Gray.accent : Gray.line),
        ),
        child: ListTile(
          title: Text(
            firstText ?? 'Untitled',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            [
              fill(S.chatHistoryReplies, {'count': chat.replyCount}),
              if (savedCount > 0) fill(S.chatHistorySaved, {'count': savedCount}),
              _time(chat.lastActiveAt),
            ].join(' · '),
            style: const TextStyle(fontSize: 12),
          ),
          onTap: () async {
            await context.read<ChatProvider>().open(chat.id);
            if (!context.mounted) return;
            Navigator.pushReplacementNamed(context, AppRoutes.chat);
          },
        ),
      ),
    );
  }

  static String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
