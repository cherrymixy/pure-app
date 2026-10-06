import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../data/strings.dart';
import '../models/message.dart';
import '../providers/chat_provider.dart';
import '../providers/library_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_icon.dart';
import '../widgets/pure_empty.dart';
import '../widgets/pure_sheet.dart';
import '../widgets/pure_top_bar.dart';

/// 06-8 대화 기록 — Figma `480:3263`.
///
/// 시안 값: 뒤로 + 제목 + 검정 `New` 알약 / 그룹(Today · Earlier) 간격 22 /
/// 카드 radius 18, 왼쪽 14 · 오른쪽 12 · 위아래 12, 항목 사이 8.
/// 왼쪽으로 밀면 지운다 — 시안에 없는 동작이지만 전시 중 정리에 쓴다.
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

    Widget group(String label, List<Chat> items) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTextStyles.bodyS.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.x12),
            for (final c in items) ...[
              _ChatCard(
                chat: c,
                savedCount: library.all.where((m) => m.chatId == c.id).length,
              ),
              if (c != items.last) const SizedBox(height: AppSpacing.x8),
            ],
          ],
        );

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PureBackBar(
              title: S.chatHistoryTitle,
              trailing: _NewChatButton(
                onTap: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.homeNew,
                  (r) => false,
                ),
              ),
            ),
            Expanded(
              child: chats.isEmpty
                  ? const PureEmptyState(
                      icon: AppIconName.bellRow,
                      title: S.emptyChatHistory,
                      body: S.emptyLibraryBody,
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.x24,
                        18,
                        AppSpacing.x24,
                        AppSpacing.x24,
                      ),
                      children: [
                        if (today.isNotEmpty) group(S.chatHistoryToday, today),
                        if (today.isNotEmpty && earlier.isNotEmpty)
                          const SizedBox(height: 22),
                        if (earlier.isNotEmpty)
                          group(S.chatHistoryEarlier, earlier),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 시안 `Button/New chat` (`480:3267`) — 검정 알약, 왼쪽 12 / 오른쪽 14 / 위아래 8.
class _NewChatButton extends StatelessWidget {
  const _NewChatButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.bgInverse,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(12, AppSpacing.x8, 14, AppSpacing.x8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppIcon(
                  AppIconName.plusRow,
                  size: 14,
                  color: AppColors.iconOnInverse,
                ),
                const SizedBox(width: 6),
                Text(
                  S.chatHistoryNew,
                  style: AppTextStyles.labelM.copyWith(
                    color: AppColors.textOnInverse,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// 시안 `Chat/…` (`480:3276`) — 흰 카드 radius 18, 저장 배지 + 꺾쇠 16.
class _ChatCard extends StatelessWidget {
  const _ChatCard({required this.chat, required this.savedCount});

  final Chat chat;
  final int savedCount;

  @override
  Widget build(BuildContext context) {
    final title = chat.messages
            .firstWhere(
              (m) => m.sender == Sender.user && (m.text ?? '').isNotEmpty,
              orElse: () => chat.messages.first,
            )
            .text ??
        'Untitled';

    final replies = fill(
      chat.replyCount == 1 ? S.chatHistoryReplyOne : S.chatHistoryReplies,
      {'count': chat.replyCount},
    );

    return Dismissible(
      key: ValueKey(chat.id),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: AppColors.statusError,
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.x20),
        child: const Icon(Icons.delete, color: AppColors.iconOnInverse),
      ),
      confirmDismiss: (_) => showPureConfirm(
        context,
        title: S.chatHistoryDeleteTitle,
        body: S.chatHistoryDeleteBody,
        confirmLabel: S.actionDelete,
      ),
      onDismissed: (_) => context.read<ChatProvider>().deleteChat(chat.id),
      child: Material(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            await context.read<ChatProvider>().open(chat.id);
            if (!context.mounted) return;
            // 대화는 홈 위에 올라간다 — 홈만 남기고 돌아간다.
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.home,
              (r) => false,
            );
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              14,
              AppSpacing.x12,
              12,
              AppSpacing.x12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyM.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        fill(S.chatHistoryMeta, {
                          'replies': replies,
                          'when': _when(chat.lastActiveAt),
                        }),
                        style: AppTextStyles.bodyS.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (savedCount > 0) ...[
                  const SizedBox(width: AppSpacing.x12),
                  _SavedBadge(count: savedCount),
                ],
                const SizedBox(width: AppSpacing.x12),
                const AppIcon(
                  AppIconName.chevron,
                  size: 16,
                  color: AppColors.iconSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 오늘이면 시각, 아니면 날짜 (시안 "9:41 PM" / "Oct 2").
  static String _when(DateTime t) {
    final now = DateTime.now();
    if (t.year == now.year && t.month == now.month && t.day == now.day) {
      final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
      return '$h:${t.minute.toString().padLeft(2, '0')} '
          '${t.hour < 12 ? 'AM' : 'PM'}';
    }
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[t.month - 1]} ${t.day}';
  }
}

/// 시안 `Saved` (`480:3280`) — `bg/brand-subtle`, 좌우 8 / 위아래 3, radius 10.
class _SavedBadge extends StatelessWidget {
  const _SavedBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.x8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.bgBrandSubtle,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          fill(S.chatHistorySaved, {'count': count}),
          style: AppTextStyles.caption.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textLink,
          ),
        ),
      );
}
