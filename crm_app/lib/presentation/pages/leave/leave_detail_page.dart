import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../data/models/leave_model.dart';
import '../../../data/repositories/leave_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leave_provider.dart';
import 'leave_edit_page.dart';

class LeaveDetailPage extends ConsumerStatefulWidget {
  const LeaveDetailPage({super.key, required this.leaveId});

  final String leaveId;

  @override
  ConsumerState<LeaveDetailPage> createState() => _LeaveDetailPageState();
}

class _LeaveDetailPageState extends ConsumerState<LeaveDetailPage> {
  LeaveEntry? _entry;
  bool _loading = true;
  String? _loadError;

  static final _dateFmt = DateFormat('MMM d, y');
  static final _appliedFmt = DateFormat("MMM d, y 'at' h:mm a");

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final repo = ref.read(leaveRepositoryProvider);
      final e = await repo.getLeaveById(widget.leaveId);
      if (mounted) {
        setState(() {
          _entry = e;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _onApprove() async {
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
    if (ok != true || !mounted) return;
    try {
      await ref.read(leaveProvider.notifier).approveLeave(widget.leaveId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave approved')),
        );
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _onReject() async {
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
    if (submitted != true || !mounted) return;
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a rejection reason')),
      );
      return;
    }
    try {
      await ref.read(leaveProvider.notifier).rejectLeave(widget.leaveId, reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave rejected')),
        );
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  String _prettyStatus(String s) {
    if (s.isEmpty) return '—';
    return s
        .split(RegExp(r'[\s_]+'))
        .where((w) => w.isNotEmpty)
        .map(
          (w) =>
              '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  String _durationTitle(LeaveEntry entry) {
    final mode = LeaveApplyDurationMode.fromApiValue(entry.durationType);
    if (mode != null) {
      return switch (mode) {
        LeaveApplyDurationMode.halfDay => 'Half Day',
        LeaveApplyDurationMode.singleDay => 'Single Day',
        LeaveApplyDurationMode.multipleDays => 'Multiple Days',
      };
    }
    final raw = entry.durationType?.replaceAll('_', ' ').trim();
    if (raw == null || raw.isEmpty) {
      if (entry.isHalfDay == true) return 'Half Day';
      return '—';
    }
    return raw.split(' ').map((w) {
      if (w.isEmpty) return w;
      return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
    }).join(' ');
  }

  String? _durationSubtitle(LeaveEntry entry) {
    final mode = LeaveApplyDurationMode.fromApiValue(entry.durationType);
    final isHalf = mode == LeaveApplyDurationMode.halfDay || entry.isHalfDay == true;
    if (!isHalf) return null;
    final part = LeaveHalfDayPart.fromApiValue(entry.halfDayPart);
    if (part != null) return part.label;
    final raw = entry.halfDayPart?.replaceAll('_', ' ').trim();
    if (raw == null || raw.isEmpty) return null;
    return raw.split(' ').map((w) {
      if (w.isEmpty) return w;
      return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
    }).join(' ');
  }

  String _dateLine(LeaveEntry entry) {
    final a = entry.startDate;
    final b = entry.endDate;
    if (a == null && b == null) return '—';
    if (a != null && b != null && a != b) {
      return '${_dateFmt.format(a)} – ${_dateFmt.format(b)}';
    }
    final d = a ?? b;
    return d != null ? _dateFmt.format(d) : '—';
  }

  String _leaveDaysLine(LeaveEntry entry) {
    final n = entry.workingDays ?? entry.totalDays;
    if (n == null) return '—';
    final d = n.toDouble();
    if (d == 0.5) return '0.5day';
    if (d == 1) return '1day';
    if (d == d.roundToDouble()) return '${d.round()}days';
    return '${n}day';
  }

  String _appliedOnLine(LeaveEntry entry) {
    final t = entry.createdAt ?? entry.updatedAt;
    if (t == null) return '—';
    return _appliedFmt.format(t.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppThemeColors.backgroundColor(context);
    final surface = AppThemeColors.surfaceColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final borderColor = AppThemeColors.borderColor(context);
    final scope = ref.watch(leaveProvider.select((s) => s.scope));
    final currentUserId = ref.watch(currentUserIdProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final isReporting =
        ref.watch(leaveProvider.select((s) => s.reportingInfo?.isReportingManager ?? false));

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(
          'Leave Request Details',
          style: TextStyle(color: textPrimary),
        ),
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        actions: [
          if (!_loading && _entry != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _load,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_loadError!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildBody(
                  context,
                  _entry!,
                  textPrimary,
                  textSecondary,
                  surface,
                  borderColor,
                  scope,
                  currentUserId,
                  isAdmin,
                  isReporting,
                ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    LeaveEntry entry,
    Color textPrimary,
    Color textSecondary,
    Color surface,
    Color borderColor,
    LeaveListScope scope,
    String? currentUserId,
    bool isAdmin,
    bool isReporting,
  ) {
    final isOwnLeave = currentUserId != null &&
        (entry.userId == null || entry.userId == currentUserId);
    final canEdit = entry.isPending && isOwnLeave;
    final showApproveReject = entry.isPending &&
        !isOwnLeave &&
        ((scope == LeaveListScope.team && (isReporting || isAdmin)) ||
            (scope == LeaveListScope.all && isAdmin));

    final typeLabel =
        (entry.leaveTypeName ?? entry.leaveTypeId)?.trim().isNotEmpty == true
            ? (entry.leaveTypeName ?? entry.leaveTypeId)!.trim()
            : '—';
    final durationSub = _durationSubtitle(entry);
    final st = entry.status.toLowerCase();
    final approved = st == 'approved' || st == 'accept';
    final rejected = st == 'rejected' || st == 'denied';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _field('Leave Type', typeLabel, textPrimary, textSecondary),
              _divider(borderColor),
              _field('Status', _prettyStatus(entry.status), textPrimary, textSecondary),
              _divider(borderColor),
              _field(
                'Duration',
                _durationTitle(entry),
                textPrimary,
                textSecondary,
                extraValue: durationSub,
              ),
              _divider(borderColor),
              _field('Date', _dateLine(entry), textPrimary, textSecondary),
              _divider(borderColor),
              _leaveCountField(entry, textPrimary, textSecondary),
              _divider(borderColor),
              _field(
                'Reason',
                entry.reason?.trim().isNotEmpty == true ? entry.reason!.trim() : '—',
                textPrimary,
                textSecondary,
              ),
              if (entry.rejectReason != null && entry.rejectReason!.trim().isNotEmpty) ...[
                _divider(borderColor),
                _field(
                  'Rejection Reason',
                  entry.rejectReason!.trim(),
                  textPrimary,
                  textSecondary,
                ),
              ],
              _divider(borderColor),
              _field('Applied On', _appliedOnLine(entry), textPrimary, textSecondary),
              if (approved &&
                  entry.approvedByName != null &&
                  entry.approvedByName!.trim().isNotEmpty) ...[
                _divider(borderColor),
                _field(
                  'Approved By',
                  entry.approvedByName!.trim(),
                  textPrimary,
                  textSecondary,
                ),
              ],
              if (rejected &&
                  entry.rejectedByName != null &&
                  entry.rejectedByName!.trim().isNotEmpty) ...[
                _divider(borderColor),
                _field(
                  'Rejected By',
                  entry.rejectedByName!.trim(),
                  textPrimary,
                  textSecondary,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (canEdit)
          FilledButton.icon(
            onPressed: () async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => LeaveEditPage(leaveId: widget.leaveId),
                ),
              );
              await _load();
            },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit request'),
          ),
        if (showApproveReject) ...[
          if (canEdit) const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _onReject,
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _onApprove,
                  child: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _divider(Color borderColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Divider(height: 1, thickness: 1, color: borderColor),
    );
  }

  Widget _field(
    String label,
    String value,
    Color textPrimary,
    Color textSecondary, {
    String? extraValue,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        SelectableText(
          value,
          style: TextStyle(
            fontSize: 16,
            color: textPrimary,
            height: 1.35,
          ),
        ),
        if (extraValue != null && extraValue.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            extraValue,
            style: TextStyle(
              fontSize: 15,
              color: textPrimary,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }

  Widget _leaveCountField(
    LeaveEntry entry,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Leave count',
          style: TextStyle(
            fontSize: 13,
            color: textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Working days — weekends and company holidays excluded',
          style: TextStyle(
            fontSize: 12,
            color: textSecondary,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 6),
        SelectableText(
          _leaveDaysLine(entry),
          style: TextStyle(
            fontSize: 16,
            color: textPrimary,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}
