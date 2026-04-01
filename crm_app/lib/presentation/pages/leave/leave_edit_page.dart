import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../data/models/leave_model.dart';
import '../../../data/repositories/leave_repository.dart';
import '../../providers/leave_provider.dart';

class LeaveEditPage extends ConsumerStatefulWidget {
  const LeaveEditPage({super.key, required this.leaveId});

  final String leaveId;

  @override
  ConsumerState<LeaveEditPage> createState() => _LeaveEditPageState();
}

class _LeaveEditPageState extends ConsumerState<LeaveEditPage> {
  String? _leaveTypeId;
  LeaveApplyDurationMode _durationMode = LeaveApplyDurationMode.singleDay;
  DateTime? _leaveDate;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  LeaveHalfDayPart? _halfDayPart;
  final _reasonCtrl = TextEditingController();
  bool _loading = true;
  bool _submitting = false;
  String? _loadError;
  String? _attachmentFileName;
  String? _attachmentData;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  static DateTime _dateOnly(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  String _formatDate(DateTime d) {
    final x = d.toLocal();
    return '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadEntry();
      ref.read(leaveProvider.notifier).loadTypes();
    });
  }

  Future<void> _loadEntry() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final repo = ref.read(leaveRepositoryProvider);
      final e = await repo.getLeaveById(widget.leaveId);
      DateTime? start = e.startDate;
      DateTime? end = e.endDate;
      if (start != null) start = _dateOnly(start);
      if (end != null) end = _dateOnly(end);

      LeaveApplyDurationMode mode =
          LeaveApplyDurationMode.fromApiValue(e.durationType) ??
              LeaveApplyDurationMode.singleDay;
      if (e.durationType == null &&
          start != null &&
          end != null &&
          (start.year != end.year ||
              start.month != end.month ||
              start.day != end.day)) {
        mode = LeaveApplyDurationMode.multipleDays;
      } else if (e.durationType == null && e.isHalfDay == true) {
        mode = LeaveApplyDurationMode.halfDay;
      }

      if (!mounted) return;
      setState(() {
        _leaveTypeId = e.leaveTypeId;
        _durationMode = mode;
        _halfDayPart = LeaveHalfDayPart.fromApiValue(e.halfDayPart);
        if (mode == LeaveApplyDurationMode.multipleDays) {
          _rangeStart = start;
          _rangeEnd = end;
          _leaveDate = null;
        } else {
          _leaveDate = start;
          _rangeStart = null;
          _rangeEnd = null;
        }
        _reasonCtrl.text = e.reason ?? '';
        _attachmentFileName = e.attachmentFileName;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickLeaveDate() async {
    final now = DateTime.now();
    final initial = _leaveDate ?? now;
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (d != null) setState(() => _leaveDate = _dateOnly(d));
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initialStart = _rangeStart ?? now;
    final initialEnd = _rangeEnd ?? initialStart;
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
    );
    if (range != null) {
      setState(() {
        _rangeStart = _dateOnly(range.start);
        _rangeEnd = _dateOnly(range.end);
      });
    }
  }

  Future<void> _pickAttachment() async {
    final r = await FilePicker.platform.pickFiles(withData: true);
    if (r == null || r.files.isEmpty) return;
    final f = r.files.first;
    final bytes = f.bytes;
    if (bytes == null) return;
    setState(() {
      _attachmentFileName = f.name;
      _attachmentData = base64Encode(bytes);
    });
  }

  void _onDurationModeChanged(LeaveApplyDurationMode mode) {
    setState(() {
      _durationMode = mode;
      if (mode == LeaveApplyDurationMode.halfDay) {
        _halfDayPart = _halfDayPart ?? LeaveHalfDayPart.firstHalf;
      } else {
        _halfDayPart = null;
      }
    });
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    if (_leaveTypeId == null || _leaveTypeId!.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Select a leave type')),
      );
      return;
    }

    late final DateTime start;
    late final DateTime end;

    if (_durationMode == LeaveApplyDurationMode.singleDay) {
      if (_leaveDate == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Select leave date')),
        );
        return;
      }
      start = _leaveDate!;
      end = _leaveDate!;
    } else if (_durationMode == LeaveApplyDurationMode.halfDay) {
      if (_leaveDate == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Select leave date')),
        );
        return;
      }
      start = _leaveDate!;
      end = _leaveDate!;
    } else {
      if (_rangeStart == null || _rangeEnd == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Select start and end dates')),
        );
        return;
      }
      start = _rangeStart!;
      end = _rangeEnd!;
      if (end.isBefore(start)) {
        messenger.showSnackBar(
          const SnackBar(content: Text('End date must be on or after start')),
        );
        return;
      }
    }

    final reason = _reasonCtrl.text.trim();

    setState(() => _submitting = true);
    try {
      await ref.read(leaveProvider.notifier).updateLeave(
            leaveId: widget.leaveId,
            leaveTypeId: _leaveTypeId!,
            startDate: start,
            endDate: end,
            reason: reason.isEmpty ? null : reason,
            durationMode: _durationMode,
            halfDayPart: _durationMode == LeaveApplyDurationMode.halfDay
                ? (_halfDayPart ?? LeaveHalfDayPart.firstHalf)
                : null,
            attachmentFileName: _attachmentFileName,
            attachmentData: _attachmentData,
          );
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Leave updated')),
        );
        nav.pop();
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppThemeColors.backgroundColor(context);
    final surface = AppThemeColors.surfaceColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final borderColor = AppThemeColors.borderColor(context);
    final types = ref.watch(leaveProvider.select((s) => s.types));

    if (_loading) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppThemeColors.appBarTitle(context, 'Edit leave'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppThemeColors.appBarTitle(context, 'Edit leave'),
        body: Center(
          child: Padding(
            padding: AppThemeColors.pagePaddingAll,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_loadError!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _loadEntry, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    final typeList = types.isNotEmpty
        ? types
        : (_leaveTypeId != null
            ? [
                LeaveTypeOption(
                  id: _leaveTypeId!,
                  name: _leaveTypeId!,
                ),
              ]
            : <LeaveTypeOption>[]);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppThemeColors.appBarTitle(context, 'Edit leave'),
      body: ListView(
        padding: AppThemeColors.pagePaddingAll,
        children: [
          _sectionLabel('Leave type', textSecondary),
          const SizedBox(height: 8),
          if (typeList.isEmpty)
            Text(
              'No leave types loaded. Check connection and try again.',
              style: TextStyle(color: textSecondary),
            )
          else
            RadioGroup<String>(
              groupValue: _leaveTypeId,
              onChanged: (v) => setState(() => _leaveTypeId = v),
              child: Column(
                children: typeList
                    .map(
                      (t) => RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        value: t.id,
                        title: Text(
                          t.name,
                          style: TextStyle(color: textPrimary),
                        ),
                        activeColor: Theme.of(context).colorScheme.primary,
                      ),
                    )
                    .toList(),
              ),
            ),
          TextButton(
            onPressed: () => ref.read(leaveProvider.notifier).loadTypes(),
            child: const Text('Refresh leave types'),
          ),
          const SizedBox(height: 16),
          _sectionLabel('Duration type', textSecondary),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: LeaveApplyDurationMode.values.map((m) {
              return ChoiceChip(
                label: Text(m.label),
                selected: _durationMode == m,
                onSelected: (selected) {
                  if (selected) _onDurationModeChanged(m);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          if (_durationMode == LeaveApplyDurationMode.singleDay) ...[
            _sectionLabel('Leave date', textSecondary),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickLeaveDate,
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(
                _leaveDate == null ? 'Select date' : _formatDate(_leaveDate!),
              ),
            ),
          ],
          if (_durationMode == LeaveApplyDurationMode.halfDay) ...[
            _sectionLabel('Leave date', textSecondary),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickLeaveDate,
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(
                _leaveDate == null ? 'Select date' : _formatDate(_leaveDate!),
              ),
            ),
            const SizedBox(height: 16),
            _sectionLabel('Session', textSecondary),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: LeaveHalfDayPart.values.map((p) {
                return ChoiceChip(
                  label: Text(p.label),
                  selected: _halfDayPart == p,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _halfDayPart = p);
                    }
                  },
                );
              }).toList(),
            ),
          ],
          if (_durationMode == LeaveApplyDurationMode.multipleDays) ...[
            _sectionLabel('Date range', textSecondary),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickDateRange,
              icon: const Icon(Icons.date_range, size: 18),
              label: Text(
                _rangeStart == null || _rangeEnd == null
                    ? 'Select date range'
                    : '${_formatDate(_rangeStart!)} → ${_formatDate(_rangeEnd!)}',
              ),
            ),
          ],
          const SizedBox(height: 20),
          _sectionLabel('Reason', textSecondary),
          const SizedBox(height: 8),
          TextField(
            controller: _reasonCtrl,
            maxLines: 5,
            decoration: InputDecoration(
              filled: true,
              fillColor: surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickAttachment,
            icon: const Icon(Icons.attach_file, size: 18),
            label: Text(
              _attachmentFileName == null || _attachmentFileName!.isEmpty
                  ? 'Replace attachment (optional)'
                  : _attachmentFileName!,
            ),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save changes'),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}
