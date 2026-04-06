import 'dart:math' show pi;

import 'package:flutter/material.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_theme_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/attendance_provider.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/location_service.dart';
import '../../../../../data/models/attendance_model.dart';
import '../../../providers/attendance_reconciliation_provider.dart';
import 'attendance_location_row.dart';

/// Prefer a human-readable server value; otherwise session [localFallback]; else [server] (may be coords).
String _displaySource(String? server, String? localFallback) {
  final s = server?.trim() ?? '';
  final l = localFallback?.trim() ?? '';
  if (s.isNotEmpty && !LocationService.looksLikeCoordinatesString(s)) {
    return s;
  }
  if (l.isNotEmpty) return l;
  return s;
}

class TodayAttendanceCardWidget extends ConsumerStatefulWidget {
  const TodayAttendanceCardWidget({super.key});

  @override
  ConsumerState<TodayAttendanceCardWidget> createState() =>
      _TodayAttendanceCardWidgetState();
}

class _TodayAttendanceCardWidgetState
    extends ConsumerState<TodayAttendanceCardWidget> {
  String _statusText(TodayAttendance? todayAttendance) {
    if (todayAttendance == null || todayAttendance.safeStatus == 'pending') {
      return 'Pending';
    }
    if (todayAttendance.safeStatus == 'no_shift') {
      return 'Check-in unavailable';
    }
    if (todayAttendance.safeStatus == 'checked_in') {
      return 'Pending';
    }
    return 'Completed';
  }

  Color _statusColor(BuildContext context, TodayAttendance? todayAttendance) {
    final cs = Theme.of(context).colorScheme;

    if (todayAttendance == null) return cs.outline;

    if (todayAttendance.isLate) return cs.secondary;

    switch (todayAttendance.safeStatus) {
      case 'completed':
      case 'checked_out':
        return cs.tertiary;
      case 'checked_in':
        return cs.primary;
      case 'no_shift':
        return cs.secondary;
      default:
        return cs.outline;
    }
  }

  IconData _statusIcon(TodayAttendance? todayAttendance) {
    final status = todayAttendance?.safeStatus;
    if (status == null || status == 'pending') {
      return Icons.schedule_outlined;
    } else if (status == 'no_shift') {
      return Icons.event_busy_outlined;
    } else if (status == 'checked_in') {
      return Icons.timer_outlined;
    }
    return Icons.check_circle_outline;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceProvider);
    final todayAttendance = state.todayAttendance;
    final locIn = _displaySource(
      todayAttendance?.locationIn,
      state.localCheckInLocation,
    );
    final locOut = _displaySource(
      todayAttendance?.locationOut,
      state.localCheckOutLocation,
    );
    // Only show location rows when that event actually happened (or optimistic local right after hold).
    final hasCheckInEvent = todayAttendance?.checkInTime != null ||
        (state.localCheckInLocation?.trim().isNotEmpty ?? false);
    final hasCheckOutEvent = todayAttendance?.checkOutTime != null ||
        (state.localCheckOutLocation?.trim().isNotEmpty ?? false);
    final showLocIn = locIn.isNotEmpty && hasCheckInEvent;
    final showLocOut = locOut.isNotEmpty && hasCheckOutEvent;
    final hasLocationLines = showLocIn || showLocOut;
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final statusColor = _statusColor(context, todayAttendance);

    // Listen for errors and show snackbar
    ref.listen(attendanceProvider, (previous, next) {
      if (next.error != null && previous?.error != next.error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next.error!),
              backgroundColor: Theme.of(context).colorScheme.error,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    });

    return Container(
      padding: AppThemeColors.pagePaddingAll,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Status Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _statusIcon(todayAttendance),
                  color: statusColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _statusText(todayAttendance),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    if (todayAttendance != null) ...[
                      Text(
                        todayAttendance.date,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppThemeColors.textSecondaryColor(context),
                        ),
                      ),
                      if (todayAttendance.isWeekend == true ||
                          todayAttendance.isHoliday == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (todayAttendance.isWeekend == true) 'Weekend',
                            if (todayAttendance.isHoliday == true) 'Holiday',
                          ].join(' · '),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppThemeColors.textSecondaryColor(context),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              if (todayAttendance?.isLate == true)
                Builder(
                  builder: (context) {
                    final w = Theme.of(context).colorScheme.secondary;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: w.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.warning_amber,
                            size: 16,
                            color: w,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Late',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: w,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 24),
          // Times Row
          Row(
            children: [
              Expanded(
                child: timeChip('Check In', todayAttendance?.checkInTime),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: timeChip('Check Out', todayAttendance?.checkOutTime),
              ),
            ],
          ),
          if (hasLocationLines) ...[
            const SizedBox(height: 12),
            if (showLocIn)
              AttendanceLocationRow(
                icon: Icons.login_rounded,
                caption: 'Check-in location',
                value: locIn,
                textPrimary: textPrimary,
                textSecondary: AppThemeColors.textSecondaryColor(context),
              ),
            if (showLocIn && showLocOut) const SizedBox(height: 8),
            if (showLocOut)
              AttendanceLocationRow(
                icon: Icons.logout_rounded,
                caption: 'Check-out location',
                value: locOut,
                textPrimary: textPrimary,
                textSecondary: AppThemeColors.textSecondaryColor(context),
              ),
          ],
          if (todayAttendance?.totalHours != null) ...[
            const SizedBox(height: 12),
            Text(
              'Total: ${(todayAttendance!.totalHours! * 100).round() / 100}h',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (todayAttendance != null &&
              todayAttendance.safeStatus == 'no_shift') ...[
            Builder(
              builder: (context) {
                final s = Theme.of(context).colorScheme.secondary;
                return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: s.withValues(alpha: 0.55),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: s, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Check-in and check-out are not enabled for your account. Contact HR.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
                );
              },
            ),
          ],
          // Status message if already checked (validated)
          if (todayAttendance != null &&
              todayAttendance.safeStatus == 'completed') ...[
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: statusColor, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: const Text(
                      "Today's attendance completed",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Hold to check in / check out (fingerprint-style ring; same duration + haptics)
          if (todayAttendance?.safeStatus != 'completed' &&
              todayAttendance?.safeStatus != 'no_shift') ...[
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final flow = todayAttendance?.safeStatus ?? 'pending';
                final busy = state.isLoading;
                if (flow == 'pending') {
                  return HoldToAttendanceAction(
                    enabled: !busy,
                    label: 'Hold to check in',
                    accentColor: Theme.of(context).colorScheme.tertiary,
                    onHoldComplete: () => _fetchLocationAndSubmit(
                      context,
                      ref,
                      (coordinates, placeLabel) => ref
                          .read(attendanceProvider.notifier)
                          .checkIn(coordinates, placeLabel),
                      isCheckIn: true,
                    ),
                  );
                }
                if (flow == 'checked_in') {
                  return HoldToAttendanceAction(
                    enabled: !busy,
                    label: 'Hold to check out',
                    accentColor: Theme.of(context).colorScheme.error,
                    onHoldComplete: () => _fetchLocationAndSubmit(
                      context,
                      ref,
                      (coordinates, placeLabel) => ref
                          .read(attendanceProvider.notifier)
                          .checkOut(coordinates, placeLabel),
                      isCheckIn: false,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ],
      ),
    );
  }

  /// After hold completes: gets GPS, then shows a blocking dialog to confirm location before API submit.
  Future<void> _fetchLocationAndSubmit(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(String coordinatesPayload, String placeLabel) submit, {
    required bool isCheckIn,
  }) async {
    final locationService = ref.read(locationServiceProvider);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Getting your location...'),
          ],
        ),
      ),
    );

    final captured = await locationService.getCurrentLocationForAttendance();
    if (!context.mounted) return;
    Navigator.of(context).pop();

    if (captured == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Could not get location. Enable GPS and permissions, then try again.',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        final textPrimary = AppThemeColors.textPrimaryColor(dialogCtx);
        final textSecondary = AppThemeColors.textSecondaryColor(dialogCtx);
        return AlertDialog(
          title: Text(
            isCheckIn ? 'Confirm check-in location' : 'Confirm check-out location',
            style: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Please verify this is where you are before continuing.',
                  style: TextStyle(
                    fontSize: 14,
                    color: textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                if (captured.placeLabel.trim().isNotEmpty)
                  Text(
                    captured.placeLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                      height: 1.3,
                    ),
                  )
                else
                  Text(
                    'Address lookup unavailable — coordinates below will be sent.',
                    style: TextStyle(
                      fontSize: 14,
                      color: textSecondary,
                    ),
                  ),
                const SizedBox(height: 10),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(dialogCtx)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(
                      captured.coordinatesString,
                      style: TextStyle(
                        fontSize: 13,
                        color: textSecondary,
                        fontFamily: 'monospace',
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: const Text('Confirm location'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await submit(captured.coordinatesString, captured.placeLabel);
    if (!context.mounted) return;

    if (isCheckIn) {
      final t = ref.read(attendanceProvider).todayAttendance;
      if (t != null && t.shouldPromptLateReconciliation) {
        await _showLateReconciliationAfterCheckIn(context, ref, t);
      }
    }
  }

  /// Late reconciliation (check-in only): after location is confirmed and the server marks a late check-in.
  Future<void> _showLateReconciliationAfterCheckIn(
    BuildContext context,
    WidgetRef ref,
    TodayAttendance today,
  ) async {
    var t = ref.read(attendanceProvider).todayAttendance ?? today;

    Future<String?> resolveAttendanceRowId() async {
      var tt = ref.read(attendanceProvider).todayAttendance ?? t;
      var records = ref.read(attendanceProvider).records;
      var id = resolveTodayAttendanceRowId(tt, records);
      if (id != null && id.isNotEmpty) return id;
      await ref.read(attendanceProvider.notifier).loadRecords(period: 'today');
      if (!context.mounted) return null;
      tt = ref.read(attendanceProvider).todayAttendance ?? tt;
      id = resolveTodayAttendanceRowId(tt, ref.read(attendanceProvider).records);
      if (id != null && id.isNotEmpty) return id;
      await ref.read(attendanceProvider.notifier).loadToday();
      if (!context.mounted) return null;
      tt = ref.read(attendanceProvider).todayAttendance ?? tt;
      return resolveTodayAttendanceRowId(
        tt,
        ref.read(attendanceProvider).records,
      );
    }

    final reasonCtrl = TextEditingController();
    final mins = t.resolvedLateMinutes;
    final msg = mins != null && mins > 0
        ? 'You checked in $mins minutes after the allowed start time. '
            'Submit a reason below for late reconciliation — your manager will review it.'
        : 'Your check-in counts as late. Submit a short reason below for late reconciliation — your manager will review it.';

    var submitting = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
              final textPrimary =
                  AppThemeColors.textPrimaryColor(dialogCtx);
              final textSecondary =
                  AppThemeColors.textSecondaryColor(dialogCtx);
              return AlertDialog(
                title: Text(
                  'Late reconciliation',
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Late check-in',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        msg,
                        style: TextStyle(
                          fontSize: 15,
                          color: textSecondary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: reasonCtrl,
                        minLines: 3,
                        maxLines: 6,
                        enabled: !submitting,
                        decoration: const InputDecoration(
                          labelText: 'Reason for being late',
                          hintText: 'e.g. Traffic, medical appointment…',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: submitting
                        ? null
                        : () {
                            Navigator.of(dialogCtx, rootNavigator: true).pop();
                          },
                    child: const Text('Skip for now'),
                  ),
                  FilledButton(
                    onPressed: submitting
                        ? null
                        : () async {
                            final text = reasonCtrl.text.trim();
                            if (text.isEmpty) {
                              ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Enter a reason or tap Skip for now',
                                  ),
                                ),
                              );
                              return;
                            }
                            submitting = true;
                            setModalState(() {});
                            try {
                              final rowId = await resolveAttendanceRowId();
                              if (rowId == null || rowId.isEmpty) {
                                submitting = false;
                                setModalState(() {});
                                if (dialogCtx.mounted) {
                                  ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Could not find your attendance record yet. '
                                        'Try again in a moment, or add a reason from More → Attendance.',
                                      ),
                                      backgroundColor: Theme.of(dialogCtx)
                                          .colorScheme
                                          .error,
                                      duration: const Duration(seconds: 5),
                                    ),
                                  );
                                }
                                return;
                              }
                              await ref
                                  .read(
                                    attendanceReconciliationProvider.notifier,
                                  )
                                  .submitReason(
                                    attendanceId: rowId,
                                    reason: text,
                                  );
                              if (dialogCtx.mounted) {
                                Navigator.of(dialogCtx, rootNavigator: true)
                                    .pop();
                              }
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Late reconciliation sent for review',
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              submitting = false;
                              setModalState(() {});
                              if (dialogCtx.mounted) {
                                final detail = e is AppException
                                    ? e.message
                                    : e.toString();
                                final errText = detail.trim().isEmpty
                                    ? 'Could not submit. Try More → Attendance.'
                                    : detail;
                                ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                  SnackBar(
                                    content: Text(errText),
                                    backgroundColor: Theme.of(dialogCtx)
                                        .colorScheme
                                        .error,
                                  ),
                                );
                              }
                            }
                          },
                    child: submitting
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Submit'),
                  ),
                ],
              );
            },
          );
        },
      );
    // Pop runs route teardown; disposing in the next frame avoids using the controller after dispose.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      reasonCtrl.dispose();
    });
  }
}

