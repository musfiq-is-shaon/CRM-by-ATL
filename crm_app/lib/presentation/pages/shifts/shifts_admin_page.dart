import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../data/models/shift_model.dart';
import '../../../core/constants/rbac_page_keys.dart';
import '../../providers/auth_provider.dart';
import '../../providers/rbac_provider.dart' show rbacMeProvider;
import '../../providers/shift_provider.dart';
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

    if (!canManageShifts) {
      return Scaffold(
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
              ref.read(shiftProvider.notifier).loadShifts();
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
          RefreshIndicator(
            onRefresh: () => ref.read(shiftProvider.notifier).loadShifts(),
            child: state.isLoading && state.shifts.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.error != null && state.shifts.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: AppThemeColors.pagePaddingAll,
                        children: [
                          Text(state.error!,
                              style: TextStyle(color: textSecondary)),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () =>
                                ref.read(shiftProvider.notifier).loadShifts(),
                            child: const Text('Retry'),
                          ),
                        ],
                      )
                    : state.shifts.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.3),
                              Center(
                                child: Text(
                                  'No shifts yet. Tap New shift.',
                                  style: TextStyle(color: textSecondary),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: AppThemeColors.listPagePaddingFab,
                            itemCount: state.shifts.length,
                            itemBuilder: (context, i) {
                              final s = state.shifts[i];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  title: Text(
                                    s.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: textPrimary,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                        final ok =
                                            await Navigator.of(context)
                                                .push<bool>(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                ShiftFormPage(existing: s),
                                          ),
                                        );
                                        if (ok == true && mounted) {
                                          ref.invalidate(
                                              userShiftTimingsProvider);
                                          ref
                                              .read(shiftProvider.notifier)
                                              .loadShifts();
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
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(userShiftTimingsProvider);
        await ref.read(userShiftTimingsProvider.future);
      },
      child: async.when(
        loading: () => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
            const Center(child: CircularProgressIndicator()),
          ],
        ),
        error: (e, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppThemeColors.pagePaddingAll,
          children: [
            Text(
              e.toString(),
              style: TextStyle(color: textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.invalidate(userShiftTimingsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppThemeColors.pagePaddingAll,
              children: [
                SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
                Center(
                  child: Text(
                    'No users returned from the server.',
                    style: TextStyle(color: textSecondary),
                  ),
                ),
              ],
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppThemeColors.pagePaddingAll.copyWith(bottom: 88),
            itemCount: rows.length + 1,
            separatorBuilder: (context, index) => const SizedBox(height: 2),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
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
              final row = rows[i - 1];
              final u = row.user;
              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                tileColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.35),
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
          );
        },
      ),
    );
  }
}
