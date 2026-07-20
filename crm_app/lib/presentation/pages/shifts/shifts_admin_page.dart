import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../core/utils/async_load_helper.dart';
import '../../../data/models/shift_model.dart';
import '../../../core/constants/rbac_page_keys.dart';
import '../../providers/auth_provider.dart';
import '../../providers/rbac_provider.dart' show rbacMeProvider;
import '../../providers/shift_provider.dart';
import '../../widgets/list_page_state.dart';
import '../../widgets/loading_widget.dart';
import 'shift_form_page.dart';

/// Admin: list shifts, create, edit, delete, assign user to shift.
class ShiftsAdminPage extends ConsumerStatefulWidget {
  const ShiftsAdminPage({super.key});

  @override
  ConsumerState<ShiftsAdminPage> createState() => _ShiftsAdminPageState();
}

class _ShiftsAdminPageState extends ConsumerState<ShiftsAdminPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(shiftProvider.notifier).loadShifts();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openAssign(WorkShift shift) async {
    final userIdController = TextEditingController();
    final result = await showDialog<Object?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assign shift'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Shift: ${shift.name}'),
            const SizedBox(height: 12),
            TextField(
              controller: userIdController,
              decoration: const InputDecoration(
                labelText: 'User ID',
                hintText: 'MongoDB user id',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 8),
            Text(
              'Leave empty and tap Unassign to remove shift from a user (requires user ID).',
              style: TextStyle(
                fontSize: 12,
                color: AppThemeColors.textSecondaryColor(context),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'unassign'),
            child: const Text('Unassign'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Assign'),
          ),
        ],
      ),
    );

    if (result == null || result == false) return;

    final uid = userIdController.text.trim();
    if (uid.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Enter a user ID')));
      }
      return;
    }

    try {
      if (result == 'unassign') {
        await ref
            .read(shiftProvider.notifier)
            .assignShift(userId: uid, shiftId: null);
      } else {
        await ref
            .read(shiftProvider.notifier)
            .assignShift(userId: uid, shiftId: shift.id);
      }
      if (mounted) {
        ref.invalidate(userShiftTimingsProvider);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _confirmDelete(WorkShift shift) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete shift?'),
        content: Text('Delete "${shift.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(shiftProvider.notifier).deleteShift(shift.id);
      if (mounted) {
        ref.invalidate(userShiftTimingsProvider);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Shift deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final jwtAdmin = ref.watch(isAdminProvider);
    final me = ref.watch(rbacMeProvider);
    final canManageShifts = jwtAdmin || (me?.hasNav(RbacPageKey.hr) ?? false);
    final state = ref.watch(shiftProvider);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);

    ref.listen<ShiftState>(shiftProvider, (prev, next) {
      if (next.error != null &&
          prev?.error != next.error &&
          next.shifts.isNotEmpty &&
          context.mounted) {
        showRefreshErrorSnackBar(context, next.error!);
        ref.read(shiftProvider.notifier).clearError();
      }
    });

    if (!canManageShifts) {
      return Scaffold(
        backgroundColor: AppThemeColors.backgroundColor(context),
        appBar: AppThemeColors.appBarTitle(context, 'Shifts'),
        body: Center(
          child: Padding(
            padding: AppThemeColors.pagePaddingAll,
            child: Text(
              'Only administrators can manage shifts.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppThemeColors.backgroundColor(context),
      appBar: AppThemeColors.appBarTitle(
        context,
        'Shifts',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(userShiftTimingsProvider);
              ref.read(shiftProvider.notifier).loadShifts(refresh: true);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Templates'),
            Tab(text: 'Team roster'),
          ],
        ),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          if (_tabController.index != 0) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () async {
              final created = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const ShiftFormPage()),
              );
              if (created == true && mounted) {
                ref.invalidate(userShiftTimingsProvider);
                ref.read(shiftProvider.notifier).loadShifts();
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('New shift'),
          );
        },
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          AsyncScreenView(
            isLoading: state.isLoading,
            isRefreshing: state.isRefreshing,
            hasCachedData: state.shifts.isNotEmpty,
            error: state.error,
            isEmpty: state.shifts.isEmpty,
            onRetry: () => ref.read(shiftProvider.notifier).loadShifts(),
            emptyTitle: 'No shifts yet',
            emptySubtitle: 'Tap New shift to create your first template',
            emptyIcon: Icons.schedule_outlined,
            content: RefreshIndicator(
              onRefresh: () =>
                  ref.read(shiftProvider.notifier).loadShifts(refresh: true),
              child: FadeInContent(
                child: ListView.builder(
                  padding: AppThemeColors.listPagePaddingFab,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: state.shifts.length,
                  itemBuilder: (context, i) {
                    final s = state.shifts[i];
                    return Card(
                      margin: AppThemeColors.cardListItemMargin,
                      child: ListTile(
                        title: Text(
                          s.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              '${s.startTime} – ${s.endTime} · grace ${s.gracePeriod} min',
                              style: TextStyle(
                                fontSize: 13,
                                color: textSecondary,
                              ),
                            ),
                            Text(
                              'Weekend: ${s.weekendDaysLabel}',
                              style: TextStyle(
                                fontSize: 12,
                                color: textSecondary,
                              ),
                            ),
                            if (s.employeeIds.isNotEmpty)
                              Text(
                                '${s.employeeIds.length} employee(s)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textSecondary,
                                ),
                              ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'edit') {
                              final ok = await Navigator.of(context)
                                  .push<bool>(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ShiftFormPage(existing: s),
                                    ),
                                  );
                              if (ok == true && mounted) {
                                ref.invalidate(userShiftTimingsProvider);
                                ref.read(shiftProvider.notifier).loadShifts();
                              }
                            } else if (v == 'assign') {
                              _openAssign(s);
                            } else if (v == 'delete') {
                              _confirmDelete(s);
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            const PopupMenuItem(
                              value: 'assign',
                              child: Text('Assign user…'),
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
          ),
          _TeamShiftRosterTab(
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
        ],
      ),
    );
  }
}

class _TeamShiftRosterTab extends ConsumerWidget {
  const _TeamShiftRosterTab({
    required this.textPrimary,
    required this.textSecondary,
  });

  final Color textPrimary;
  final Color textSecondary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(userShiftTimingsProvider);
    final cached = async.valueOrNull ?? const <UserShiftTiming>[];
    final isLoading = async.isLoading && cached.isEmpty;
    final isRefreshing = async.isLoading && cached.isNotEmpty;
    final error = async.hasError ? async.error.toString() : null;

    return AsyncScreenView(
      isLoading: isLoading,
      isRefreshing: isRefreshing,
      hasCachedData: cached.isNotEmpty,
      error: error,
      isEmpty: cached.isEmpty,
      onRetry: () => ref.invalidate(userShiftTimingsProvider),
      emptyTitle: 'No team members',
      emptySubtitle: 'No users returned from the server',
      emptyIcon: Icons.people_outline,
      content: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(userShiftTimingsProvider);
          await ref.read(userShiftTimingsProvider.future);
        },
        child: FadeInContent(
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppThemeColors.listPagePadding.copyWith(bottom: 88),
            itemCount: cached.length + 1,
            separatorBuilder: (context, index) => const SizedBox(height: 2),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: AppThemeColors.cardListItemMargin,
                  child: Text(
                    'Each row shows times from the user shift id on their profile, or from a shift template that lists them.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: textSecondary,
                    ),
                  ),
                );
              }
              final row = cached[i - 1];
              final u = row.user;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                tileColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                title: Text(
                  u.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    row.timingLine,
                    style: TextStyle(
                      fontSize: 13,
                      color: textSecondary,
                      height: 1.3,
                    ),
                  ),
                ),
                trailing: u.isActive == false
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          'Inactive',
                          style: TextStyle(
                            fontSize: 11,
                            color: textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : null,
              );
            },
          ),
        ),
      ),
    );
  }
}
