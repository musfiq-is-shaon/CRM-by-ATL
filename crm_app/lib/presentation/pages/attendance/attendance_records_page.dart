import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../providers/attendance_provider.dart';
import 'widgets/records_list.dart';

class AttendanceRecordsPage extends ConsumerStatefulWidget {
  const AttendanceRecordsPage({super.key});

  @override
  ConsumerState<AttendanceRecordsPage> createState() =>
      _AttendanceRecordsPageState();
}

class _AttendanceRecordsPageState extends ConsumerState<AttendanceRecordsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(attendanceProvider.notifier).loadRecords();
    });
  }

  Future<void> _refresh() async {
    ref.read(attendanceProvider.notifier).loadRecords();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceProvider);
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);

    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        title: const Text('Attendance Records'),
        elevation: 0,
        backgroundColor: surfaceColor,
        foregroundColor: textPrimary,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: RecordsList(state: state),
        ),
      ),
    );
  }
}
