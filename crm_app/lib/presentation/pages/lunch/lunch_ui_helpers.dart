import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/theme/app_theme_colors.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/lunch_poll_schedule.dart';
import '../../../data/models/lunch_model.dart';
import '../../providers/lunch_provider.dart';

export '../../../core/utils/lunch_poll_schedule.dart'
    show
        isPollEndTimeViable,
        lunchDefaultEndTimeApi,
        lunchEndTimeOfDay,
        lunchEndTimeToApi,
        lunchExtendMinutesUntil,
        lunchPollEndDateTime,
        preferPollEndTime;

/// Web lunch module accent colors.
const Color lunchBrandGreen = Color(0xFF22C55E);
const Color lunchBrandPurple = Color(0xFF6366F1);
const Color lunchBrandOrange = Color(0xFFF97316);

/// API option types: `office` (menu), `personal`, `off` (see production polls).
/// Legacy reads also accept `office_menu` / `yes` — see [lunchOptionKindFrom].
String lunchOptionKindApiValue(LunchOptionKind kind) {
  switch (kind) {
    case LunchOptionKind.officeMenu:
      return 'office';
    case LunchOptionKind.personal:
      return 'personal';
    case LunchOptionKind.offAbsent:
      return 'off';
    case LunchOptionKind.other:
      return 'other';
  }
}

LunchOptionKind lunchOptionKindFromApiValue(String? raw) => lunchOptionKindFrom(raw);

pw.ThemeData? _lunchPdfThemeCache;

Future<pw.ThemeData> _loadLunchPdfTheme() async {
  if (_lunchPdfThemeCache != null) return _lunchPdfThemeCache!;

  final base = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  final bengali = await PdfGoogleFonts.notoSansBengaliRegular();
  final bengaliBold = await PdfGoogleFonts.notoSansBengaliBold();

  _lunchPdfThemeCache = pw.ThemeData.withFont(
    base: base,
    bold: bold,
    fontFallback: [bengali, bengaliBold, base],
  );
  return _lunchPdfThemeCache!;
}

final pw.TextStyle _pdfTableHeaderStyle = pw.TextStyle(
  fontSize: 10,
  fontWeight: pw.FontWeight.bold,
);
final pw.TextStyle _pdfTableCellStyle = pw.TextStyle(fontSize: 9);

Future<void> exportLunchOrderSummaryPdf(LunchOrderSummary summary) async {
  final theme = await _loadLunchPdfTheme();
  final poll = summary.poll;
  final dateStr = poll.date != null
      ? DateFormat('EEEE, MMMM d, yyyy').format(poll.date!.toLocal())
      : 'Lunch order';
  final doc = pw.Document(theme: theme);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Header(
          level: 0,
          child: pw.Text(
            'Order Summary - ${poll.title}',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Text(dateStr),
        pw.SizedBox(height: 8),
        pw.Text('Status: ${poll.status.toUpperCase()}'),
        pw.SizedBox(height: 16),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _pdfStat('Office orders', '${summary.officeOrders}'),
            _pdfStat('Personal', '${summary.personalCount}'),
            _pdfStat('Total votes', '${summary.totalVotes}'),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Text('Menu breakdown', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.TableHelper.fromTextArray(
          headers: const ['Menu item', 'Type', 'Votes', 'Share %'],
          headerStyle: _pdfTableHeaderStyle,
          cellStyle: _pdfTableCellStyle,
          data: summary.menuBreakdown
              .map(
                (r) => [
                  r.label,
                  lunchOptionKindLabel(r.kind),
                  '${r.votes}',
                  '${r.share.toStringAsFixed(0)}%',
                ],
              )
              .toList(),
        ),
        pw.SizedBox(height: 20),
        pw.Text('Employee votes', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.TableHelper.fromTextArray(
          headers: const ['Employee', 'Choice', 'Type', 'Voted'],
          headerStyle: _pdfTableHeaderStyle,
          cellStyle: _pdfTableCellStyle,
          data: summary.employeeVotes
              .map(
                (r) => [
                  r.userName,
                  r.choice,
                  lunchOptionKindLabel(r.kind),
                  r.votedAt != null
                      ? DateFormat.jm().format(r.votedAt!.toLocal())
                      : '-',
                ],
              )
              .toList(),
        ),
      ],
    ),
  );

  await Printing.layoutPdf(onLayout: (format) async => doc.save());
}

pw.Widget _pdfStat(String label, String value) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
    ],
  );
}

String formatLunchVoteTime(DateTime? dt) {
  if (dt == null) return '';
  final local = dt.toLocal();
  final now = DateTime.now();
  final sameDay =
      local.year == now.year && local.month == now.month && local.day == now.day;
  if (sameDay) return DateFormat.jm().format(local);
  return DateFormat('MMM d, jm').format(local);
}