Widget timeChip(String label, DateTime? time) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.grey.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        Text(
          time != null ? _formatTime(time) : '--:--',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}

String _formatTime(DateTime time) {
  final local = time.toLocal();
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  var hour12 = local.hour > 12 ? local.hour - 12 : local.hour;
  if (hour12 == 0) hour12 = 12;
  return '$hour12:$minute $period';
}

/// Press and hold until the ring completes; then runs [onHoldComplete] (e.g. GPS flow).
/// Same duration and [AppHaptics.holdComplete] as before. Release early to cancel.
class HoldToAttendanceAction extends StatefulWidget {
  final bool enabled;
  final String label;
  final Color accentColor;
  final Future<void> Function() onHoldComplete;

  const HoldToAttendanceAction({
    super.key,
    required this.enabled,
    required this.label,
    required this.accentColor,
    required this.onHoldComplete,
  });

  @override
  State<HoldToAttendanceAction> createState() => _HoldToAttendanceActionState();
}

class _HoldToAttendanceActionState extends State<HoldToAttendanceAction>
    with SingleTickerProviderStateMixin {
  static const double _ringSize = 140;
  static const Duration _holdDuration = Duration(milliseconds: 1600);

  late AnimationController _controller;
  bool _fingerDown = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _holdDuration);
    _controller.addStatusListener(_onAnimStatus);
  }

  void _onAnimStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed &&
        _fingerDown &&
        !_busy &&
        widget.enabled) {
      _runComplete();
    }
  }

  Future<void> _runComplete() async {
    if (_busy || !mounted) return;
    setState(() => _busy = true);
    AppHaptics.holdComplete();
    try {
      await widget.onHoldComplete();
    } finally {
      if (mounted) {
        _controller.reset();
        setState(() {
          _busy = false;
          _fingerDown = false;
        });
      }
    }
  }

  void _onTapDown(TapDownDetails _) {
    if (!widget.enabled || _busy) return;
    setState(() => _fingerDown = true);
    _controller.forward(from: 0);
  }

  void _onTapEnd() {
    if (!widget.enabled || _busy) return;
    _fingerDown = false;
    if (!_controller.isCompleted) {
      _controller.reset();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onAnimStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final disabled = !widget.enabled || _busy;
    final accent = widget.accentColor;

    return Opacity(
      opacity: disabled && !_busy ? 0.55 : 1,
      child: AbsorbPointer(
        absorbing: disabled,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: _onTapDown,
              onTapUp: (_) => _onTapEnd(),
              onTapCancel: _onTapEnd,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final p = _controller.value.clamp(0.0, 1.0);
                  final track = Color.lerp(
                    accent.withValues(alpha: 0.14),
                    accent.withValues(alpha: 0.22),
                    p,
                  )!;
                  return SizedBox(
                    width: _ringSize,
                    height: _ringSize,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accent.withValues(alpha: 0.06 + p * 0.08),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      accent.withValues(alpha: 0.12 + p * 0.18),
                                  blurRadius: 18 + p * 12,
                                  spreadRadius: p * 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                        CustomPaint(
                          size: const Size(_ringSize, _ringSize),
                          painter: _FingerprintHoldRingPainter(
                            progress: p,
                            accent: accent,
                            trackColor: track,
                          ),
                        ),
                        Icon(
                          Icons.fingerprint,
                          size: 56,
                          color: Color.lerp(
                            accent.withValues(alpha: 0.65),
                            accent,
                            p,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                widget.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Keep holding until the ring completes',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Outer track + inner scanner-style rings + sweep progress (clockwise from top).
class _FingerprintHoldRingPainter extends CustomPainter {
  _FingerprintHoldRingPainter({
    required this.progress,
    required this.accent,
    required this.trackColor,
  });

  final double progress;
  final Color accent;
  final Color trackColor;

  static const double _stroke = 4.5;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - _stroke;

    for (var i = 0; i < 3; i++) {
      final rr = r * (0.38 + i * 0.17);
      final p = Paint()
        ..color = accent.withValues(alpha: 0.05 + i * 0.035)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawCircle(c, rr, p);
    }

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, track);

    final sweep = 2 * pi * progress.clamp(0.0, 1.0);
    if (sweep > 0.002) {
      final prog = Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -pi / 2,
        sweep,
        false,
        prog,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FingerprintHoldRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.accent != accent ||
      oldDelegate.trackColor != trackColor;
}
