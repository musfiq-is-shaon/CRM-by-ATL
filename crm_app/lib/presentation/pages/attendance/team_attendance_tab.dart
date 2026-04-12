import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme_colors.dart';
import '../../../core/utils/attendance_week_utils.dart';
import '../../../data/models/attendance_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/attendance_repository.dart';
import '../../providers/user_provider.dart';
import 'widgets/records_list.dart';

/// Admin-only tab: `GET /api/attendance/all` — everyone’s attendance, optional user filter.
class TeamAttendanceTab extends ConsumerStatefulWidget {
  const TeamAttendanceTab({super.key});

  @override
  ConsumerState<TeamAttendanceTab> createState() => _TeamAttendanceTabState();
}

class _TeamAttendanceTabState extends ConsumerState<TeamAttendanceTab> {
  static const _periods = [
    'today',
    'yesterday',
    'week',
    'last_week',
    'month',
    'last_month',
    'year',
    'last_year',
  ];

  String _period = 'today';
  String? _filterUserId;
  List<AttendanceRecord> _rows = [];
  bool _loading = true;
  String? _error;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final gen = ++_loadGeneration;
    setState(() {
      _loading = true;
      _error = null;
      _rows = [];
    });
    try {
      final usersState = ref.read(usersProvider);
      if (usersState.users.isEmpty) {
        await ref.read(usersProvider.notifier).loadUsers();
      }
      if (!mounted || gen != _loadGeneration) return;

      final repo = ref.read(attendanceRepositoryProvider);
      List<AttendanceRecord> rows;
      if (_period == 'week') {
        final range = sundayWeekRangeContaining(DateTime.now());
        try {
          rows = await repo.getAllAttendance(
            dateFrom: range.dateFrom,
            dateTo: range.dateTo,
            userId: _filterUserId,
          );
        } catch (_) {
          rows = await repo.getAllAttendance(
            period: _period,
            userId: _filterUserId,
          );
        }
        rows = filterAttendanceRecordsToYmdRange(
          rows,
          range.dateFrom,
          range.dateTo,
        );
      } else if (_period == 'last_week') {
        final range = previousSundayWeekRange(DateTime.now());
        try {
          rows = await repo.getAllAttendance(
            dateFrom: range.dateFrom,
            dateTo: range.dateTo,
            userId: _filterUserId,
          );
        } catch (_) {
          rows = await repo.getAllAttendance(
            period: _period,
            userId: _filterUserId,
          );
        }
        rows = filterAttendanceRecordsToYmdRange(
          rows,
          range.dateFrom,
          range.dateTo,
        );
      } else {
        rows = await repo.getAllAttendance(
          period: _period,
          userId: _filterUserId,
        );
      }
      if (!mounted || gen != _loadGeneration) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _loadGeneration) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _fmtPeriod(String p) {
    return switch (p) {
      'today' => 'Today',
      'yesterday' => 'Yesterday',
      'week' => 'This week',
      'last_week' => 'Last week',
      'month' => 'This month',
      'last_month' => 'Last month',
      'year' => 'This year',
      'last_year' => 'Last year',
      _ => p.replaceAll('_', ' '),
    };
  }

  /// Prefer API-embedded [AttendanceRecord.user], else match [users] by id (same as backend ids).
  String _userLabel(AttendanceRecord r, List<User> users) {
    final n = r.user?.name.trim();
    if (n != null && n.isNotEmpty) return n;
    final e = r.user?.email.trim();
    if (e != null && e.isNotEmpty) return e;

    if (r.userId.isNotEmpty) {
      for (final u in users) {
        if (attendanceUserIdsEqual(u.id, r.userId)) {
          final name = u.name.trim();
          if (name.isNotEmpty) return name;
          final em = u.email.trim();
          if (em.isNotEmpty) return em;
          break;
        }
      }
    }
    if (r.userId.isNotEmpty) return r.userId;
    return 'User';
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final usersState = ref.watch(usersProvider);

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: AppThemeColors.pagePaddingAll,
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  'All employees — attendance for the selected period. Optional: filter by person.',
                  style: TextStyle(
                    fontSize: 13,
                    color: textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Period',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.grey.withValues(alpha: 0.25),
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _period,
                                items: _periods
                                    .map(
                                      (p) => DropdownMenuItem(
                                        value: p,
                                        child: Text(_fmtPeriod(p)),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() => _period = v);
                                  _load();
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'User',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.grey.withValues(alpha: 0.25),
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                isExpanded: true,
                                value: _filterUserId,
                                hint: const Text('All users'),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('All users'),
                                  ),
                                  ...usersState.users.map(
                                    (User u) => DropdownMenuItem<String?>(
                                      value: u.id,
                                      child: Text(
                                        u.name.isNotEmpty ? u.name : u.email,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (v) {
                                  setState(() => _filterUserId = v);
                                  _load();
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ]),
            ),
          ),
          if (_loading && _rows.isEmpty)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null && _rows.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: AppThemeColors.pagePaddingHorizontal,
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textSecondary),
                  ),
                ),
              ),
            )
          else if (_rows.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.groups_outlined, size: 56, color: textSecondary),
                    const SizedBox(height: 12),
                    Text(
                      'No attendance rows',
                      style: TextStyle(
                        fontSize: 16,
                        color: textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'for ${_fmtPeriod(_period)}${_filterUserId != null ? ' (filtered)' : ''}',
                      style: TextStyle(fontSize: 14, color: textSecondary),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: AppThemeColors.pagePaddingHorizontal
                  .add(const EdgeInsets.only(bottom: 24)),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final r = _rows[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: RecordTile(
                        record: r,
                        userHeader: _userLabel(r, usersState.users),
                      ),
                    );
                  },
                  childCount: _rows.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
