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
    this.compact = false,
  });

  final LunchPollOption option;
  final bool selected;
  final int totalVotes;
  final bool enabled;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final accent = lunchOptionKindColor(option.kind, cs);
    final count = option.effectiveVoteCount;
    final fraction = totalVotes > 0 ? count / totalVotes : 0.0;
    final labelColor = enabled ? textPrimary : textSecondary;
    final radioColor = enabled
        ? (selected ? lunchBrandGreen : textSecondary)
        : textSecondary.withValues(alpha: 0.45);
    final rowPad = compact ? 5.0 : 10.0;
    final radioSize = compact ? 20.0 : 22.0;
    final labelSize = compact ? 13.0 : 14.0;
    final gap = compact ? 4.0 : 8.0;
    final barHeight = compact ? 6.0 : 8.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Opacity(
          opacity: enabled ? 1 : 0.55,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: rowPad),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: compact ? 1 : 2),
                  child: Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off_outlined,
                    size: radioSize,
                    color: radioColor,
                  ),
                ),
                SizedBox(width: compact ? 8 : 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.label,
                        style: TextStyle(
                          fontSize: labelSize,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: labelColor,
                        ),
                      ),
                      SizedBox(height: gap),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: fraction.clamp(0.0, 1.0),
                                minHeight: barHeight,
                                backgroundColor: cs.surfaceContainerHighest,
                                color: enabled ? accent : textSecondary.withValues(alpha: 0.35),
                              ),
                            ),
                          ),
                          SizedBox(width: compact ? 6 : 8),
                          Text(
                            '$count',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: compact ? 12 : 13,
                              color: labelColor,
                            ),
                          ),
                        ],
                      ),
                      if (option.voters.isNotEmpty) ...[
                        SizedBox(height: gap),
                        _VoterAvatarStack(voters: option.voters, compact: compact),
                      ],
                    ],
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

class _VoterAvatarStack extends StatelessWidget {
  const _VoterAvatarStack({required this.voters, this.compact = false});

  final List<LunchOptionVoter> voters;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final shown = voters.take(6).toList();
    final size = compact ? 20.0 : 24.0;
    final step = compact ? 16.0 : 20.0;
    final stackHeight = compact ? 22.0 : 28.0;
    return SizedBox(
      height: stackHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * step,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppThemeColors.cardColor(context),
                    width: compact ? 1.5 : 2,
                  ),
                ),
                child: AvatarWidget(name: shown[i].name, size: size),
              ),
            ),
          if (voters.length > 6)
            Positioned(
              left: shown.length * step,
              child: CircleAvatar(
                radius: compact ? 10 : 12,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Text(
                  '+${voters.length - 6}',
                  style: TextStyle(
                    fontSize: compact ? 8 : 9,
                    fontWeight: FontWeight.w700,
                  ),
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
