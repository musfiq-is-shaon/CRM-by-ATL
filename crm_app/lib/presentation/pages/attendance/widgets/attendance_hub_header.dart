import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../providers/attendance_provider.dart';

/// Top of More → Attendance: this week’s status counts and refresh.
class AttendanceHubHeader extends ConsumerStatefulWidget {
  const AttendanceHubHeader({super.key});

  @override
  ConsumerState<AttendanceHubHeader> createState() =>
      _AttendanceHubHeaderState();
}

class _AttendanceHubHeaderState extends ConsumerState<AttendanceHubHeader> {
  Future<void> _refresh() async {
    ref.invalidate(attendanceWeekRollupProvider);
    await ref.read(attendanceProvider.notifier).loadToday();
    await ref.read(attendanceWeekRollupProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final att = ref.watch(attendanceProvider);
    final today = att.todayAttendance;
    final noShift =
        today?.hasShiftAssigned == false || today?.safeStatus == 'no_shift';
    final weekAsync = ref.watch(attendanceWeekRollupProvider);

    return Padding(
      padding: AppThemeColors.pagePaddingHorizontal.copyWith(
        top: AppThemeColors.pagePaddingAll.top,
        bottom: 8,
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                cs.primaryContainer.withValues(alpha: 0.45),
                cs.tertiaryContainer.withValues(alpha: 0.35),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.45),
            ),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.event_available_rounded,
                        color: cs.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Attendance',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                              color: textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Overview',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: att.isLoading ? null : () => _refresh(),
                      icon: Icon(
                        Icons.refresh_rounded,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
                if (noShift) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Check-in and check-out are not enabled for your account. Contact HR.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.3,
                      color: textSecondary,
                    ),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(
                    height: 1,
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      Icons.insights_rounded,
                      size: 18,
                      color: cs.secondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'This week',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const Spacer(),
                    weekAsync.when(
                      data: (r) => Text(
                        r.total == 0 ? 'No rows yet' : '${r.total} days',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: textSecondary,
                        ),
                      ),
                      loading: () => SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.secondary,
                        ),
                      ),
                      error: (e, _) => Text(
                        '—',
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                weekAsync.when(
                  data: (r) {
                    if (r.total == 0) {
                      return Text(
                        'Your week’s attendance will show here once recorded.',
                        style: TextStyle(
                          fontSize: 13,
                          color: textSecondary,
                          height: 1.35,
                        ),
                      );
                    }
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _WeekStatChip(
                          label: 'Attended',
                          count: r.present,
                          icon: Icons.check_circle_rounded,
                          accent: const Color(0xFF2E7D32),
                        ),
                        _WeekStatChip(
                          label: 'Late',
                          count: r.late,
                          icon: Icons.schedule_rounded,
                          accent: const Color(0xFFE65100),
                        ),
                        _WeekStatChip(
                          label: 'Absent',
                          count: r.absent,
                          icon: Icons.event_busy_rounded,
                          accent: const Color(0xFFC62828),
                        ),
                        if (r.other > 0)
                          _WeekStatChip(
                            label: 'Other',
                            count: r.other,
                            icon: Icons.more_horiz_rounded,
                            accent: const Color(0xFF546E7A),
                          ),
                      ],
                    );
                  },
                  loading: () => const LinearProgressIndicator(minHeight: 3),
                  error: (e, _) => Text(
                    'Could not load week summary',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekStatChip extends StatelessWidget {
  const _WeekStatChip({
    required this.label,
    required this.count,
    required this.icon,
    required this.accent,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = Color.alphaBlend(
      accent.withValues(alpha: isDark ? 0.28 : 0.14),
      cs.surfaceContainerHighest,
    );
    final fg = isDark
        ? Color.lerp(accent, cs.onSurface, 0.15)!
        : accent;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 92),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: fg.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: fg),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: fg.withValues(alpha: 0.88),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
