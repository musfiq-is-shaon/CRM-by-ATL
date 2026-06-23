import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/theme/app_theme_colors.dart';
import '../../../data/models/lunch_model.dart';

/// Web lunch module accent colors.
const Color lunchBrandGreen = Color(0xFF22C55E);
const Color lunchBrandPurple = Color(0xFF6366F1);

String lunchOptionKindApiValue(LunchOptionKind kind) {
  switch (kind) {
    case LunchOptionKind.officeMenu:
      return 'office_menu';
    case LunchOptionKind.personal:
      return 'personal';
    case LunchOptionKind.offAbsent:
      return 'off';
    case LunchOptionKind.other:
      return 'other';
  }
}

LunchOptionKind lunchOptionKindFromApiValue(String? raw) => lunchOptionKindFrom(raw);

Future<void> exportLunchOrderSummaryPdf(LunchOrderSummary summary) async {
  final poll = summary.poll;
  final dateStr = poll.date != null
      ? DateFormat('EEEE, MMMM d, yyyy').format(poll.date!.toLocal())
      : 'Lunch order';
  final doc = pw.Document();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Header(
          level: 0,
          child: pw.Text(
            'Order Summary — ${poll.title}',
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
        pw.Table.fromTextArray(
          headers: const ['Menu item', 'Type', 'Votes', 'Share %'],
          data: summary.menuBreakdown
              .map(
                (r) => [
                  r.label,
                  lunchOptionKindLabel(r.kind),
                  '${r.votes}',
                  r.share.toStringAsFixed(0),
                ],
              )
              .toList(),
        ),
        pw.SizedBox(height: 20),
        pw.Text('Employee votes', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.Table.fromTextArray(
          headers: const ['Employee', 'Choice', 'Type', 'Voted'],
          data: summary.employeeVotes
              .map(
                (r) => [
                  r.userName,
                  r.choice,
                  lunchOptionKindLabel(r.kind),
                  r.votedAt != null
                      ? DateFormat.jm().format(r.votedAt!.toLocal())
                      : '—',
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
  if (dt == null) return '—';
  return DateFormat.jm().format(dt.toLocal());
}

/// Display HH:mm or existing 12h string as 12-hour time (e.g. "6:30 PM").
String formatLunchEndTimeDisplay(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '—';
  final t = raw.trim();
  final parts = t.split(':');
  if (parts.length >= 2) {
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final dt = DateTime(2000, 1, 1, h, m);
    return DateFormat.jm().format(dt);
  }
  return t;
}

/// Parse 12h or 24h display to API `HH:mm` (24-hour).
String lunchEndTimeToApi(String display) {
  final t = display.trim();
  if (t.isEmpty) return t;
  try {
    final parsed = DateFormat.jm().parse(t);
    return '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    // Already 24h
    final parts = t.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }
  }
  return t;
}

TimeOfDay lunchEndTimeOfDay(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const TimeOfDay(hour: 18, minute: 0);
  final t = raw.trim();
  try {
    final parsed = DateFormat.jm().parse(t);
    return TimeOfDay(hour: parsed.hour, minute: parsed.minute);
  } catch (_) {
    final parts = t.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.first) ?? 18,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
  }
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
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final d = date ?? DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(subtitle, style: TextStyle(fontSize: 14, color: textSecondary)),
        const SizedBox(height: 4),
        Text(
          formatLunchPollDate(d),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: textSecondary,
          ),
        ),
      ],
    );
  }
}
