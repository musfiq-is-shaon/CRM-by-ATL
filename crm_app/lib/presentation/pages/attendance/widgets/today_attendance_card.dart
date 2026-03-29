import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/attendance_provider.dart';
import '../../../../core/services/location_service.dart';

class TodayAttendanceCardWidget extends ConsumerWidget {
  const TodayAttendanceCardWidget({super.key});

  String getStatusText(dynamic? todayAttendance) {
    if (todayAttendance == null) return 'No attendance yet';
    if (todayAttendance.checkOutTime != null) return 'Completed';
    if (todayAttendance.checkInTime != null) return 'Checked In';
    return 'Pending';
  }

  Color getStatusColor(BuildContext context, dynamic? todayAttendance) {
    final errorColor = AppColors.error;
    final warningColor = AppColors.warning;
    final successColor = AppColors.success;
    final primaryColor = Theme.of(context).primaryColor;

    if (todayAttendance == null) return Colors.grey;
    if (todayAttendance!.isLate) return warningColor;
    if (todayAttendance!.isCheckedOut) return successColor;
    if (todayAttendance!.isCheckedIn) return primaryColor;
    return Colors.grey;
  }

  IconData getStatusIcon(dynamic? todayAttendance) {
    if (todayAttendance?.checkOutTime != null)
      return Icons.check_circle_outline;
    if (todayAttendance?.checkInTime != null) return Icons.login_outlined;
    return Icons.schedule_outlined;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(attendanceProvider);
    final todayAttendance = state.todayAttendance;
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
                        todayAttendance!.date,
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
          // Status message if already checked
          if (todayAttendance != null && !todayAttendance.isPending) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: statusColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (todayAttendance.checkInTime != null)
                          ? 'Already checked in today'
                          : 'Today\'s attendance completed',
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Action Buttons
          Row(
            children: [
              if (todayAttendance == null || todayAttendance.isPending) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.login, size: 20),
                    label: const Text('Check In'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _showGpsLocationDialog(
                      context,
                      ref,
                      'Check In',
                      (location) => ref
                          .read(attendanceProvider.notifier)
                          .checkIn(location),
                    ),
                  ),
                ),
              ],
              if (todayAttendance?.checkInTime != null &&
                  todayAttendance?.checkOutTime == null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.logout, size: 20),
                    label: const Text('Check Out'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _showGpsLocationDialog(
                      context,
                      ref,
                      'Check Out',
                      (location) => ref
                          .read(attendanceProvider.notifier)
                          .checkOut(location),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showGpsLocationDialog(
    BuildContext context,
    WidgetRef ref,
    String title,
    Future<void> Function(String) onSubmit,
  ) async {
    final locationService = ref.read(locationServiceProvider);

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text('GPS Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Fetching your current location...'),
          ],
        ),
      ),
    );

    final location = await locationService.getCurrentLocation();
    Navigator.pop(context); // Close loading

    if (location != null) {
      // Confirm dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: SelectableText(
            location,
            style: const TextStyle(fontSize: 16, fontFamily: 'monospace'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Retry'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(title),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await onSubmit(location);
      }
    } else {
      // Error dialog
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('GPS Unavailable'),
            content: const Text(
              'Please enable location services and grant permissions.\\n\\n'
              '1. Enable GPS in settings\\n'
              '2. Grant location permission\\n'
              '3. Try again',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
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
          time != null ? _formatTime(time!) : '--:--',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}

String _formatTime(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.hour >= 12 ? 'PM' : 'AM';
  final hour12 = time.hour > 12 ? time.hour - 12 : time.hour;
  return '$hour12:${minute.padLeft(2, '0')} $period';
}
