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
      final n = ref.read(attendanceProvider.notifier);
      n.loadRecords();
      n.loadToday();
    });
  }

  Future<void> _refresh() async {
    final n = ref.read(attendanceProvider.notifier);
    await Future.wait([n.loadRecords(), n.loadToday()]);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceProvider);
    final surfaceColor = AppThemeColors.surfaceColor(context);

    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppThemeColors.appBarTitle(context, 'Attendance Records'),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppThemeColors.pagePaddingAll,
          child: RecordsList(state: state),
        ),
      ),
    );
  }
}
