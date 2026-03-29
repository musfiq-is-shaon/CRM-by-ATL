import 'package:flutter/material.dart';
import 'attendance_place_label.dart';

/// Check-in / check-out location line (icon, caption, resolved place name).
class AttendanceLocationRow extends StatelessWidget {
  const AttendanceLocationRow({
    super.key,
    required this.icon,
    required this.caption,
    required this.value,
    required this.textPrimary,
    required this.textSecondary,
    this.valueFontSize = 14,
  });

  final IconData icon;
  final String caption;
  final String value;
  final Color textPrimary;
  final Color textSecondary;
  final double valueFontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                caption,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              AttendancePlaceLabel(
                text: value,
                textStyle: TextStyle(
                  fontSize: valueFontSize,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
                loadingStyle: TextStyle(
                  fontSize: valueFontSize,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                  color: textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
