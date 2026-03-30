import 'dart:math' show pi;

import 'package:flutter/material.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/attendance_provider.dart';
import '../../../../core/services/location_service.dart';
import '../../../../../data/models/attendance_model.dart';
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

class TodayAttendanceCardWidget extends ConsumerWidget {
  const TodayAttendanceCardWidget({super.key});

  String getStatusText(TodayAttendance? todayAttendance) {
    if (todayAttendance == null || todayAttendance.safeStatus == 'pending') {
      return 'Pending';
    }
    if (todayAttendance.safeStatus == 'checked_in') {
      return 'Pending';
    }
    return 'Completed';
  }

  Color getStatusColor(BuildContext context, TodayAttendance? todayAttendance) {
    final warningColor = AppColors.warning;
    final successColor = AppColors.success;
    final primaryColor = Theme.of(context).primaryColor;

    if (todayAttendance == null) return Colors.grey;

    // Prioritize late status, then safe status
    if (todayAttendance.isLate) return warningColor;

    switch (todayAttendance.safeStatus) {
      case 'completed':
      case 'checked_out':
        return successColor;
      case 'checked_in':
        return primaryColor;
      default:
        return Colors.grey;
    }
  }

  IconData getStatusIcon(TodayAttendance? todayAttendance) {
    final status = todayAttendance?.safeStatus;
    if (status == null || status == 'pending') {
      return Icons.schedule_outlined; // Pending clock
    } else if (status == 'checked_in') {
      return Icons.timer_outlined; // Pending checkout timer
    }
    return Icons.check_circle_outline; // Completed check
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final hasLocationLines = locIn.isNotEmpty || locOut.isNotEmpty;
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final statusColor = getStatusColor(context, todayAttendance);

    // Listen for errors and show snackbar
    ref.listen(attendanceProvider, (previous, next) {
      if (next.error != null && previous?.error != next.error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next.error!),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    });

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  getStatusIcon(todayAttendance),
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
                      getStatusText(todayAttendance),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    if (todayAttendance != null)
                      Text(
                        todayAttendance.date,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppThemeColors.textSecondaryColor(context),
                        ),
                      ),
                  ],
                ),
              ),
              if (todayAttendance?.isLate == true)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber,
                        size: 16,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${todayAttendance!.lateMinutes} min late',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          // Times Row
          Row(
            children: [
              Expanded(
                child: _TimeChip('Check In', todayAttendance?.checkInTime),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TimeChip('Check Out', todayAttendance?.checkOutTime),
              ),
            ],
          ),
          if (hasLocationLines) ...[
            const SizedBox(height: 12),
            if (locIn.isNotEmpty)
              AttendanceLocationRow(
                icon: Icons.login_rounded,
                caption: 'Check-in location',
                value: locIn,
                textPrimary: textPrimary,
                textSecondary: AppThemeColors.textSecondaryColor(context),
              ),
            if (locIn.isNotEmpty && locOut.isNotEmpty)
              const SizedBox(height: 8),
            if (locOut.isNotEmpty)
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
          // Status message if already checked (validated)
          if (todayAttendance != null &&
              todayAttendance.safeStatus == 'completed') ...[
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withOpacity(0.4)),
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
          if (todayAttendance?.safeStatus != 'completed') ...[
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final flow = todayAttendance?.safeStatus ?? 'pending';
                final busy = state.isLoading;
                if (flow == 'pending') {
                  return HoldToAttendanceAction(
                    enabled: !busy,
                    label: 'Hold to check in',
                    accentColor: Colors.green.shade600,
                    onHoldComplete: () => _fetchLocationAndSubmit(
                      context,
                      ref,
                      (coordinates, placeLabel) => ref
                          .read(attendanceProvider.notifier)
                          .checkIn(coordinates, placeLabel),
                    ),
                  );
                }
                if (flow == 'checked_in') {
                  return HoldToAttendanceAction(
                    enabled: !busy,
                    label: 'Hold to check out',
                    accentColor: Colors.red.shade600,
                    onHoldComplete: () => _fetchLocationAndSubmit(
                      context,
                      ref,
                      (coordinates, placeLabel) => ref
                          .read(attendanceProvider.notifier)
                          .checkOut(coordinates, placeLabel),
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

  /// Gets GPS + place label, submits without a second confirmation popup.
  Future<void> _fetchLocationAndSubmit(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(String coordinatesPayload, String placeLabel) submit,
  ) async {
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
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    await submit(captured.coordinatesString, captured.placeLabel);
  }
}

Widget _TimeChip(String label, DateTime? time) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.grey.withOpacity(0.1),
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
