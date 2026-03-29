import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../providers/attendance_provider.dart';
import 'widgets/today_attendance_card.dart';
import 'widgets/records_list.dart';

class AttendancePage extends ConsumerStatefulWidget {
  const AttendancePage({super.key});

  @override
  ConsumerState<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends ConsumerState<AttendancePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(attendanceProvider.notifier).loadToday();
      ref.read(attendanceProvider.notifier).loadRecords();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceProvider);
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);

    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        title: const Text('Attendance'),
        elevation: 0,
        backgroundColor: surfaceColor,
        foregroundColor: textPrimary,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(attendanceProvider.notifier).loadToday();
          ref.read(attendanceProvider.notifier).loadRecords();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Today Status Card
              TodayAttendanceCard(
                todayAttendance: state.todayAttendance,
                onCheckIn: () => _showLocationDialog(
                  context,
                  'Check In',
                  ref.read(attendanceProvider.notifier).checkIn,
                ),
                onCheckOut: state.todayAttendance?.isCheckedIn == true
                    ? () => _showLocationDialog(
                        context,
                        'Check Out',
                        ref.read(attendanceProvider.notifier).checkOut,
                      )
                    : null,
              ),
              const SizedBox(height: 24),
              // Records Section
              RecordsList(state: state),
              if (state.error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.error!,
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            ref.read(attendanceProvider.notifier).clearError(),
                        icon: const Icon(Icons.close, size: 20),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showLocationDialog(
    BuildContext context,
    String title,
    Future<void> Function(String) onSubmit,
  ) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$title Location'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Location (e.g. Office Entrance)',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                onSubmit(controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: Text(title),
          ),
        ],
      ),
    );
  }
}
