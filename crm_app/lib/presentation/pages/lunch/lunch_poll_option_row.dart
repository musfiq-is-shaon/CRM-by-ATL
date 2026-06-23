import 'package:flutter/material.dart';

import '../../../core/theme/app_theme_colors.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/lunch_model.dart';
import '../../widgets/avatar_widget.dart';
import 'lunch_ui_helpers.dart';

/// Single poll choice row — radio, label, vote bar, voter avatars (web parity).
class LunchPollOptionRow extends StatelessWidget {
  const LunchPollOptionRow({
    super.key,
    required this.option,
    required this.selected,
    required this.totalVotes,
    required this.enabled,
    required this.onTap,
  });

  final LunchPollOption option;
  final bool selected;
  final int totalVotes;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final accent = lunchOptionKindColor(option.kind, cs);
    final fraction = totalVotes > 0 ? option.voteCount / totalVotes : 0.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off_outlined,
                  size: 22,
                  color: selected ? lunchBrandGreen : textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: fraction.clamp(0.0, 1.0),
                              minHeight: 8,
                              backgroundColor: cs.surfaceContainerHighest,
                              color: accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${option.voteCount}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                    if (option.voters.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _VoterAvatarStack(voters: option.voters),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoterAvatarStack extends StatelessWidget {
  const _VoterAvatarStack({required this.voters});

  final List<LunchOptionVoter> voters;

  @override
  Widget build(BuildContext context) {
    final shown = voters.take(6).toList();
    return SizedBox(
      height: 28,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * 20.0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppThemeColors.cardColor(context),
                    width: 2,
                  ),
                ),
                child: AvatarWidget(name: shown[i].name, size: 24),
              ),
            ),
          if (voters.length > 6)
            Positioned(
              left: shown.length * 20.0,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Text(
                  '+${voters.length - 6}',
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Type selector chips for poll form (OFFICE MENU / PERSONAL / OFF).
class LunchOptionTypeSelector extends StatelessWidget {
  const LunchOptionTypeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final LunchOptionKind selected;
  final ValueChanged<LunchOptionKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: LunchOptionKind.values
          .where((k) => k != LunchOptionKind.other)
          .map(
            (kind) => _TypeChip(
              label: lunchOptionKindLabel(kind),
              kind: kind,
              selected: selected == kind,
              onTap: () => onChanged(kind),
            ),
          )
          .toList(),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final LunchOptionKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = lunchOptionKindColor(kind, cs);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? fg.withValues(alpha: 0.15) : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? fg : cs.outlineVariant.withValues(alpha: 0.5),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: selected ? fg : cs.onSurfaceVariant,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
