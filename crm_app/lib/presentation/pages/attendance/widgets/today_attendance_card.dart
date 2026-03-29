import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../providers/attendance_provider.dart';

class TodayAttendanceCard extends StatelessWidget {
  final dynamic todayAttendance; // TodayAttendance?
  final VoidCallback? onCheckIn;
  final VoidCallback? onCheckOut;

  const TodayAttendanceCard({
    super.key,
    required this.todayAttendance,
    this.onCheckIn,
    this.onCheckOut,
  });

  String getStatusText() {
    if (todayAttendance == null) return 'No data';
    if (todayAttendance!.isPending) return 'Pending';
    if (todayAttendance!.isCheckedIn) return 'Checked In';
    return 'Completed';
  }

  Color getStatusColor(BuildContext context) {
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

  IconData getStatusIcon() {
    if (todayAttendance?.isPending == true) return Icons.schedule_outlined;
    if (todayAttendance?.isCheckedIn == true) return Icons.login_outlined;
    if (todayAttendance?.isCheckedOut == true) return Icons.logout_outlined;
    return Icons.schedule;
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final statusColor = getStatusColor(context);

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
                child: Icon(getStatusIcon(), color: statusColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      getStatusText(),
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
          // Action Buttons
          Row(
            children: [
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
                  onPressed: onCheckIn,
                ),
              ),
              if (onCheckOut != null) ...[
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
                    onPressed: onCheckOut,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
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
