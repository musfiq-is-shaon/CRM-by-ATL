import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../data/models/attendance_model.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/attendance_reconciliation_provider.dart';
import '../../providers/shift_provider.dart';

/// Team queue tab inside [AttendanceHubPage]: pending late-reconciliation requests (JWT admin or
/// Attendance RBAC `admin`).
class AttendanceTeamReconciliationTab extends ConsumerStatefulWidget {
  const AttendanceTeamReconciliationTab({super.key});

  @override
  ConsumerState<AttendanceTeamReconciliationTab> createState() =>
      _AttendanceTeamReconciliationTabState();
}

class _AttendanceTeamReconciliationTabState
    extends ConsumerState<AttendanceTeamReconciliationTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(attendanceReconciliationProvider.notifier)
          .loadTeamQueue(status: 'pending');
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(attendanceWeekRollupProvider);
    ref.invalidate(userProfileShiftProvider);
    await ref
        .read(attendanceReconciliationProvider.notifier)
        .loadTeamQueue(status: 'pending');
    await ref.read(attendanceProvider.notifier).loadToday();
    await ref.read(shiftProvider.notifier).loadShifts();
    await ref.read(attendanceWeekRollupProvider.future);
  }

  Future<void> _review(
    AttendanceReconciliation row,
    String status,
  ) async {
    final noteCtrl = TextEditingController();
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final textPrimary = AppThemeColors.textPrimaryColor(ctx);
          return AlertDialog(
            title: Text(
              status == 'approved' ? 'Approve request' : 'Reject request',
              style: TextStyle(color: textPrimary),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  row.displayUserName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  row.reason,
                  style: TextStyle(
                    color: AppThemeColors.textSecondaryColor(ctx),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(status == 'approved' ? 'Approve' : 'Reject'),
              ),
            ],
          );
        },
      );
      if (ok != true || !mounted) return;
      await ref.read(attendanceReconciliationProvider.notifier).review(
            reconciliationId: row.id,
            status: status,
            reviewNote: noteCtrl.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'approved' ? 'Approved' : 'Rejected',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not update request'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      noteCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceReconciliationProvider);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final cs = Theme.of(context).colorScheme;

    ref.listen(attendanceReconciliationProvider, (prev, next) {
      if (next.error != null && prev?.error != next.error && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: cs.error,
          ),
        );
        ref.read(attendanceReconciliationProvider.notifier).clearError();
      }
    });

    return RefreshIndicator(
      onRefresh: _refresh,
      child: state.isLoading && state.items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height * 0.2,
                    ),
                    Center(
                      child: Text(
                        'No pending requests',
                        style: TextStyle(color: textSecondary, fontSize: 16),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: AppThemeColors.pagePaddingAll,
                  itemCount: state.items.length,
                  itemBuilder: (context, i) {
                    final row = state.items[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      row.displayUserName,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: textPrimary,
                                      ),
                                    ),
                                  ),
                                  Chip(
                                    label: const Text('Pending'),
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: cs.secondaryContainer,
                                  ),
                                ],
                              ),
                              if (row.attendanceDate != null &&
                                  row.attendanceDate!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Date: ${row.attendanceDate}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                row.reason,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: textPrimary,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: state.isLoading
                                          ? null
                                          : () => _review(row, 'rejected'),
                                      child: const Text('Reject'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: state.isLoading
                                          ? null
                                          : () => _review(row, 'approved'),
                                      child: const Text('Approve'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
