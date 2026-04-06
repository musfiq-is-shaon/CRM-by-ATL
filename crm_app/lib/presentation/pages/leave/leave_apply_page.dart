import 'dart:async';
import 'dart:convert';

import 'package:confetti/confetti.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../data/models/leave_model.dart';
import '../../../data/repositories/leave_repository.dart';
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
  bool _existingLeavesLoading = false;
  String? _existingLeavesError;
  List<LeaveEntry> _existingLeaves = const [];
  String? _nonWorkingDayMessage;

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.wait([
        ref.read(leaveProvider.notifier).loadTypes(),
        ref.read(leaveProvider.notifier).loadMyBalances(),
      ]);
      await _loadExistingMyLeaves();
    });
  }

  Future<void> _loadExistingMyLeaves() async {
    if (!mounted) return;
    setState(() {
      _existingLeavesLoading = true;
      _existingLeavesError = null;
    });
    try {
      final repo = ref.read(leaveRepositoryProvider);
      final rows = await repo.getMyLeaves();
      if (!mounted) return;
      setState(() {
        _existingLeaves = rows;
        _existingLeavesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _existingLeavesLoading = false;
        _existingLeavesError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  static String _fmtBalance(double v) {
    if (v == v.roundToDouble()) return v.round().toString();
    return v.toStringAsFixed(1);
  }

  /// Remaining days for this leave type, or `null` if no balance row.
  static double? _balanceForType(String typeId, List<LeaveBalanceRow> rows) {
    for (final r in rows) {
      if (r.leaveTypeId == typeId) return r.remainingDays;
    }
    return null;
  }

  bool _datesComplete() {
    switch (_durationMode) {
      case LeaveApplyDurationMode.singleDay:
      case LeaveApplyDurationMode.halfDay:
        return _leaveDate != null;
      case LeaveApplyDurationMode.multipleDays:
        return _rangeStart != null &&
            _rangeEnd != null &&
            !_rangeEnd!.isBefore(_rangeStart!);
    }
  }

  /// Working days consumed by this request (0.5 per day for half-day mode).
  double _requestedLeaveDays() {
    if (_workingDays == null) return 0;
    switch (_durationMode) {
      case LeaveApplyDurationMode.halfDay:
        return _workingDays! * 0.5;
      case LeaveApplyDurationMode.singleDay:
      case LeaveApplyDurationMode.multipleDays:
        return _workingDays!.toDouble();
    }
  }

  bool get _selectedPeriodHasNoWorkingDay =>
      !_workingDaysLoading && _datesComplete() && (_workingDays ?? 0) == 0;

  bool _canSubmit(LeaveState leaveState) {
    if (_submitting || _celebrating) return false;
    if (_existingLeavesLoading) return false;
    if (_existingLeavesError != null) return false;
    if (leaveState.balancesLoading) return false;
    if (leaveState.balancesError != null) return false;
    if (_hasDateOverlapWithExistingLeave() != null) return false;
    if (_leaveTypeId == null || _leaveTypeId!.isEmpty) return false;
    if (!_datesComplete()) return false;
    if (_workingDays == null) return false;
    if (_selectedPeriodHasNoWorkingDay) return false;

    return _requestedLeaveDays() > 0;
  }

  DateTimeRange? _selectedRange() {
    switch (_durationMode) {
      case LeaveApplyDurationMode.singleDay:
      case LeaveApplyDurationMode.halfDay:
        if (_leaveDate == null) return null;
        final d = _dateOnly(_leaveDate!);
        return DateTimeRange(start: d, end: d);
      case LeaveApplyDurationMode.multipleDays:
        if (_rangeStart == null || _rangeEnd == null) return null;
        final s = _dateOnly(_rangeStart!);
        final e = _dateOnly(_rangeEnd!);
        if (e.isBefore(s)) return null;
        return DateTimeRange(start: s, end: e);
    }
  }

  bool _isBlockingLeaveStatus(String status) {
    final s = status.trim().toLowerCase();
    return s != 'rejected' && s != 'cancelled' && s != 'canceled' && s != 'withdrawn';
  }

  LeaveEntry? _hasDateOverlapWithExistingLeave() {
    final selected = _selectedRange();
    if (selected == null) return null;
    for (final e in _existingLeaves) {
      if (!_isBlockingLeaveStatus(e.status)) continue;
      final s = e.startDate;
      final en = e.endDate ?? e.startDate;
      if (s == null || en == null) continue;
      final a = _dateOnly(s);
      final b = _dateOnly(en);
      final rowStart = b.isBefore(a) ? b : a;
      final rowEnd = b.isBefore(a) ? a : b;
      final overlaps =
          !selected.end.isBefore(rowStart) && !selected.start.isAfter(rowEnd);
      if (overlaps) return e;
    }
    return null;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

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
      final days = await ref
          .read(leaveProvider.notifier)
          .calculateWorkingDays(startDate: start, endDate: end);
      if (mounted) {
        final nextMessage = days == 0
            ? (_durationMode == LeaveApplyDurationMode.multipleDays
                  ? 'Selected date range is fully holiday/weekend for your assigned shift. Please choose working days.'
                  : 'Selected date is a holiday/weekend for your assigned shift. Please choose a working day.')
            : null;
        setState(() {
          _workingDays = days;
          _workingDaysLoading = false;
          _nonWorkingDayMessage = nextMessage;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _workingDays = null;
          _workingDaysLoading = false;
          _nonWorkingDayMessage = null;
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
      setState(() {
        _leaveDate = _dateOnly(d);
        _nonWorkingDayMessage = null;
      });
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
        _nonWorkingDayMessage = null;
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
      _nonWorkingDayMessage = null;
    });
    _scheduleWorkingDaysCalc();
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    final leaveState = ref.read(leaveProvider);
    if (!_canSubmit(leaveState)) {
      if (_existingLeavesLoading) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Checking your existing leave dates…')),
        );
        return;
      }
      if (_existingLeavesError != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Could not validate existing leave dates: $_existingLeavesError',
            ),
          ),
        );
        return;
      }
      final overlap = _hasDateOverlapWithExistingLeave();
      if (overlap != null) {
        final startTxt = overlap.startDate == null
            ? ''
            : _formatDate(_dateOnly(overlap.startDate!));
        final endRaw = overlap.endDate ?? overlap.startDate;
        final endTxt = endRaw == null ? '' : _formatDate(_dateOnly(endRaw));
        final rangeText = startTxt.isEmpty
            ? 'an existing leave'
            : (startTxt == endTxt ? startTxt : '$startTxt to $endTxt');
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'You already have a leave on $rangeText (${overlap.status}). '
              'Choose different date(s).',
            ),
          ),
        );
        return;
      }
      if (leaveState.balancesLoading) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Loading your leave balance…')),
        );
        return;
      }
      if (leaveState.balancesError != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Could not verify leave balance: ${leaveState.balancesError}',
            ),
          ),
        );
        return;
      }
      if (_leaveTypeId == null || _leaveTypeId!.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Select a leave type.'),
          ),
        );
        return;
      }
      if (_selectedPeriodHasNoWorkingDay) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              _nonWorkingDayMessage ??
                  'Selected date is holiday/weekend for your assigned shift.',
            ),
          ),
        );
        return;
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Select dates and wait for working days to finish calculating.',
          ),
        ),
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
      await ref
          .read(leaveProvider.notifier)
          .applyLeave(
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
    final leaveState = ref.watch(leaveProvider);
    final types = leaveState.types;
    final typesLoading = leaveState.typesLoading;

    ref.listen<LeaveState>(leaveProvider, (prev, next) {
      if (prev?.balancesLoading == true && !next.balancesLoading && mounted) {
        final id = _leaveTypeId;
        if (id != null) {
          final b = _balanceForType(id, next.myBalances);
          if (b == null || b <= 0) {
            setState(() => _leaveTypeId = null);
          }
        }
      }
    });

    return CelebrationShell(
      celebrating: _celebrating,
      confettiController: _confettiController,
      title: 'Request sent!',
      message: 'Your leave request was submitted.',
      icon: Icons.event_available_rounded,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppThemeColors.appBarTitle(context, 'Apply for leave'),
        body: ListView(
          padding: AppThemeColors.pagePaddingAll,
          children: [
            if (leaveState.balancesError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            leaveState.balancesError!,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onErrorContainer,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            _sectionLabel('Leave type', textSecondary),
            const SizedBox(height: 8),
            if (leaveState.balancesLoading && leaveState.myBalances.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
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
                      'Loading your balances…',
                      style: TextStyle(fontSize: 13, color: textSecondary),
                    ),
                  ],
                ),
              ),
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
                    onPressed: () =>
                        ref.read(leaveProvider.notifier).loadTypes(),
                    child: const Text('Retry'),
                  ),
                ],
              )
            else
              RadioGroup<String>(
                groupValue: _leaveTypeId,
                onChanged: (v) => setState(() => _leaveTypeId = v),
                child: Column(
                  children: types.map((t) {
                    final bal = _balanceForType(t.id, leaveState.myBalances);
                    final loadingBal = leaveState.balancesLoading;
                    String subtitle;
                    if (loadingBal && leaveState.myBalances.isEmpty) {
                      subtitle = 'Loading balance…';
                    } else if (bal == null) {
                      subtitle = 'No balance row (will count as additional leave)';
                    } else if (bal <= 0) {
                      subtitle =
                          'No days remaining (${_fmtBalance(bal)} d). Applies as additional leave.';
                    } else {
                      subtitle = 'Remaining: ${_fmtBalance(bal)} day(s)';
                    }
                    return RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: t.id,
                      enabled: true,
                      title: Text(
                        t.name,
                        style: TextStyle(color: textPrimary),
                      ),
                      subtitle: Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: bal != null && bal > 0
                              ? textSecondary
                              : Colors.orange.shade800,
                        ),
                      ),
                      activeColor: Theme.of(context).colorScheme.primary,
                    );
                  }).toList(),
                ),
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
            if (_nonWorkingDayMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _nonWorkingDayMessage!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.red.shade800,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (_existingLeavesError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Could not validate overlap from previous leaves: $_existingLeavesError',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade800,
                  ),
                ),
              ),
            Builder(
              builder: (context) {
                final overlap = _hasDateOverlapWithExistingLeave();
                if (overlap == null) return const SizedBox.shrink();
                final startTxt = overlap.startDate == null
                    ? ''
                    : _formatDate(_dateOnly(overlap.startDate!));
                final endRaw = overlap.endDate ?? overlap.startDate;
                final endTxt =
                    endRaw == null ? '' : _formatDate(_dateOnly(endRaw));
                final rangeText = startTxt.isEmpty
                    ? 'an existing leave period'
                    : (startTxt == endTxt
                          ? startTxt
                          : '$startTxt to $endTxt');
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'Selected date(s) overlap with your existing leave ($rangeText, ${overlap.status}).',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.red.shade800,
                      height: 1.35,
                    ),
                  ),
                );
              },
            ),
            if (leaveState.balancesError == null &&
                !leaveState.balancesLoading &&
                _leaveTypeId != null &&
                _leaveTypeId!.isNotEmpty) ...[
              Builder(
                builder: (context) {
                  final bal = _balanceForType(
                    _leaveTypeId!,
                    leaveState.myBalances,
                  );
                  if (bal == null) return const SizedBox.shrink();
                  if (!_datesComplete() || _workingDays == null) {
                    return const SizedBox.shrink();
                  }
                  final need = _requestedLeaveDays();
                  if (need <= bal + 1e-9) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'This request needs ${_fmtBalance(need)} day(s) and '
                      'remaining is ${_fmtBalance(bal)}. The excess will be counted as additional leave.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange.shade800,
                        height: 1.35,
                      ),
                    ),
                  );
                },
              ),
            ],
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
              onPressed:
                  (_submitting || _celebrating || !_canSubmit(leaveState))
                  ? null
                  : _submit,
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
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
    );
  }
}






