import 'package:flutter/material.dart';

import '../../../core/theme/design_tokens.dart';
import '../../widgets/app_section_header.dart';

/// Page title block used inside lunch tab bodies (app bar shows "Lunch").
class LunchPageTitle extends StatelessWidget {
  const LunchPageTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing = const [],
  });

  final String title;
  final String? subtitle;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AppSectionHeader(title: title, subtitle: subtitle),
        ),
        ...trailing,
      ],
    );
  }
}

/// Active filter chips row (theme-aligned).
class LunchActiveFiltersRow extends StatelessWidget {
  const LunchActiveFiltersRow({super.key, required this.labels, this.onRemove});

  final List<String> labels;
  final void Function(String label)? onRemove;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xxs,
        children: labels.map((label) {
          return InputChip(
            label: Text(label, style: const TextStyle(fontSize: 12)),
            deleteIcon: onRemove != null ? const Icon(Icons.close, size: 16) : null,
            onDeleted: onRemove != null ? () => onRemove!(label) : null,
            backgroundColor: cs.primaryContainer.withValues(alpha: 0.35),
            side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
          );
        }).toList(),
      ),
    );
  }
}
