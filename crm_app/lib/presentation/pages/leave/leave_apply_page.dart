import 'dart:async';
import 'dart:convert';

import 'package:confetti/confetti.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../data/models/leave_model.dart';
import '../../providers/leave_provider.dart';
import '../../widgets/celebration_shell.dart';

class LeaveApplyPage extends ConsumerStatefulWidget {
  const LeaveApplyPage({super.key});

  @override
  ConsumerState<LeaveApplyPage> createState() => _LeaveApplyPageState();
}

class _LeaveApplyPageState extends ConsumerState<LeaveApplyPage> {
  String? _leaveTypeId;
  LeaveApplyDurationMode _durationMode = LeaveApplyDurationMode.singleDay;

  DateTime? _leaveDate;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  LeaveHalfDayPart? _halfDayPart;
  final _reasonCtrl = TextEditingController();
  bool _submitting = false;
  bool _celebrating = false;
  late ConfettiController _confettiController;
  Timer? _workingDaysDebounce;
  int? _workingDays;
  bool _workingDaysLoading = false;
  String? _attachmentFileName;
  String? _attachmentData;

  @override
  void dispose() {
    _workingDaysDebounce?.cancel();
    _confettiController.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(leaveProvider.notifier).loadTypes();
    });
  }

  static DateTime _dateOnly(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  String _formatDate(DateTime d) {
    final x = d.toLocal();
    return '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
  }

  /// [calculate-days] returns full-day counts for the range; half-day leave is half that amount.
  String _formatHalfDayWorkingAmount(int fullDayCount) {
    final v = fullDayCount * 0.5;
    if (v == v.roundToDouble()) {
      return v.toInt().toString();
    }
    return v.toString();
  }

  void _scheduleWorkingDaysCalc() {
    _workingDaysDebounce?.cancel();
    _workingDaysDebounce = Timer(const Duration(milliseconds: 450), () {
      _recalcWorkingDays();
    });
  }

  Future<void> _recalcWorkingDays() async {
    DateTime? start;
    DateTime? end;

    switch (_durationMode) {
      case LeaveApplyDurationMode.singleDay:
      case LeaveApplyDurationMode.halfDay:
        if (_leaveDate == null) {
          if (mounted) setState(() => _workingDays = null);
          return;
        }
        start = _leaveDate;
        end = _leaveDate;
      case LeaveApplyDurationMode.multipleDays:
        if (_rangeStart == null || _rangeEnd == null) {
          if (mounted) setState(() => _workingDays = null);
          return;
        }
        start = _rangeStart;
        end = _rangeEnd;
        if (end!.isBefore(start!)) {
          if (mounted) setState(() => _workingDays = null);
          return;
        }
    }

    if (start == null || end == null) return;

    if (mounted) {
      setState(() {
        _workingDaysLoading = true;
      });
    }
    try {
      final days = await ref.read(leaveProvider.notifier).calculateWorkingDays(
            startDate: start,
            endDate: end,
          );
      if (mounted) {
        setState(() {
          _workingDays = days;
          _workingDaysLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _workingDays = null;
          _workingDaysLoading = false;
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
    if (d != null) {
      setState(() => _leaveDate = _dateOnly(d));
      _scheduleWorkingDaysCalc();
    }
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
      _scheduleWorkingDaysCalc();
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
        // Must not stay null: chips may not report selection on some Flutter builds.
        _halfDayPart = LeaveHalfDayPart.firstHalf;
      } else {
        _halfDayPart = null;
      }
      _workingDays = null;
    });
    _scheduleWorkingDaysCalc();
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
          const SnackBar(
            content: Text('End date must be on or after start'),
          ),
        );
        return;
      }
    }

    final reason = _reasonCtrl.text.trim();

    setState(() => _submitting = true);
    try {
      await ref.read(leaveProvider.notifier).applyLeave(
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
        HapticFeedback.mediumImpact();
        setState(() {
          _submitting = false;
          _celebrating = true;
        });
        _confettiController.play();
        await Future.delayed(const Duration(milliseconds: 2800));
        if (mounted) nav.pop();
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
      if (mounted && !_celebrating) setState(() => _submitting = false);
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
    final typesLoading = ref.watch(leaveProvider.select((s) => s.typesLoading));

    return CelebrationShell(
      celebrating: _celebrating,
      confettiController: _confettiController,
      title: 'Request sent!',
      message: 'Your leave request was submitted.',
      icon: Icons.event_available_rounded,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          title: const Text('Apply for leave'),
          backgroundColor: surface,
          foregroundColor: textPrimary,
          elevation: 0,
        ),
        body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionLabel('Leave type', textSecondary),
          const SizedBox(height: 8),
          if (typesLoading && types.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (types.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No leave types returned from the server.',
                  style: TextStyle(color: textSecondary),
                ),
                TextButton(
                  onPressed: () => ref.read(leaveProvider.notifier).loadTypes(),
                  child: const Text('Retry'),
                ),
              ],
            )
          else
            RadioGroup<String>(
              groupValue: _leaveTypeId,
              onChanged: (v) => setState(() => _leaveTypeId = v),
              child: Column(
                children: types
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
          if (types.isNotEmpty)
            TextButton(
              onPressed: () => ref.read(leaveProvider.notifier).loadTypes(),
              child: const Text('Refresh leave types'),
            ),
          const SizedBox(height: 20),
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
                _leaveDate == null
                    ? 'Select date'
                    : _formatDate(_leaveDate!),
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
                _leaveDate == null
                    ? 'Select date'
                    : _formatDate(_leaveDate!),
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
          const SizedBox(height: 12),
          if (_workingDaysLoading)
            Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Calculating working days…',
                  style: TextStyle(fontSize: 13, color: textSecondary),
                ),
              ],
            )
          else if (_workingDays != null)
            Text(
              _durationMode == LeaveApplyDurationMode.halfDay
                  ? 'Working days (leave): ${_formatHalfDayWorkingAmount(_workingDays!)}'
                  : 'Working days in range: $_workingDays',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
          const SizedBox(height: 20),
          _sectionLabel('Reason for leave', textSecondary),
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
              hintText: 'Describe why you need this leave…',
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickAttachment,
            icon: const Icon(Icons.attach_file, size: 18),
            label: Text(
              _attachmentFileName == null || _attachmentFileName!.isEmpty
                  ? 'Attachment (optional)'
                  : _attachmentFileName!,
            ),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: (_submitting || _celebrating) ? null : _submit,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _submitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit request'),
          ),
        ],
      ),
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
