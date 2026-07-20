import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme_colors.dart';
import '../../../core/utils/async_load_helper.dart';
import '../../../core/utils/attendance_week_utils.dart';
import '../../../data/models/attendance_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/attendance_repository.dart';
import '../../providers/user_provider.dart';
import '../../widgets/list_page_state.dart';
import '../../widgets/loading_widget.dart';
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
  bool _loading = false;
  String? _error;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool refresh = false}) async {
    final gen = ++_loadGeneration;
    final hadCache = _rows.isNotEmpty;
    setState(() {
      _error = null;
      if (!hadCache) {
        _loading = true;
        _rows = [];
      } else if (refresh || hadCache) {
        _loading = true;
      }
    });
    try {
      final usersState = ref.read(usersProvider);
      if (usersState.users.isEmpty) {
        await ref.read(usersProvider.notifier).loadUsers();
      }
      if (!mounted || gen != _loadGeneration) return;

      final repo = ref.read(attendanceRepositoryProvider);
      final rows = sortAttendanceRecordsByDateDesc(
        await repo.getAllAttendance(
          period: _period,
          userId: _filterUserId,
        ),
      );
      if (!mounted || gen != _loadGeneration) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _loadGeneration) return;
      final msg = asyncLoadError(e);
      setState(() {
        _error = msg;
        _loading = false;
      });
      if (hadCache && mounted) {
        showRefreshErrorSnackBar(context, msg);
      }
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
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final usersState = ref.watch(usersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: AppThemeColors.pagePaddingAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
            ],
          ),
        ),
        Expanded(
          child: ListPageState(
            isLoading: _loading && _rows.isEmpty,
            isRefreshing: _loading && _rows.isNotEmpty,
            hasCachedData: _rows.isNotEmpty,
            error: _error,
            isEmpty: _rows.isEmpty,
            onRetry: () => _load(),
            emptyTitle: 'No attendance rows',
            emptySubtitle:
                'for ${_fmtPeriod(_period)}${_filterUserId != null ? ' (filtered)' : ''}',
            emptyIcon: Icons.groups_outlined,
            content: RefreshIndicator(
              onRefresh: () => _load(refresh: true),
              child: FadeInContent(
                child: ListView.builder(
                  padding: AppThemeColors.pagePaddingHorizontal
                      .add(const EdgeInsets.only(bottom: 24)),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: _rows.length,
                  itemBuilder: (context, index) {
                    final r = _rows[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: RecordTile(
                        record: r,
                        userHeader: _userLabel(r, usersState.users),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