void showLunchVoteDisabledMessage(BuildContext context, LunchPoll poll) {
  final String message;
  if (poll.isCancelled) {
    message = 'This poll was cancelled. Voting is not available.';
  } else if (poll.isClosed) {
    message = 'This poll is closed. Voting is no longer available.';
  } else if (poll.isPastEndTime) {
    message =
        'Voting closed at ${formatLunchEndTimeDisplay(poll.endTime)}.';
  } else {
    message = 'Voting is not available for this poll.';
  }
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Display HH:mm or existing 12h string as 12-hour time (e.g. "6:30 PM").
String formatLunchEndTimeDisplay(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '—';
  final tod = lunchEndTimeOfDay(raw);
  final dt = DateTime(2000, 1, 1, tod.hour, tod.minute);
  return DateFormat.jm().format(dt);
}

extension LunchPollVoting on LunchPoll {
  bool get isPastEndTime => lunchPollIsPastEndTime(
        endTime: endTime,
        pollDate: date,
        status: status,
      );

  /// Prior-day reactivated polls: first vote only — no changing an existing choice.
  bool get allowsVoteChanges => allowVoteChange && !isPriorDayPoll;

  String get effectiveStatus {
    if (isCancelled) return 'cancelled';
    if (isClosed || isPastEndTime) return 'closed';
    return status.toLowerCase();
  }

  bool get isVotingOpen =>
      !isCancelled && status.toLowerCase() == 'active' && !isPastEndTime;

  /// Admin poll list / edit actions.
  bool get canAdminClosePoll => !isCancelled && isVotingOpen;
}

String formatLunchPollDate(DateTime? dt) {
  if (dt == null) return '';
  return DateFormat('EEEE, MMMM d, yyyy').format(dt.toLocal());
}

String formatLunchPollDateShort(DateTime? dt) {
  if (dt == null) return '';
  return DateFormat('MMM d, yyyy').format(dt.toLocal());
}

Color lunchOptionKindColor(LunchOptionKind kind, ColorScheme cs) {
  switch (kind) {
    case LunchOptionKind.officeMenu:
      return const Color(0xFF6366F1);
    case LunchOptionKind.personal:
      return const Color(0xFF22C55E);
    case LunchOptionKind.offAbsent:
      return cs.outline;
    case LunchOptionKind.other:
      return cs.secondary;
  }
}

Color lunchOptionKindBg(LunchOptionKind kind, ColorScheme cs) {
  return lunchOptionKindColor(kind, cs).withValues(alpha: 0.12);
}

IconData lunchOptionKindIcon(LunchOptionKind kind) {
  switch (kind) {
    case LunchOptionKind.officeMenu:
      return Icons.restaurant_rounded;
    case LunchOptionKind.personal:
      return Icons.person_rounded;
    case LunchOptionKind.offAbsent:
      return Icons.home_rounded;
    case LunchOptionKind.other:
      return Icons.more_horiz_rounded;
  }
}

/// Pill chip for poll meta (status, votes, end time).
Widget lunchPollMetaChip({
  required IconData icon,
  required String label,
  Color? foreground,
  Color? background,
  Color? border,
  bool compact = false,
}) {
  return Builder(
    builder: (context) {
      final cs = Theme.of(context).colorScheme;
      final fg = foreground ?? cs.onSurfaceVariant;
      final bg = background ?? cs.surfaceContainerHighest.withValues(alpha: 0.7);
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 10,
          vertical: compact ? 3 : 5,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(compact ? 14 : 20),
          border: Border.all(color: border ?? cs.outline.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 11 : 13, color: fg),
            SizedBox(width: compact ? 3 : 5),
            Text(
              label,
              style: TextStyle(
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w600,
                color: fg,
                letterSpacing: 0.15,
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget lunchPollStatusMetaChip(String status, {bool compact = false}) {
  return Builder(
    builder: (context) {
      final cs = Theme.of(context).colorScheme;
      final s = status.toLowerCase();
      Color fg;
      Color bg;
      IconData icon;
      String label;
      switch (s) {
        case 'active':
          fg = lunchBrandGreen;
          bg = fg.withValues(alpha: 0.12);
          icon = Icons.bolt_rounded;
          label = 'POLL OPEN';
        case 'closed':
          fg = lunchBrandOrange;
          bg = fg.withValues(alpha: 0.1);
          icon = Icons.auto_awesome;
          label = 'POLL CLOSED';
        case 'cancelled':
          fg = cs.error;
          bg = cs.errorContainer.withValues(alpha: 0.4);
          icon = Icons.block;
          label = 'CANCELLED';
        default:
          fg = cs.onSurfaceVariant;
          bg = cs.surfaceContainerHighest;
          icon = Icons.info_outline;
          label = s.toUpperCase();
      }
      return lunchPollMetaChip(
        icon: icon,
        label: label,
        foreground: fg,
        background: bg,
        border: fg.withValues(alpha: 0.25),
        compact: compact,
      );
    },
  );
}

Widget lunchOptionTypeBadge(String optionType, {double fontSize = 10, bool shortLabel = false}) {
  return Builder(
    builder: (context) {
      final cs = Theme.of(context).colorScheme;
      final kind = lunchOptionKindFrom(optionType);
      final fg = lunchOptionKindColor(kind, cs);
      final bg = lunchOptionKindBg(kind, cs);
      final label = shortLabel ? lunchOptionKindShortLabel(kind) : lunchOptionKindLabel(kind);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: fg.withValues(alpha: 0.25)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: fg,
            letterSpacing: 0.3,
          ),
        ),
      );
    },
  );
}

Widget lunchPollStatusBadge(String status) {
  return Builder(
    builder: (context) {
      final cs = Theme.of(context).colorScheme;
      final s = status.toLowerCase();
      Color fg;
      Color bg;
      switch (s) {
        case 'active':
          fg = lunchBrandGreen;
          bg = fg.withValues(alpha: 0.12);
        case 'closed':
          fg = cs.outline;
          bg = cs.surfaceContainerHighest;
        case 'cancelled':
          fg = cs.error;
          bg = cs.errorContainer.withValues(alpha: 0.4);
        default:
          fg = cs.onSurfaceVariant;
          bg = cs.surfaceContainerHighest;
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: fg.withValues(alpha: 0.2)),
        ),
        child: Text(
          s.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: fg,
            letterSpacing: 0.5,
          ),
        ),
      );
    },
  );
}

