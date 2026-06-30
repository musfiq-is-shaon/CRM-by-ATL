import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../core/theme/design_tokens.dart';
import '../../providers/notifications_provider.dart';
import '../../widgets/crm_card.dart';
import '../../widgets/list_page_state.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Always refetch when opening this screen so each user/session sees current data.
      ref.read(notificationsProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsProvider);
    final notifier = ref.read(notificationsProvider.notifier);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final textTertiary = AppThemeColors.textTertiaryColor(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppThemeColors.backgroundColor(context),
      appBar: AppThemeColors.appBarTitle(
        context,
        'Notifications',
        actions: [
          IconButton(
            tooltip: 'Mark all read',
            onPressed: state.items.isEmpty
                ? null
                : () async {
                    await notifier.markAllRead();
                  },
            icon: const Icon(Icons.done_all),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => notifier.load(),
        child: ListPageState(
          isLoading: state.isLoading && state.items.isEmpty,
          error: state.error != null && state.items.isEmpty ? state.error : null,
          isEmpty: !state.isLoading && state.error == null && state.items.isEmpty,
          onRetry: () => notifier.load(),
          emptyTitle: 'No notifications',
          emptySubtitle: 'You are all caught up.',
          emptyIcon: Icons.notifications_none_outlined,
          content: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppThemeColors.listPagePadding,
            itemCount: state.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final item = state.items[index];
              final when = _formatWhen(item.createdAt);
              return CRMCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppThemeColors.iconChip(
                      context,
                      icon: item.isRead
                          ? Icons.notifications_none_outlined
                          : Icons.notifications_outlined,
                      accent: item.isRead ? textSecondary : cs.primary,
                      size: 44,
                      iconSize: 22,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.displayTitle,
                            style: TextStyle(
                              color: textPrimary,
                              fontWeight: item.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                            ),
                          ),
                          if (item.displayMessage.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              item.displayMessage,
                              style: TextStyle(color: textSecondary),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            when,
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: textTertiary),
                      onSelected: (v) async {
                        if (v == 'read' && !item.isRead) {
                          await notifier.markAsRead(item.id);
                        }
                        if (v == 'delete') {
                          await notifier.deleteOne(item.id);
                        }
                      },
                      itemBuilder: (_) => [
                        if (!item.isRead)
                          const PopupMenuItem(
                            value: 'read',
                            child: Text('Mark as read'),
                          ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _formatWhen(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${local.day}/${local.month}/${local.year}';
  }
}
