import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../providers/notifications_provider.dart';
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
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = state.items[index];
              final when = _formatWhen(item.createdAt);
              return Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 22,
                    backgroundColor: item.isRead
                        ? cs.surfaceContainerHighest
                        : (isDark
                            ? cs.primary
                            : cs.primary.withValues(alpha: 0.22)),
                    child: Icon(
                      item.isRead
                          ? Icons.notifications_none_outlined
                          : Icons.notifications_outlined,
                      color: item.isRead
                          ? cs.onSurfaceVariant
                          : (isDark ? cs.onPrimary : cs.primary),
                      size: 22,
                    ),
                  ),
                  title: Text(
                    item.title,
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: item.isRead ? FontWeight.w500 : FontWeight.w700,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.message.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.message,
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
                  trailing: PopupMenuButton<String>(
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
