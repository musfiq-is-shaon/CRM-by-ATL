import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../providers/notifications_provider.dart';
import '../../widgets/error_widget.dart' as app_widgets;
import '../../widgets/loading_widget.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsProvider);
    final notifier = ref.read(notificationsProvider.notifier);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final surfaceColor = AppThemeColors.surfaceColor(context);

    return Scaffold(
      backgroundColor: AppThemeColors.backgroundColor(context),
      appBar: AppBar(
        backgroundColor: surfaceColor,
        foregroundColor: textPrimary,
        title: const Text('Notifications'),
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
        child: state.isLoading && state.items.isEmpty
            ? const LoadingWidget()
            : state.error != null && state.items.isEmpty
                ? app_widgets.ErrorWidget(
                    message: state.error!,
                    onRetry: () => notifier.load(),
                  )
                : state.items.isEmpty
                    ? const app_widgets.EmptyStateWidget(
                        title: 'No notifications',
                        subtitle: 'You are all caught up.',
                        icon: Icons.notifications_none_outlined,
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: state.items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = state.items[index];
                          final when = _formatWhen(item.createdAt);
                          return Card(
                            margin: EdgeInsets.zero,
                            child: ListTile(
                              leading: Icon(
                                item.isRead
                                    ? Icons.notifications_none
                                    : Icons.notifications_active,
                                color: item.isRead
                                    ? textSecondary
                                    : Theme.of(context).primaryColor,
                              ),
                              title: Text(
                                item.title,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontWeight: item.isRead
                                      ? FontWeight.w500
                                      : FontWeight.w700,
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
