import 'dart:async';
import 'dart:math' show pi;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../widgets/crm_card.dart';
import '../../../widgets/loading_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/attendance_provider.dart';
import '../../../providers/dashboard_live_location_provider.dart';
import '../../../providers/leave_provider.dart';
import '../../../../data/models/leave_model.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/location_service.dart';
import '../../../../../data/models/attendance_model.dart';
import '../../../providers/attendance_reconciliation_provider.dart';
import 'attendance_location_row.dart';
import 'live_location_osm_map_page.dart';

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

String _formatWorkingHours(double hours) {
  final totalMin = (hours * 60).round();
  final h = totalMin ~/ 60;
  final m = totalMin % 60;
  if (m == 0) {
    return '${h}h';
  }
  return '${h}h ${m}m';
}

class TodayAttendanceCardWidget extends ConsumerStatefulWidget {
  const TodayAttendanceCardWidget({super.key});

  @override
  ConsumerState<TodayAttendanceCardWidget> createState() =>
      _TodayAttendanceCardWidgetState();
}

class _TodayAttendanceCardWidgetState extends ConsumerState<TodayAttendanceCardWidget>
    with WidgetsBindingObserver {
  static const Duration _liveFirstFixTimeout = Duration(seconds: 22);
  static const Duration _liveGeocodeDebounce = Duration(milliseconds: 2000);
  /// Check-in/out uses live fix when newer than this (same source as the card).
  static const Duration _liveMaxAgeForSubmit = Duration(minutes: 2);
  StreamSubscription<Position>? _liveLocSub;
  Timer? _liveGeocodeDebounceTimer;
  Timer? _liveFirstFixTimer;
  int _liveGeocodeGen = 0;
  bool _appInBackground = false;

  Position? _livePosition;
  String? _liveAddress;
  /// `null` = no error; otherwise a short key for user-facing copy.
  String? _liveLocationErrorKey;
  bool _liveWaitingFirstFix = true;
  bool _liveRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _beginLiveLocation());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeLiveLocation();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _appInBackground = true;
      _disposeLiveLocation();
    } else if (state == AppLifecycleState.resumed) {
      _appInBackground = false;
      _beginLiveLocation();
    }
  }

  void _disposeLiveLocation() {
    _liveLocSub?.cancel();
    _liveLocSub = null;
    _liveGeocodeDebounceTimer?.cancel();
    _liveGeocodeDebounceTimer = null;
    _liveFirstFixTimer?.cancel();
    _liveFirstFixTimer = null;
  }

  Future<void> _beginLiveLocation() async {
    if (!mounted || _appInBackground) return;
    _disposeLiveLocation();
    setState(() {
      _livePosition = null;
      _liveAddress = null;
      _liveLocationErrorKey = null;
      _liveWaitingFirstFix = true;
    });

    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!mounted || _appInBackground) return;
    if (!enabled) {
      setState(() {
        _liveWaitingFirstFix = false;
        _liveLocationErrorKey = 'services_off';
      });
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (!mounted || _appInBackground) return;
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() {
        _liveWaitingFirstFix = false;
        _liveLocationErrorKey = 'permission_denied';
      });
      return;
    }

    final stream =
        ref.read(locationServiceProvider).openDashboardPositionStream();

    _liveFirstFixTimer = Timer(_liveFirstFixTimeout, () {
      if (!mounted) return;
      if (_livePosition == null && _liveLocationErrorKey == null) {
        setState(() {
          _liveWaitingFirstFix = false;
          _liveLocationErrorKey = 'no_fix';
        });
      }
    });

    _liveLocSub = stream.listen(
      (pos) {
        if (!mounted || _appInBackground) return;
        _liveFirstFixTimer?.cancel();
        final prev = _livePosition;
        // Skip no-op rebuilds that only change sub-meter noise / same display.
        if (prev != null &&
            !_liveWaitingFirstFix &&
            (prev.latitude - pos.latitude).abs() < 0.00005 &&
            (prev.longitude - pos.longitude).abs() < 0.00005) {
          final prevAcc = prev.accuracy.isFinite ? prev.accuracy.round() : null;
          final nextAcc = pos.accuracy.isFinite ? pos.accuracy.round() : null;
          if (prevAcc == nextAcc) {
            _scheduleLiveGeocode(pos);
            return;
          }
        }
        setState(() {
          _livePosition = pos;
          _liveWaitingFirstFix = false;
          _liveLocationErrorKey = null;
        });
        _scheduleLiveGeocode(pos);
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _liveWaitingFirstFix = false;
          _liveLocationErrorKey = 'error';
        });
      },
    );
  }

  /// Silent refresh when user switches back to the Dashboard tab (see [dashboardVisitLiveLocationRefreshTickProvider]).
  Future<void> _onDashboardVisitRefreshLiveLocation() async {
    if (!mounted || _appInBackground || _liveRefreshing) return;
    if (_liveWaitingFirstFix) return;
    if (_liveLocationErrorKey == 'services_off' ||
        _liveLocationErrorKey == 'permission_denied') {
      return;
    }
    final pos =
        await ref.read(locationServiceProvider).fetchHighAccuracyPosition();
    if (!mounted || _appInBackground) return;
    if (pos == null) return;
    _liveFirstFixTimer?.cancel();
    setState(() {
      _livePosition = pos;
      _liveWaitingFirstFix = false;
      _liveLocationErrorKey = null;
    });
    _scheduleLiveGeocode(pos);
  }

  void _scheduleLiveGeocode(Position pos) {
    _liveGeocodeDebounceTimer?.cancel();
    final gen = ++_liveGeocodeGen;
    _liveGeocodeDebounceTimer = Timer(_liveGeocodeDebounce, () async {
      final coords = LocationService.formatCoordinatesForStorage(
        pos.latitude,
        pos.longitude,
      );
      final label = await LocationService.placeLabelFromCoordinateString(coords);
      if (!mounted || gen != _liveGeocodeGen) return;
      final next = label.trim().isNotEmpty ? label.trim() : null;
      if (next == _liveAddress) return;
      setState(() {
        _liveAddress = next;
      });
    });
  }

  void _openLiveMap(BuildContext context) {
    final p = _livePosition;
    if (p == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => LiveLocationOsmMapPage(
          initialLatitude: p.latitude,
          initialLongitude: p.longitude,
          placeLabel: _liveAddress,
        ),
      ),
    );
  }

  Future<void> _onRefreshLiveLocation(
    BuildContext context,
    WidgetRef ref,
  ) async {
    if (_liveRefreshing) return;
    setState(() {
      _liveRefreshing = true;
      _liveLocationErrorKey = null;
    });
    final pos =
        await ref.read(locationServiceProvider).fetchHighAccuracyPosition();
    if (!mounted) return;
    setState(() => _liveRefreshing = false);
    if (pos == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Could not refresh location. Enable GPS and allow location access.',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      if (_livePosition == null) {
        setState(() {
          _liveWaitingFirstFix = false;
          _liveLocationErrorKey = 'error';
        });
      }
      return;
    }
    _liveFirstFixTimer?.cancel();
    setState(() {
      _livePosition = pos;
      _liveWaitingFirstFix = false;
      _liveLocationErrorKey = null;
    });
    _scheduleLiveGeocode(pos);
  }

  Widget _buildLiveLocationSection({
    required BuildContext context,
    required WidgetRef ref,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
    required ColorScheme cs,
  }) {
    const caption = 'Live location';
    String? primary;
    String? secondary;
    Widget? leading;

    final err = _liveLocationErrorKey;
    if (err == 'services_off') {
      leading = Icon(Icons.location_off_outlined, size: 18, color: textSecondary);
      primary = 'Location services off';
      secondary = 'Turn on device location to see live updates here.';
    } else if (err == 'permission_denied') {
      leading = Icon(Icons.location_disabled_outlined, size: 18, color: textSecondary);
      primary = 'Location permission needed';
      secondary = 'Allow location access for this app to see your current position.';
    } else if (err == 'no_fix') {
      leading = Icon(Icons.gps_not_fixed, size: 18, color: textSecondary);
      primary = 'No GPS fix yet';
      secondary = 'Try moving outdoors or wait a few seconds.';
    } else if (err == 'error') {
      leading = Icon(Icons.error_outline, size: 18, color: textSecondary);
      primary = 'Could not update location';
      secondary = null;
    } else if (_livePosition != null) {
      final p = _livePosition!;
      leading = Icon(Icons.my_location, size: 18, color: cs.primary);
      final shortCoords =
          '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}';
      final acc = p.accuracy.isFinite ? p.accuracy.round() : null;
      final meta = <String?>[
        if (acc != null) '±$acc m',
        'Updated ${_formatLiveClock(p.timestamp)}',
      ].join(' · ');
      if (_liveAddress != null && _liveAddress!.trim().isNotEmpty) {
        primary = _liveAddress!.trim();
        secondary = '$shortCoords · $meta';
      } else {
        primary = shortCoords;
        secondary = meta;
      }
    } else if (_liveWaitingFirstFix) {
      leading = SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: cs.primary,
        ),
      );
      primary = 'Locating…';
      secondary = 'Getting your position…';
    }

    final hasMapTarget = _livePosition != null;

    return MediaQuery.withClampedTextScaling(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.2,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 58),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 2, 6),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor.withValues(alpha: 0.65)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: leading ??
                    Icon(
                      Icons.my_location_outlined,
                      size: 18,
                      color: textSecondary,
                    ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: hasMapTarget ? () => _openLiveMap(context) : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(2, 0, 4, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              height: 1.15,
                              color: textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            primary ?? ' ',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                              color: textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            secondary ?? ' ',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.25,
                              color: textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Refresh location',
                onPressed: _liveRefreshing
                    ? null
                    : () => _onRefreshLiveLocation(context, ref),
                icon: _liveRefreshing
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.primary,
                        ),
                      )
                    : Icon(Icons.refresh, size: 20, color: cs.primary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusText(
    TodayAttendance? todayAttendance, [
    LeaveEntry? approvedLeaveToday,
  ]) {
    if (approvedLeaveToday != null && todayAttendance?.checkInTime == null) {
      final type = approvedLeaveToday.leaveTypeName?.trim() ?? '';
      if (type.isNotEmpty) return 'On leave ($type)';
      return 'On approved leave';
    }
    if (todayAttendance == null || todayAttendance.safeStatus == 'pending') {
      return 'Not checked in yet';
    }
    if (todayAttendance.safeStatus == 'no_shift') {
      return 'Check-in unavailable';
    }
    if (todayAttendance.safeStatus == 'checked_in') {
      return 'Checked in';
    }
    return 'Day complete';
  }

  String? _statusHint(
    TodayAttendance? todayAttendance, [
    LeaveEntry? approvedLeaveToday,
  ]) {
    if (approvedLeaveToday != null && todayAttendance?.checkInTime == null) {
      return 'No check-in required while on approved leave.';
    }
    if (todayAttendance == null) return null;
    switch (todayAttendance.safeStatus) {
      case 'pending':
        return 'Hold below to check in.';
      case 'checked_in':
        return 'Hold below to check out.';
      case 'completed':
        return null;
      case 'no_shift':
        return null;
      default:
        return null;
    }
  }

  Widget _buildTimeChip(
    ColorScheme cs,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    String label,
    DateTime? time,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor.withValues(alpha: 0.75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            time != null ? _formatTime(time) : '—',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.1,
              color: time != null
                  ? textPrimary
                  : textSecondary.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
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

  IconData _statusIcon(
    TodayAttendance? todayAttendance, [
    LeaveEntry? approvedLeaveToday,
  ]) {
    if (approvedLeaveToday != null && todayAttendance?.checkInTime == null) {
      return Icons.event_available_outlined;
    }
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
    ref.listen<int>(dashboardVisitLiveLocationRefreshTickProvider, (previous, next) {
      unawaited(_onDashboardVisitRefreshLiveLocation());
    });

    final state = ref.watch(attendanceProvider);
    final todayAttendance = state.todayAttendance;
    final leavesAsync = ref.watch(myLeavesForAttendanceProvider);
    final approvedLeaveToday = leavesAsync.maybeWhen(
      data: (leaves) =>
          approvedLeaveCoveringCalendarDay(leaves, DateTime.now()),
      orElse: () => null,
    );
    final onLeaveWithoutCheckIn =
        approvedLeaveToday != null && todayAttendance?.checkInTime == null;
    final locIn = _displaySource(
      todayAttendance?.locationIn,
      state.localCheckInLocation,
    );
    final locOut = _displaySource(
      todayAttendance?.locationOut,
      state.localCheckOutLocation,
    );
    // Only show location rows when that event actually happened (or optimistic local right after hold).
    final hasCheckInEvent =
        todayAttendance?.checkInTime != null ||
        (state.localCheckInLocation?.trim().isNotEmpty ?? false);
    final hasCheckOutEvent =
        todayAttendance?.checkOutTime != null ||
        (state.localCheckOutLocation?.trim().isNotEmpty ?? false);
    final showLocIn = locIn.isNotEmpty && hasCheckInEvent;
    final showLocOut = locOut.isNotEmpty && hasCheckOutEvent;
    final hasLocationLines = showLocIn || showLocOut;
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final borderColor = AppThemeColors.borderColor(context);
    final cs = Theme.of(context).colorScheme;
    final statusColor = onLeaveWithoutCheckIn
        ? cs.tertiary
        : _statusColor(context, todayAttendance);
    final statusHint = _statusHint(todayAttendance, approvedLeaveToday);

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

    // Initial load — keep card height stable instead of "Not checked in yet".
    if (state.isLoading && todayAttendance == null) {
      return const AttendanceCardSkeleton();
    }

    return CRMCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.32),
                    width: 1,
                  ),
                ),
                child: Icon(
                  _statusIcon(todayAttendance, approvedLeaveToday),
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _statusText(todayAttendance, approvedLeaveToday),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: textPrimary,
                      ),
                    ),
                    if (statusHint != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        statusHint,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          color: textSecondary,
                        ),
                      ),
                    ],
                    if (todayAttendance != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        todayAttendance.date,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: textSecondary,
                        ),
                      ),
                      if (todayAttendance.isWeekend == true ||
                          todayAttendance.isHoliday == true) ...[
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (todayAttendance.isWeekend == true) 'Weekend',
                            if (todayAttendance.isHoliday == true) 'Holiday',
                          ].join(' · '),
                          style: TextStyle(
                            fontSize: 11,
                            color: textSecondary,
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
                          Icon(Icons.warning_amber, size: 16, color: w),
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
          const SizedBox(height: 12),
          // Times Row
          Row(
            children: [
              Expanded(
                child: _buildTimeChip(
                  cs,
                  borderColor,
                  textPrimary,
                  textSecondary,
                  'Check-in',
                  todayAttendance?.checkInTime,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTimeChip(
                  cs,
                  borderColor,
                  textPrimary,
                  textSecondary,
                  'Check-out',
                  todayAttendance?.checkOutTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildLiveLocationSection(
            context: context,
            ref: ref,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            borderColor: borderColor,
            cs: cs,
          ),
          if (hasLocationLines) ...[
            const SizedBox(height: 8),
            if (showLocIn)
              AttendanceLocationRow(
                icon: Icons.login_rounded,
                caption: 'Check-in location',
                value: locIn,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
            if (showLocIn && showLocOut) const SizedBox(height: 6),
            if (showLocOut)
              AttendanceLocationRow(
                icon: Icons.logout_rounded,
                caption: 'Check-out location',
                value: locOut,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
          ],
          if (todayAttendance?.resolvedWorkingHoursHours != null) ...[
            const SizedBox(height: 8),
            Text(
              'Working hours today: ${_formatWorkingHours(todayAttendance!.resolvedWorkingHoursHours!)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (todayAttendance != null &&
              todayAttendance.safeStatus == 'no_shift') ...[
            Builder(
              builder: (context) {
                final s = Theme.of(context).colorScheme.secondary;
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: s.withValues(alpha: 0.55)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: s, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Check-in and check-out are not enabled for your account. Contact HR.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.3,
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: statusColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: statusColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: const Text(
                      "Today's attendance completed",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (onLeaveWithoutCheckIn) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: cs.tertiaryContainer.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cs.tertiary.withValues(alpha: 0.45)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.event_available_outlined,
                    color: cs.tertiary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You have approved leave for today'
                      '${approvedLeaveToday.leaveTypeName != null && approvedLeaveToday.leaveTypeName!.trim().isNotEmpty ? ' (${approvedLeaveToday.leaveTypeName})' : ''}. '
                      'Shift check-in reminders are paused for this day.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Hold to check in / check out (fingerprint-style ring; same duration + haptics)
          if (todayAttendance?.safeStatus != 'completed' &&
              todayAttendance?.safeStatus != 'no_shift' &&
              !onLeaveWithoutCheckIn) ...[
            const SizedBox(height: 10),
            Builder(
              builder: (context) {
                final flow = todayAttendance?.safeStatus ?? 'pending';
                final busy = state.isLoading;
                if (flow == 'pending') {
                  return HoldToAttendanceAction(
                    enabled: !busy,
                    label: 'Hold to check in',
                    accentColor: Theme.of(context).colorScheme.primary,
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

  /// Prefer recent live fix from the card stream; else one silent GPS fix.
  Future<({String coordinates, String placeLabel})?>
  _resolveLocationForAttendanceSubmit(WidgetRef ref) async {
    final live = _livePosition;
    if (live != null) {
      final age = DateTime.now().difference(live.timestamp);
      if (age <= _liveMaxAgeForSubmit) {
        final coordinates = LocationService.formatCoordinatesForStorage(
          live.latitude,
          live.longitude,
        );
        var place = _liveAddress?.trim() ?? '';
        if (place.isEmpty) {
          place = (await LocationService.placeLabelFromCoordinateString(
                coordinates,
              ))
              .trim();
        }
        return (coordinates: coordinates, placeLabel: place);
      }
    }

    final pos = await ref.read(locationServiceProvider).fetchHighAccuracyPosition();
    if (!mounted) return null;
    if (pos == null) return null;

    setState(() {
      _livePosition = pos;
      _liveWaitingFirstFix = false;
      _liveLocationErrorKey = null;
    });
    _liveFirstFixTimer?.cancel();
    _scheduleLiveGeocode(pos);

    final coordinates = LocationService.formatCoordinatesForStorage(
      pos.latitude,
      pos.longitude,
    );
    var place = (await LocationService.placeLabelFromCoordinateString(
          coordinates,
        ))
        .trim();
    return (coordinates: coordinates, placeLabel: place);
  }

  /// After hold completes: uses live location when fresh; otherwise silent fix (no dialogs).
  Future<void> _fetchLocationAndSubmit(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(String coordinatesPayload, String placeLabel)
    submit, {
    required bool isCheckIn,
  }) async {
    final resolved = await _resolveLocationForAttendanceSubmit(ref);
    if (!context.mounted) return;

    if (resolved == null) {
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

    await submit(resolved.coordinates, resolved.placeLabel);
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
      id = resolveTodayAttendanceRowId(
        tt,
        ref.read(attendanceProvider).records,
      );
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
            final textPrimary = AppThemeColors.textPrimaryColor(dialogCtx);
            final textSecondary = AppThemeColors.textSecondaryColor(dialogCtx);
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
                                      'Try again in a moment, or add a reason from the Attendance tab.',
                                    ),
                                    backgroundColor: Theme.of(
                                      dialogCtx,
                                    ).colorScheme.error,
                                    duration: const Duration(seconds: 5),
                                  ),
                                );
                              }
                              return;
                            }
                            await ref
                                .read(attendanceReconciliationProvider.notifier)
                                .submitReason(
                                  attendanceId: rowId,
                                  reason: text,
                                );
                            if (dialogCtx.mounted) {
                              Navigator.of(
                                dialogCtx,
                                rootNavigator: true,
                              ).pop();
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
                                  ? 'Could not submit. Try the Attendance tab.'
                                  : detail;
                              ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                SnackBar(
                                  content: Text(errText),
                                  backgroundColor: Theme.of(
                                    dialogCtx,
                                  ).colorScheme.error,
                                ),
                              );
                            }
                          }
                        },
                  child: submitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
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

String _formatLiveClock(DateTime time) {
  final l = time.toLocal();
  final h = l.hour.toString().padLeft(2, '0');
  final m = l.minute.toString().padLeft(2, '0');
  // Omit seconds — updating every GPS tick made the meta line jitter.
  return '$h:$m';
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
  static const double _ringSize = 148;
  static const Duration _holdDuration = Duration(milliseconds: 900);

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
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accent.withValues(alpha: 0.42),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
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
                      accent.withValues(alpha: 0.2),
                      accent.withValues(alpha: 0.32),
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
                                color: accent.withValues(alpha: 0.08 + p * 0.1),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withValues(
                                      alpha: 0.18 + p * 0.22,
                                    ),
                                    blurRadius: 14 + p * 10,
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
                            Icons.fingerprint_rounded,
                            size: 56,
                            color: Color.lerp(
                              accent.withValues(alpha: 0.55),
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
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Hold until the ring completes · release to cancel',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.25,
                  fontWeight: FontWeight.w500,
                  color: textSecondary,
                ),
              ),
            ],
          ),
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

  static const double _stroke = 6.5;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - _stroke - 1.5;

    for (var i = 0; i < 2; i++) {
      final rr = r * (0.42 + i * 0.22);
      final p = Paint()
        ..color = accent.withValues(alpha: 0.09 + i * 0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(c, rr, p);
    }

    final outerGuide = Paint()
      ..color = accent.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r + 1.25, outerGuide);

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
