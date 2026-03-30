import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
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

  Future<void> _openAttachmentUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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

  String _fmt(DateTime? d) {
    if (d == null) return '—';
    final x = d.toLocal();
    return '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppThemeColors.backgroundColor(context);
    final surface = AppThemeColors.surfaceColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final scope = ref.watch(leaveProvider.select((s) => s.scope));
    final currentUserId = ref.watch(currentUserIdProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final isReporting =
        ref.watch(leaveProvider.select((s) => s.reportingInfo?.isReportingManager ?? false));

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Leave details'),
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

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          entry.leaveTypeName ?? entry.leaveTypeId ?? 'Leave',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text('Status: ${entry.status}', style: TextStyle(color: textSecondary)),
        if (entry.userName != null && entry.userName!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Employee: ${entry.userName}', style: TextStyle(color: textSecondary)),
        ],
        const SizedBox(height: 20),
        _row(Icons.date_range, 'Dates', '${_fmt(entry.startDate)} → ${_fmt(entry.endDate)}', textPrimary, textSecondary),
        if (entry.isHalfDay == true)
          _row(Icons.wb_twilight, 'Half day', entry.halfDayPart ?? 'Yes', textPrimary, textSecondary),
        if (entry.reason != null && entry.reason!.trim().isNotEmpty)
          _row(Icons.notes, 'Reason', entry.reason!.trim(), textPrimary, textSecondary),
        if (entry.rejectReason != null && entry.rejectReason!.trim().isNotEmpty)
          _row(Icons.block, 'Rejection reason', entry.rejectReason!.trim(), textPrimary, textSecondary),
        if (entry.attachmentFileName != null &&
            entry.attachmentFileName!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Attachment', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
          const SizedBox(height: 6),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.attach_file),
            title: Text(entry.attachmentFileName!, style: TextStyle(color: textPrimary)),
            subtitle: entry.attachmentUrl != null && entry.attachmentUrl!.startsWith('http')
                ? TextButton(
                    onPressed: () => _openAttachmentUrl(entry.attachmentUrl!),
                    child: const Text('Open link'),
                  )
                : null,
          ),
        ],
        const SizedBox(height: 28),
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

  Widget _row(IconData icon, String label, String value, Color p, Color s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: s),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: s)),
                Text(value, style: TextStyle(fontSize: 15, color: p, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
