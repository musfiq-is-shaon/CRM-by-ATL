import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/models/user_model.dart';
import '../../widgets/crm_card.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/app_semantic_pill.dart';
import '../../widgets/list_page_state.dart';

final usersProvider = FutureProvider<List<User>>((ref) async {
  final repository = ref.watch(userRepositoryProvider);
  return repository.getUsers();
});

class UsersPage extends ConsumerWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersProvider);

    final bgColor = AppThemeColors.backgroundColor(context);
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final textTertiary = AppThemeColors.textTertiaryColor(context);
    final cs = Theme.of(context).colorScheme;
    final primaryColor = cs.primary;
    final accentColor = cs.tertiary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppThemeColors.appBarTitle(
        context,
        'Users',
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              _showCreateUserDialog(context);
            },
          ),
        ],
      ),
      body: usersAsync.when(
        loading: () => ListPageState(
          isLoading: true,
          error: null,
          isEmpty: false,
          onRetry: () => ref.invalidate(usersProvider),
          emptyTitle: '',
          emptySubtitle: '',
          emptyIcon: Icons.people_outline,
          content: const SizedBox.shrink(),
        ),
        error: (error, stack) => ListPageState(
          isLoading: false,
          error: error.toString(),
          isEmpty: false,
          onRetry: () => ref.invalidate(usersProvider),
          emptyTitle: '',
          emptySubtitle: '',
          emptyIcon: Icons.people_outline,
          content: const SizedBox.shrink(),
        ),
        data: (users) {
          return ListPageState(
            isLoading: false,
            error: null,
            isEmpty: users.isEmpty,
            onRetry: () => ref.invalidate(usersProvider),
            emptyTitle: 'No users found',
            emptySubtitle: 'Add your first user',
            emptyIcon: Icons.people_outline,
            content: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(usersProvider);
                await ref.read(usersProvider.future);
              },
              child: ListView.builder(
                padding: AppThemeColors.pagePaddingAll,
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: CRMCard(
                      onTap: () {
                        _showUserDetailsDialog(
                          context,
                          user,
                          textPrimary,
                          textSecondary,
                          surfaceColor,
                          primaryColor,
                          accentColor,
                        );
                      },
                      child: Row(
                        children: [
                          AvatarWidget(name: user.name, size: 50),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user.email,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textSecondary,
                                  ),
                                ),
                                if (user.role != null) ...[
                                  const SizedBox(height: 4),
                                  AppSemanticPill(
                                    label: user.role!,
                                    tone: user.role == 'admin'
                                        ? AppSemanticTone.warning
                                        : AppSemanticTone.info,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: textTertiary),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  void _showUserDetailsDialog(
    BuildContext context,
    User user,
    Color textPrimary,
    Color textSecondary,
    Color surfaceColor,
    Color primaryColor,
    Color accentColor,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceColor,
        title: Text(user.name, style: TextStyle(color: textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Email', user.email, textPrimary, textSecondary),
            if (user.phone != null)
              _buildDetailRow('Phone', user.phone!, textPrimary, textSecondary),
            _buildDetailRow(
              'Role',
              user.role ?? 'user',
              textPrimary,
              textSecondary,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to edit user
            },
            child: Text('Edit', style: TextStyle(color: primaryColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(color: textSecondary, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateUserDialog(BuildContext context) {
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceColor,
        title: Text('Create User', style: TextStyle(color: textPrimary)),
        content: Text(
          'User creation form would go here.',
          style: TextStyle(color: textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