/// Module intro under the app bar — date and helper text only.
class LunchModuleHeader extends StatelessWidget {
  const LunchModuleHeader({
    super.key,
    this.subtitle = 'Vote for today\'s menu and track your balance',
    this.date,
  });

  final String subtitle;
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final cs = Theme.of(context).colorScheme;
    final d = date ?? DateTime.now();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppThemeColors.heroSurface(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppThemeColors.iconChip(
            context,
            icon: Icons.restaurant_menu_rounded,
            accent: lunchBrandGreen,
            size: 44,
            iconSize: 22,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today\'s lunch',
                  style: AppTypography.sectionTitle(context)?.copyWith(
                        color: textPrimary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: textSecondary,
                        height: 1.35,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  formatLunchPollDate(d),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact read-only vote bars for poll list cards.
class LunchPollVoteBreakdown extends StatelessWidget {
  const LunchPollVoteBreakdown({super.key, required this.poll, this.compact = true});

  final LunchPoll poll;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final options = poll.mergedOptions;
    if (options.isEmpty) return const SizedBox.shrink();

    final total = poll.totalVoteCount;
    final cs = Theme.of(context).colorScheme;
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: options.map((opt) {
        final count = opt.effectiveVoteCount;
        final fraction = total > 0 ? count / total : 0.0;
        final accent = lunchBrandPurple;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      opt.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 12 : 13,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: compact ? 12 : 13,
                      fontWeight: FontWeight.w700,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: fraction.clamp(0.0, 1.0),
                  minHeight: compact ? 5 : 6,
                  backgroundColor: cs.surfaceContainerHighest,
                  color: accent,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

void showLunchPollVotesSheet(BuildContext context, LunchPoll poll) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _LunchPollVotesSheet(initialPoll: poll),
  );
}

class _LunchPollVotesSheet extends ConsumerStatefulWidget {
  const _LunchPollVotesSheet({required this.initialPoll});

  final LunchPoll initialPoll;

  @override
  ConsumerState<_LunchPollVotesSheet> createState() =>
      _LunchPollVotesSheetState();
}

class _LunchPollVotesSheetState
    extends ConsumerState<_LunchPollVotesSheet> {
  bool _refreshing = true;
  bool _refreshFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    if (!_refreshing) {
      setState(() {
        _refreshing = true;
        _refreshFailed = false;
      });
    }
    final ok = await ref
        .read(lunchProvider.notifier)
        .refreshPollVotes(widget.initialPoll.id);
    if (!mounted) return;
    setState(() {
      _refreshing = false;
      _refreshFailed = !ok;
    });
  }

  LunchPoll _livePoll(LunchState state) {
    for (final poll in [...state.todayPolls, ...state.adminPolls]) {
      if (poll.id == widget.initialPoll.id) return poll;
    }
    return widget.initialPoll;
  }

  @override
  Widget build(BuildContext context) {
    final poll = _livePoll(ref.watch(lunchProvider));
    final options = poll.mergedOptions;
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back',
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'All votes — ${poll.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text(
                        _refreshing
                            ? 'Updating latest votes…'
                            : _refreshFailed
                                ? 'Could not refresh · showing saved results'
                                : 'Latest votes loaded',
                        style: TextStyle(
                          fontSize: 11,
                          color: _refreshFailed
                              ? Theme.of(context).colorScheme.error
                              : textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh votes',
                  onPressed: _refreshing ? null : _reload,
                  icon: _refreshing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: options.map((opt) {
                  final count = opt.effectiveVoteCount;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                opt.label,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              '$count vote${count == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (opt.voters.isEmpty)
                          Text(
                            'No votes yet',
                            style: TextStyle(
                              fontSize: 13,
                              color: textSecondary,
                            ),
                          )
                        else
                          ...opt.voters.map(
                            (v) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              leading: CircleAvatar(
                                radius: 16,
                                child: Text(
                                  v.name.isNotEmpty
                                      ? v.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              title: Text(
                                v.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: textPrimary,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
