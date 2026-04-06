import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/attendance_reconciliation_provider.dart';
import '../../providers/shift_provider.dart';
import 'attendance_admin_access.dart';
import 'reconciliation_team_page.dart';
import 'widgets/attendance_hub_header.dart';
import 'widgets/records_list.dart';

/// More → Attendance: reconciliation request history, attendance records,
/// and (JWT admin or Attendance RBAC admin) team queue. Late reasons are submitted from the dashboard
/// after a late check-in.
class AttendanceHubPage extends ConsumerStatefulWidget {
  const AttendanceHubPage({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  ConsumerState<AttendanceHubPage> createState() => _AttendanceHubPageState();
}

class _AttendanceHubPageState extends ConsumerState<AttendanceHubPage>
    with SingleTickerProviderStateMixin {
  TabController? _tabs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(attendanceProvider.notifier).loadToday();
      ref.read(shiftProvider.notifier).loadShifts();
    });
  }

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  void _syncTabController(int length) {
    if (_tabs != null && _tabs!.length == length) return;
    final previousIndex = _tabs?.index;
    _tabs?.dispose();
    var initial = widget.initialTabIndex.clamp(0, length - 1);
    if (previousIndex != null && previousIndex < length) {
      initial = previousIndex;
    }
    _tabs = TabController(
      length: length,
      vsync: this,
      initialIndex: initial,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isReviewer = canManageAttendanceReconciliations(ref);
    final tabCount = isReviewer ? 3 : 2;
    _syncTabController(tabCount);

    final surface = AppThemeColors.surfaceColor(context);
    final tabs = <Widget>[
      const Tab(text: 'My requests'),
      const Tab(text: 'History'),
    ];
    if (isReviewer) {
      tabs.add(const Tab(text: 'Team'));
    }

    final views = <Widget>[
      const _ReconciliationRequestsTab(),
      const _AttendanceHistoryTab(),
    ];
    if (isReviewer) {
      views.add(const AttendanceTeamReconciliationTab());
    }

    return Scaffold(
      backgroundColor: surface,
      appBar: AppThemeColors.appBarTitle(context, 'Attendance'),
      body: Column(
        children: [
          const AttendanceHubHeader(),
          TabBar(
            controller: _tabs!,
            isScrollable: tabCount > 2,
            tabAlignment: tabCount > 2 ? TabAlignment.start : TabAlignment.fill,
            tabs: tabs,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs!,
              children: views,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReconciliationRequestsTab extends ConsumerStatefulWidget {
  const _ReconciliationRequestsTab();

  @override
  ConsumerState<_ReconciliationRequestsTab> createState() =>
      _ReconciliationRequestsTabState();
}

class _ReconciliationRequestsTabState
    extends ConsumerState<_ReconciliationRequestsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(attendanceReconciliationProvider.notifier).loadMine();
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(attendanceWeekRollupProvider);
    ref.invalidate(userProfileShiftProvider);
    await ref.read(attendanceReconciliationProvider.notifier).loadMine();
    await ref.read(shiftProvider.notifier).loadShifts();
    await ref.read(attendanceWeekRollupProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final rec = ref.watch(attendanceReconciliationProvider);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final cs = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: rec.isLoading && rec.items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : rec.items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
                    Center(
                      child: Text(
                        'No reconciliation requests yet',
                        style: TextStyle(color: textSecondary, fontSize: 16),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: AppThemeColors.pagePaddingAll,
                  itemCount: rec.items.length,
                  itemBuilder: (context, i) {
                    final row = rec.items[i];
                    Color chipBg;
                    Color chipFg;
                    String label;
                    switch (row.status) {
                      case 'approved':
                        chipBg = cs.primaryContainer;
                        chipFg = cs.onPrimaryContainer;
                        label = 'Approved';
                        break;
                      case 'rejected':
                        chipBg = cs.errorContainer;
                        chipFg = cs.onErrorContainer;
                        label = 'Rejected';
                        break;
                      default:
                        chipBg = cs.secondaryContainer;
                        chipFg = cs.onSecondaryContainer;
                        label = 'Pending';
                    }
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Chip(
                                  label: Text(label),
                                  backgroundColor: chipBg,
                                  labelStyle: TextStyle(
                                    color: chipFg,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                const Spacer(),
                                if (row.createdAt != null)
                                  Text(
                                    _shortDate(row.createdAt!),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              row.reason,
                              style: TextStyle(
                                fontSize: 15,
                                color: textPrimary,
                                height: 1.35,
                              ),
                            ),
                            if (row.reviewNote != null &&
                                row.reviewNote!.trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Note: ${row.reviewNote}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

String _shortDate(DateTime d) {
  final l = d.toLocal();
  return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
}

class _AttendanceHistoryTab extends ConsumerStatefulWidget {
  const _AttendanceHistoryTab();

  @override
  ConsumerState<_AttendanceHistoryTab> createState() =>
      _AttendanceHistoryTabState();
}

class _AttendanceHistoryTabState extends ConsumerState<_AttendanceHistoryTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(attendanceProvider.notifier).loadRecords(period: 'month');
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(attendanceWeekRollupProvider);
    ref.invalidate(userProfileShiftProvider);
    final n = ref.read(attendanceProvider.notifier);
    await n.loadRecords(period: ref.read(attendanceProvider).period);
    await ref.read(attendanceProvider.notifier).loadToday();
    await ref.read(shiftProvider.notifier).loadShifts();
    await ref.read(attendanceWeekRollupProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final att = ref.watch(attendanceProvider);
    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppThemeColors.pagePaddingAll,
        child: RecordsList(state: att, showHeading: false),
      ),
    );
  }
}
