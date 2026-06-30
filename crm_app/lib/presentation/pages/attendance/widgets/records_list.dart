import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../providers/attendance_provider.dart';
import '../../../../data/models/attendance_model.dart';
import 'attendance_location_row.dart';

class RecordsList extends ConsumerWidget {
  final AttendanceState state;

  /// When embedded in [AttendanceHubPage], hide the duplicate page title.
  final bool showHeading;

  const RecordsList({super.key, required this.state, this.showHeading = true});

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
            if (showHeading) ...[
              Text(
                'Attendance Records',
                style: AppTypography.sectionTitle(context)?.copyWith(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
            ] else ...[
              Expanded(
                child: Text(
                  'Period',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
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
        const SizedBox(height: AppSpacing.md),
        if (state.records.isEmpty)
          Center(
            child: Column(
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey),
                const SizedBox(height: AppSpacing.xs),
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

  /// When set (e.g. team attendance), shown above the date.
  final String? userHeader;

  const RecordTile({super.key, required this.record, this.userHeader});

  Color statusColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return switch (record.status) {
      'present' => cs.tertiary,
      'late' => cs.secondary,
      'early_leave' => cs.secondary,
      'half_day' => cs.primary,
      'absent' => cs.error,
      'exempt' => cs.outline,
      _ => cs.onSurfaceVariant,
    };
  }

  IconData getStatusIcon() {
    return switch (record.status) {
      'present' => Icons.check_circle,
      'late' => Icons.warning_amber,
      'early_leave' => Icons.logout,
      'half_day' => Icons.schedule,
      'absent' => Icons.close,
      'exempt' => Icons.weekend_outlined,
      _ => Icons.help_outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final statusColor = this.statusColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final locIn = record.locationIn?.trim() ?? '';
    final locOut = record.locationOut?.trim() ?? '';
    final showLocIn = locIn.isNotEmpty && record.checkInTime != null;
    final showLocOut = locOut.isNotEmpty && record.checkOutTime != null;
    final hasLocations = showLocIn || showLocOut;

    return Container(
      margin: AppThemeColors.cardListItemMargin,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: statusColor, width: 4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(getStatusIcon(), color: statusColor, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (userHeader != null && userHeader!.trim().isNotEmpty) ...[
                  Text(
                    userHeader!.trim(),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  record.date,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    timeChip('In', record.checkInTime),
                    const SizedBox(width: 16),
                    timeChip('Out', record.checkOutTime),
                  ],
                ),
                if (record.workingHoursDisplayLabel != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Working hours: ${record.workingHoursDisplayLabel}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                ],
                if (hasLocations) ...[
                  const SizedBox(height: AppSpacing.sm),
                  if (showLocIn)
                    AttendanceLocationRow(
                      icon: Icons.login_rounded,
                      caption: 'Check-in location',
                      value: locIn,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                  if (showLocIn && showLocOut) const SizedBox(height: AppSpacing.xs),
                  if (showLocOut)
                    AttendanceLocationRow(
                      icon: Icons.logout_rounded,
                      caption: 'Check-out location',
                      value: locOut,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget timeChip(String label, DateTime? time) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.grey.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(
          time != null ? _formatTime(time) : '--:--',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
