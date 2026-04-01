import 'package:flutter/material.dart';

enum AppSemanticTone { info, success, warning, danger }

/// Small semantic pill for statuses/tags with theme-safe contrast.
class AppSemanticPill extends StatelessWidget {
  const AppSemanticPill({
    super.key,
    required this.label,
    this.tone = AppSemanticTone.info,
    this.compact = true,
  });

  final String label;
  final AppSemanticTone tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ({Color bg, Color fg}) colors = switch (tone) {
      AppSemanticTone.info => (bg: cs.secondaryContainer, fg: cs.onSecondaryContainer),
      AppSemanticTone.success => (bg: cs.tertiaryContainer, fg: cs.onTertiaryContainer),
      AppSemanticTone.warning => (bg: cs.errorContainer, fg: cs.onErrorContainer),
      AppSemanticTone.danger => (bg: cs.error, fg: cs.onError),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w700,
          color: colors.fg,
        ),
      ),
    );
  }
}
