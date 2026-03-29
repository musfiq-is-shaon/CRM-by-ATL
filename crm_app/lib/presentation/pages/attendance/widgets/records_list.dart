import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../providers/attendance_provider.dart';
import '../../../../data/models/attendance_model.dart';

class RecordsList extends ConsumerWidget {
  final AttendanceState state;

  const RecordsList({super.key, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final surfaceColor = AppThemeColors.surfaceColor(context);

    final periods = ['today', 'week', 'month', 'last_month', 'year'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Attendance Records',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: state.period,
                  items: periods
                      .map(
                        (p) => DropdownMenuItem(
                          value: p,
                          child: Text(_formatPeriod(p)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      ref
                          .read(attendanceProvider.notifier)
                          .loadRecords(period: value);
                    }
                  },
                  icon: const Icon(Icons.arrow_drop_down, size: 20),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (state.records.isEmpty)
          Center(
            child: Column(
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey),
                const SizedBox(height: 8),
                Text(
                  'No records found',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppThemeColors.textSecondaryColor(context),
                  ),
                ),
                Text(
                  'for ${state.period}',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.records.length,
            itemBuilder: (context, index) {
              final record = state.records[index];
              return RecordTile(record: record);
            },
          ),
      ],
    );
  }

  String _formatPeriod(String period) {
    return switch (period) {
      'today' => 'Today',
      'week' => 'This Week',
      'month' => 'This Month',
      'last_month' => 'Last Month',
      'year' => 'This Year',
      _ => period.replaceAll('_', ' ').toUpperCase(),
    };
  }
}

class RecordTile extends StatelessWidget {
  final AttendanceRecord record;

  const RecordTile({super.key, required this.record});

  Color getStatusColor() {
    return switch (record.status) {
      'present' => Colors.green,
      'late' => Colors.orange,
      'early_leave' => Colors.orange,
      'half_day' => Colors.blue,
      'absent' => Colors.red,
      _ => Colors.grey,
    };
  }

  IconData getStatusIcon() {
    return switch (record.status) {
      'present' => Icons.check_circle,
      'late' => Icons.warning_amber,
      'early_leave' => Icons.logout,
      'half_day' => Icons.schedule,
      'absent' => Icons.close,
      _ => Icons.help_outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final statusColor = getStatusColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: statusColor, width: 4)),
      ),
      child: Row(
        children: [
          // Status Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(getStatusIcon(), color: statusColor, size: 24),
          ),
          const SizedBox(width: 16),
          // Date & Times
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.date,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _TimeChip('In', record.checkInTime),
                    const SizedBox(width: 16),
                    _TimeChip('Out', record.checkOutTime),
                  ],
                ),
                if (record.durationHours != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${(record.durationHours! * 100).round() / 100}h',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (record.locationIn != null || record.locationOut != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (record.locationIn != null)
                  Text(
                    record.locationIn!,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (record.locationOut != null)
                  Text(
                    record.locationOut!,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

Widget _TimeChip(String label, DateTime? time) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.grey.withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(
          time != null ? _formatTime(time!) : '--:--',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    ),
  );
}

String _formatTime(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
