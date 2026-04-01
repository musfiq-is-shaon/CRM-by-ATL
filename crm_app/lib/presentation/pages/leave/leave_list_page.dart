import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leave_provider.dart';
import '../../../data/models/leave_model.dart';
import '../../widgets/crm_card.dart';
import '../../widgets/status_badge.dart';
import 'leave_apply_page.dart';
import 'leave_balances_page.dart';
import 'leave_detail_page.dart';
import 'leave_hr_admin_page.dart';
import 'leave_module_flags.dart';

class LeaveListPage extends ConsumerStatefulWidget {
  const LeaveListPage({super.key});

  @override
  ConsumerState<LeaveListPage> createState() => _LeaveListPageState();
}

class _LeaveListPageState extends ConsumerState<LeaveListPage> {
  late final TextEditingController _adminUserIdsController;

  @override
  void initState() {
    super.initState();
    _adminUserIdsController = TextEditingController();
    if (kLeaveModuleComingSoon) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(leaveProvider.notifier).bootstrapList();
      final uid = ref.read(leaveProvider).adminAllFilters.userIds;
      if (uid.isNotEmpty) _adminUserIdsController.text = uid;
    });
  }

  @override
  void dispose() {
    _adminUserIdsController.dispose();
    super.dispose();
  }

  String _fmtDay(DateTime d) {
    final x = d.toLocal();
    return '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
  }

  static String _formatLeaveBalance(num v) {
    final d = v.toDouble();
    if (d == d.roundToDouble()) return d.round().toString();
    return d.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    if (kLeaveModuleComingSoon) {
      return _buildComingSoon(context);
    }

    final state = ref.watch(leaveProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final bg = AppThemeColors.backgroundColor(context);
    final surface = AppThemeColors.surfaceColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final borderColor = AppThemeColors.borderColor(context);
    final cardFill = AppThemeColors.cardColor(context);
    final primary = Theme.of(context).colorScheme.primary;

    final showTeamChip =
        isAdmin || (state.reportingInfo?.isReportingManager ?? false);
    final showAllChip = isAdmin;

    final canOpenLeaveDetail =
        state.scope == LeaveListScope.mine ||
        (state.scope == LeaveListScope.all && isAdmin) ||
        (state.scope == LeaveListScope.team && isAdmin);

    ref.listen(leaveProvider, (prev, next) {
      if (next.error != null && prev?.error != next.error && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Colors.red.shade700,
          ),
        );
        ref.read(leaveProvider.notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text('Leave', style: TextStyle(color: textPrimary)),
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'balances') {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const LeaveBalancesPage(),
                  ),
                );
              } else if (value == 'hr_admin' && isAdmin) {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const LeaveHrAdminPage(),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'balances',
                child: Text('Leave balances'),
              ),
              if (isAdmin)
                const PopupMenuItem(
                  value: 'hr_admin',
                  child: Text('HR: types, weekends, holidays'),
                ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push<void>(
            context,
            MaterialPageRoute<void>(builder: (_) => const LeaveApplyPage()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Apply'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              decoration: BoxDecoration(
                color: cardFill,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 4, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.pie_chart_outline, size: 20, color: primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your remaining leave',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (state.balancesLoading)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: primary,
                              ),
                            ),
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 22),
                            tooltip: 'Refresh balances',
                            color: textSecondary,
                            onPressed: () => ref
                                .read(leaveProvider.notifier)
                                .loadMyBalances(),
                          ),
                      ],
                    ),
                    if (state.balancesError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        state.balancesError!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.red.shade700,
                          height: 1.3,
                        ),
                      ),
                    ],
                    if (!state.balancesLoading &&
                        state.balancesError == null &&
                        state.myBalances.isEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'No balances on file yet. HR can allocate days (menu → Leave balances).',
                        style: TextStyle(
                          fontSize: 13,
                          color: textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                    if (state.myBalances.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'All values are in days',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 12,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Additional is alert',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context).colorScheme.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    'Leave type',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: textSecondary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'Cred',
                                    textAlign: TextAlign.end,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: textSecondary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'Rem',
                                    textAlign: TextAlign.end,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: textSecondary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'Add',
                                    textAlign: TextAlign.end,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context).colorScheme.error,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            for (final entry in state.myBalances.asMap().entries) ...[
                              if (entry.key > 0) const Divider(height: 10),
                              Builder(
                                builder: (context) {
                                  final cs = Theme.of(context).colorScheme;
                                  final row = entry.value;
                                  final label = row.leaveTypeName ?? row.leaveTypeId;
                                  final credited = row.creditedDays;
                                  final remaining = row.remainingDays ?? 0;
                                  final additional =
                                      row.additionalOutstandingDays ?? 0;
                                  final muted = row.isActive == false;
                                  final rowColor = muted
                                      ? cs.onSurfaceVariant
                                      : textPrimary;
                                  return Row(
                                    children: [
                                      Expanded(
                                        flex: 4,
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                label,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: rowColor,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            if (muted) ...[
                                              const SizedBox(width: 4),
                                              Icon(
                                                Icons.block,
                                                size: 12,
                                                color: cs.onSurfaceVariant,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          credited == null
                                              ? '-'
                                              : _formatLeaveBalance(credited),
                                          textAlign: TextAlign.end,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: rowColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          _formatLeaveBalance(remaining),
                                          textAlign: TextAlign.end,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: rowColor,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          _formatLeaveBalance(additional),
                                          textAlign: TextAlign.end,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: additional > 0
                                                ? cs.error
                                                : rowColor,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'Cred: Credited  Rem: Remaining  Add: Additional used',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (showTeamChip || showAllChip)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Mine'),
                      selected: state.scope == LeaveListScope.mine,
                      onSelected: (_) => ref
                          .read(leaveProvider.notifier)
                          .setScope(LeaveListScope.mine),
                      selectedColor: primary.withValues(alpha: 0.25),
                      labelStyle: TextStyle(
                        color: state.scope == LeaveListScope.mine
                            ? primary
                            : textPrimary,
                        fontWeight: state.scope == LeaveListScope.mine
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    if (showTeamChip) ...[
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(
                          state.reportingInfo != null &&
                                  state.reportingInfo!.teamSize > 0
                              ? 'Team (${state.reportingInfo!.teamSize})'
                              : 'Team',
                        ),
                        selected: state.scope == LeaveListScope.team,
                        onSelected: (_) => ref
                            .read(leaveProvider.notifier)
                            .setScope(LeaveListScope.team),
                        selectedColor: primary.withValues(alpha: 0.25),
                        labelStyle: TextStyle(
                          color: state.scope == LeaveListScope.team
                              ? primary
                              : textPrimary,
                          fontWeight: state.scope == LeaveListScope.team
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                    if (showAllChip) ...[
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('All'),
                        selected: state.scope == LeaveListScope.all,
                        onSelected: (_) => ref
                            .read(leaveProvider.notifier)
                            .setScope(LeaveListScope.all),
                        selectedColor: primary.withValues(alpha: 0.25),
                        labelStyle: TextStyle(
                          color: state.scope == LeaveListScope.all
                              ? primary
                              : textPrimary,
                          fontWeight: state.scope == LeaveListScope.all
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (state.scope == LeaveListScope.all && isAdmin)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: cardFill,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Filter all leaves',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () async {
                              final initial =
                                  state.adminAllFilters.startDate ??
                                  DateTime.now();
                              final d = await showDatePicker(
                                context: context,
                                initialDate: initial,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (d != null && context.mounted) {
                                ref
                                    .read(leaveProvider.notifier)
                                    .patchAdminAllFilters(startDate: d);
                              }
                            },
                            child: Text(
                              state.adminAllFilters.startDate == null
                                  ? 'Start date'
                                  : 'From ${_fmtDay(state.adminAllFilters.startDate!)}',
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () async {
                              final initial =
                                  state.adminAllFilters.endDate ??
                                  DateTime.now();
                              final d = await showDatePicker(
                                context: context,
                                initialDate: initial,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (d != null && context.mounted) {
                                ref
                                    .read(leaveProvider.notifier)
                                    .patchAdminAllFilters(endDate: d);
                              }
                            },
                            child: Text(
                              state.adminAllFilters.endDate == null
                                  ? 'End date'
                                  : 'To ${_fmtDay(state.adminAllFilters.endDate!)}',
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              ref
                                  .read(leaveProvider.notifier)
                                  .patchAdminAllFilters(
                                    clearStart: true,
                                    clearEnd: true,
                                  );
                            },
                            child: const Text('Clear dates'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _adminUserIdsController,
                        decoration: const InputDecoration(
                          labelText: 'User IDs (comma-separated)',
                          hintText: 'Optional',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        style: TextStyle(color: textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          FilledButton(
                            onPressed: () {
                              ref
                                  .read(leaveProvider.notifier)
                                  .patchAdminAllFilters(
                                    userIds: _adminUserIdsController.text,
                                  );
                              ref
                                  .read(leaveProvider.notifier)
                                  .applyAdminAllFiltersAndReload();
                            },
                            child: const Text('Apply'),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              _adminUserIdsController.clear();
                              ref
                                  .read(leaveProvider.notifier)
                                  .clearAdminAllFilters();
                              ref.read(leaveProvider.notifier).loadLeaves();
                            },
                            child: const Text('Reset filters'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await ref.read(leaveProvider.notifier).loadReportingInfo();
                await ref.read(leaveProvider.notifier).loadLeaves();
              },
              child: state.isLoading && state.leaves.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : state.leaves.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.3,
                        ),
                        Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.event_busy_outlined,
                                size: 64,
                                color: textSecondary,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No leave requests here',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try another tab or tap Apply',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: textSecondary.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                      itemCount: state.leaves.length,
                      itemBuilder: (context, i) {
                        final entry = state.leaves[i];
                        final isTeam = state.scope == LeaveListScope.team;
                        final showTeamActions = isTeam && entry.isPending;
                        return _LeaveTile(
                          entry: entry,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          showApplicant: state.scope != LeaveListScope.mine,
                          onTileTap: canOpenLeaveDetail
                              ? () {
                                  Navigator.push<void>(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          LeaveDetailPage(leaveId: entry.id),
                                    ),
                                  );
                                }
                              : null,
                          onApprove: showTeamActions
                              ? () => _confirmApproveTeam(context, entry.id)
                              : null,
                          onReject: showTeamActions
                              ? () => _confirmRejectTeam(context, entry.id)
                              : null,
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmApproveTeam(BuildContext context, String leaveId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve leave'),
        content: const Text('Approve this leave request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(leaveProvider.notifier).approveLeave(leaveId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Leave approved')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _confirmRejectTeam(BuildContext context, String leaveId) async {
    final controller = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject leave'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'Why is this request rejected?',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    final reason = controller.text.trim();
    controller.dispose();
    if (submitted != true || !context.mounted) return;
    if (reason.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a rejection reason')),
      );
      return;
    }
    try {
      await ref.read(leaveProvider.notifier).rejectLeave(leaveId, reason);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Leave rejected')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Widget _buildComingSoon(BuildContext context) {
    final bg = AppThemeColors.backgroundColor(context);
    final surface = AppThemeColors.surfaceColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text('Leave', style: TextStyle(color: textPrimary)),
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.event_available_outlined,
                size: 64,
                color: textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                'Coming soon',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Leave management will be available soon.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaveTile extends StatelessWidget {
  const _LeaveTile({
    required this.entry,
    required this.textPrimary,
    required this.textSecondary,
    required this.showApplicant,
    this.onTileTap,
    this.onApprove,
    this.onReject,
  });

  final LeaveEntry entry;
  final Color textPrimary;
  final Color textSecondary;
  final bool showApplicant;
  final VoidCallback? onTileTap;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  String _dateRange() {
    final a = entry.startDate;
    final b = entry.endDate;
    if (a == null && b == null) return '—';
    if (a != null && b != null) {
      if (a.year == b.year && a.month == b.month && a.day == b.day) {
        return _fmt(a);
      }
      return '${_fmt(a)} → ${_fmt(b)}';
    }
    return _fmt(a ?? b!);
  }

  String _fmt(DateTime d) {
    final x = d.toLocal();
    return '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
  }

  /// Prefer working days; otherwise total days; half-day hint if counts missing.
  String? _daysSummaryLine() {
    final w = entry.workingDays;
    final t = entry.totalDays;
    if (w != null) {
      return _formatDaysCount(w, working: true);
    }
    if (t != null) {
      return _formatDaysCount(t, working: false);
    }
    if (entry.isHalfDay == true) {
      return '0.5 day';
    }
    return null;
  }

  String _formatDaysCount(num n, {required bool working}) {
    final d = n.toDouble();
    final suffix = working ? ' working' : '';
    if (d == 0.5) return '0.5$suffix day';
    if (d == 1) return '1$suffix day';
    if (d == d.roundToDouble()) {
      return '${d.round()}$suffix days';
    }
    return '$n$suffix days';
  }

  bool get _isAdditionalLeave {
    final v = entry.additionalLeaveDays;
    return v != null && v.toDouble() > 0;
  }

  String _formatAdditionalDays(num n) {
    final d = n.toDouble();
    if (d == 1) return '1 day';
    if (d == d.roundToDouble()) return '${d.round()} days';
    return '$d days';
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final tonal = AppThemeColors.tonalForAccent(context, primary);
    final daysLine = _daysSummaryLine();

    return CRMCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: onTileTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tonal.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.event_available_outlined,
                  color: tonal.foreground,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            entry.leaveTypeName ??
                                entry.leaveTypeId ??
                                'Leave request',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(status: entry.status, type: 'leave'),
                      ],
                    ),
                    if (_isAdditionalLeave) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.tertiaryContainer.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Additional leave (${_formatAdditionalDays(entry.additionalLeaveDays!)})',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onTertiaryContainer,
                          ),
                        ),
                      ),
                    ],
                    if (showApplicant &&
                        entry.userName != null &&
                        entry.userName!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        entry.userName!,
                        style: TextStyle(fontSize: 13, color: textSecondary),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.date_range, size: 18, color: textSecondary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _dateRange(),
                            style: TextStyle(
                              fontSize: 14,
                              color: textSecondary,
                            ),
                          ),
                        ),
                        if (entry.isHalfDay == true)
                          Text(
                            'Half day',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                    if (daysLine != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.timelapse_outlined,
                            size: 18,
                            color: textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              daysLine,
                              style: TextStyle(
                                fontSize: 14,
                                color: textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (entry.reason != null &&
                        entry.reason!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        entry.reason!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (onApprove != null && onReject != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    onPressed: onApprove,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
