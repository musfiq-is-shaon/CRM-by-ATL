import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../core/utils/async_load_helper.dart';
import '../../../data/models/attendance_model.dart';
import '../../../data/models/shift_model.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/attendance_reconciliation_provider.dart';
import '../../providers/shift_provider.dart';
import '../../widgets/list_page_state.dart';
import '../../widgets/loading_widget.dart';

String _teamRowDisplayName(
  AttendanceReconciliation row,
  List<UserShiftTiming>? timings,
) {
  final d = row.displayUserName.trim();
  if (d.isNotEmpty && d != 'User') return d;
  if (timings == null) return d.isNotEmpty ? d : 'User';
  final uid = row.effectiveApplicantUserId;
  for (final t in timings) {
    if (attendanceUserIdsEqual(t.user.id, uid)) {
      final n = t.user.name.trim();
      if (n.isNotEmpty) return n;
      final e = t.user.email.trim();
      if (e.isNotEmpty) return e;
    }
  }
  final em = row.user?.email.trim();
  if (em != null && em.isNotEmpty) {
    for (final t in timings) {
      if (t.user.email.trim().toLowerCase() == em.toLowerCase()) {
        final n = t.user.name.trim();
        if (n.isNotEmpty) return n;
        return em;
      }
    }
  }
  return d.isNotEmpty ? d : 'User';
}

String _teamRowShiftLine(
  AttendanceReconciliation row,
  List<WorkShift> shifts,
  List<UserShiftTiming>? timings,
) {
  final uid = row.effectiveApplicantUserId.trim();
  final em = row.user?.email.trim();
  if (timings != null) {
    for (final t in timings) {
      if (uid.isNotEmpty && attendanceUserIdsEqual(t.user.id, uid)) {
        return t.timingLine;
      }
    }
    if (em != null && em.isNotEmpty) {
      for (final t in timings) {
        if (t.user.email.trim().toLowerCase() == em.toLowerCase()) {
          return t.timingLine;
        }
      }
    }
  }
  final fromLocal = WorkShift.resolveForApplicant(
    shifts: shifts,
    embeddedUser: row.user,
    applicantUserId: row.effectiveApplicantUserId,
  );
  return fromLocal?.timingDisplayLine ?? 'No shift assigned';
}

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
      ref.read(userShiftTimingsProvider.future);
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(attendanceWeekRollupProvider);
    ref.invalidate(userProfileShiftProvider);
    await ref
        .read(attendanceReconciliationProvider.notifier)
        .loadTeamQueue(status: 'pending', refresh: true);
    await ref.read(attendanceProvider.notifier).loadToday();
    await ref.read(shiftProvider.notifier).loadShifts();
    ref.invalidate(userShiftTimingsProvider);
    await ref.read(userShiftTimingsProvider.future);
    await ref.read(attendanceWeekRollupProvider.future);
  }

  Future<void> _review(
    AttendanceReconciliation row,
    String status,
  ) async {
    final noteCtrl = TextEditingController();
    try {
      final timings = ref.read(userShiftTimingsProvider).valueOrNull;
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
                  _teamRowDisplayName(row, timings),
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
    final shifts = ref.watch(shiftProvider).shifts;
    final timings = ref.watch(userShiftTimingsProvider).valueOrNull;
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final cs = Theme.of(context).colorScheme;

    ref.listen(attendanceReconciliationProvider, (prev, next) {
      if (next.error != null &&
          prev?.error != next.error &&
          next.items.isNotEmpty &&
          mounted) {
        showRefreshErrorSnackBar(context, next.error!);
        ref.read(attendanceReconciliationProvider.notifier).clearError();
      }
    });

    return AsyncScreenView(
      isLoading: state.isLoading && state.items.isEmpty,
      isRefreshing: state.isRefreshing,
      hasCachedData: state.items.isNotEmpty,
      error: state.error,
      isEmpty: state.items.isEmpty,
      onRetry: () => ref
          .read(attendanceReconciliationProvider.notifier)
          .loadTeamQueue(status: 'pending'),
      emptyTitle: 'No pending requests',
      emptySubtitle: 'Late reconciliation requests will appear here',
      emptyIcon: Icons.fact_check_outlined,
      content: RefreshIndicator(
        onRefresh: _refresh,
        child: FadeInContent(
          child: ListView.builder(
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
                                _teamRowDisplayName(row, timings),
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
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 15,
                              color: cs.tertiary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _teamRowShiftLine(row, shifts, timings),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: textSecondary,
                                  height: 1.3,
                                ),
                              ),
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
                                onPressed: state.isLoading || state.isRefreshing
                                    ? null
                                    : () => _review(row, 'rejected'),
                                child: const Text('Reject'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: state.isLoading || state.isRefreshing
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
        ),
      ),
    );
  }
}
