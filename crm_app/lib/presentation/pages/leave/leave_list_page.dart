import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leave_provider.dart';
import '../../../data/models/leave_model.dart';
import 'leave_apply_page.dart';
import 'leave_detail_page.dart';
import 'leave_module_flags.dart';

class LeaveListPage extends ConsumerStatefulWidget {
  const LeaveListPage({super.key});

  @override
  ConsumerState<LeaveListPage> createState() => _LeaveListPageState();
}

class _LeaveListPageState extends ConsumerState<LeaveListPage> {
  @override
  void initState() {
    super.initState();
    if (kLeaveModuleComingSoon) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(leaveProvider.notifier).bootstrapList();
    });
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
    final primary = Theme.of(context).colorScheme.primary;

    final showTeamChip =
        isAdmin || (state.reportingInfo?.isReportingManager ?? false);
    final showAllChip = isAdmin;

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
        title: const Text('Leave'),
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
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
                      selectedColor: primary.withOpacity(0.25),
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
                        selectedColor: primary.withOpacity(0.25),
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
                        selectedColor: primary.withOpacity(0.25),
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
                                      color: textSecondary.withOpacity(0.85),
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
                            final showTeamActions =
                                isTeam && entry.isPending;
                            return _LeaveTile(
                              entry: entry,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                              surface: surface,
                              showApplicant:
                                  state.scope != LeaveListScope.mine,
                              onTileTap: isTeam
                                  ? null
                                  : () {
                                      Navigator.push<void>(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (_) => LeaveDetailPage(
                                            leaveId: entry.id,
                                          ),
                                        ),
                                      );
                                    },
                              onApprove: showTeamActions
                                  ? () => _confirmApproveTeam(
                                        context,
                                        entry.id,
                                      )
                                  : null,
                              onReject: showTeamActions
                                  ? () => _confirmRejectTeam(
                                        context,
                                        entry.id,
                                      )
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Leave approved')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Leave rejected')),
      );
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
        title: const Text('Leave'),
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
    required this.surface,
    required this.showApplicant,
    this.onTileTap,
    this.onApprove,
    this.onReject,
  });

  final LeaveEntry entry;
  final Color textPrimary;
  final Color textSecondary;
  final Color surface;
  final bool showApplicant;
  final VoidCallback? onTileTap;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'approved':
      case 'accept':
        return Colors.green.shade700;
      case 'rejected':
      case 'denied':
        return Colors.red.shade700;
      case 'pending':
      case 'submitted':
        return Colors.orange.shade800;
      case 'cancelled':
      case 'canceled':
        return Colors.grey.shade600;
      default:
        return Colors.blueGrey;
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final status = entry.status;
    final chipColor = _statusColor(status);
    final primary = Theme.of(context).colorScheme.primary;

    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: chipColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: chipColor,
                  ),
                ),
              ),
            ],
          ),
          if (showApplicant &&
              entry.userName != null &&
              entry.userName!.isNotEmpty) ...[
            const SizedBox(height: 6),
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
              Text(
                _dateRange(),
                style: TextStyle(fontSize: 14, color: textSecondary),
              ),
              if (entry.isHalfDay == true) ...[
                const SizedBox(width: 12),
                Text(
                  'Half day',
                  style: TextStyle(
                    fontSize: 12,
                    color: textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
          if (entry.reason != null && entry.reason!.trim().isNotEmpty) ...[
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
                      foregroundColor:
                          Theme.of(context).colorScheme.onPrimary,
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

    return Card(
      color: surface,
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: chipColor.withOpacity(0.35), width: 1),
      ),
      child: onTileTap != null
          ? InkWell(
              onTap: onTileTap,
              borderRadius: BorderRadius.circular(12),
              child: content,
            )
          : content,
    );
  }
}
