import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../data/models/shift_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shift_provider.dart';
import 'shift_form_page.dart';

/// Admin: list shifts, create, edit, delete, assign user to shift.
class ShiftsAdminPage extends ConsumerStatefulWidget {
  const ShiftsAdminPage({super.key});

  @override
  ConsumerState<ShiftsAdminPage> createState() => _ShiftsAdminPageState();
}

class _ShiftsAdminPageState extends ConsumerState<ShiftsAdminPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(shiftProvider.notifier).loadShifts();
    });
  }

  Future<void> _openAssign(WorkShift shift) async {
    final userIdController = TextEditingController();
    final ok = await showDialog<bool>(
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

    if (ok == null || ok == false) return;

    final uid = userIdController.text.trim();
    if (uid.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a user ID')),
        );
      }
      return;
    }

    try {
      if (ok == 'unassign') {
        await ref.read(shiftProvider.notifier).assignShift(
              userId: uid,
              shiftId: null,
            );
      } else {
        await ref.read(shiftProvider.notifier).assignShift(
              userId: uid,
              shiftId: shift.id,
            );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shift deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isAdmin = auth.user?.role == 'admin';
    final state = ref.watch(shiftProvider);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final surface = AppThemeColors.surfaceColor(context);

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Shifts')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
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
      appBar: AppBar(
        title: const Text('Shifts'),
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(shiftProvider.notifier).loadShifts(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => const ShiftFormPage(),
            ),
          );
          if (created == true && mounted) {
            ref.read(shiftProvider.notifier).loadShifts();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('New shift'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(shiftProvider.notifier).loadShifts(),
        child: state.isLoading && state.shifts.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : state.error != null && state.shifts.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(
                        state.error!,
                        style: TextStyle(color: textSecondary),
                      ),
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
                            height: MediaQuery.of(context).size.height * 0.3,
                          ),
                          Center(
                            child: Text(
                              'No shifts yet. Tap New shift.',
                              style: TextStyle(color: textSecondary),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
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
    );
  }
}
