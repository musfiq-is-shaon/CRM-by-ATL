import 'package:flutter/material.dart';

import '../../../core/theme/app_theme_colors.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/lunch_model.dart';
import '../../widgets/avatar_widget.dart';
import 'lunch_ui_helpers.dart';

/// Card-style poll option — matches My Lunch reference layout.
class LunchPollOptionCard extends StatelessWidget {
  const LunchPollOptionCard({
    super.key,
    required this.option,
    required this.selected,
    required this.totalVotes,
    required this.enabled,
    required this.onTap,
    this.compact = false,
    this.dimmed = false,
  });

  final LunchPollOption option;
  final bool selected;
  final int totalVotes;
  final bool enabled;
  final VoidCallback? onTap;
  final bool compact;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final kind = option.kind;
    final kindColor = lunchOptionKindColor(kind, cs);
    final count = option.effectiveVoteCount;
    final fraction = totalVotes > 0 ? count / totalVotes : 0.0;
    final inactive = dimmed && !selected;
    final borderColor = selected
        ? lunchBrandOrange
        : inactive
            ? cs.outline.withValues(alpha: 0.18)
            : cs.outline.withValues(alpha: 0.3);
    final bgColor = selected
        ? lunchBrandOrange.withValues(alpha: inactive ? 0.03 : 0.04)
        : inactive
            ? cs.surfaceContainerHighest.withValues(alpha: 0.45)
            : cs.surface;
    final labelColor = inactive ? textSecondary.withValues(alpha: 0.75) : textPrimary;
    final iconBg = selected
        ? lunchBrandOrange
        : inactive
            ? cs.outline.withValues(alpha: 0.12)
            : kindColor.withValues(alpha: 0.12);
    final iconFg = selected
        ? Colors.white
        : inactive
            ? textSecondary.withValues(alpha: 0.55)
            : kindColor;
    final progressBg = inactive
        ? cs.surfaceContainerHighest
        : const Color(0xFFFEF3C7);
    final progressFg = selected
        ? lunchBrandOrange
        : inactive
            ? cs.outline.withValues(alpha: 0.35)
            : const Color(0xFFFDE68A);
    final radius = compact ? 10.0 : 14.0;
    final iconSize = compact ? 32.0 : 40.0;
    final iconGlyph = compact ? 16.0 : 20.0;
    final labelSize = compact ? 13.0 : 15.0;
    final gap = compact ? 6.0 : 10.0;
    final cardPad = compact
        ? const EdgeInsets.fromLTRB(8, 8, 8, 7)
        : const EdgeInsets.fromLTRB(12, 12, 12, 10);
    final checkSize = compact ? 20.0 : 26.0;
    final checkIcon = compact ? 13.0 : 16.0;

    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 6 : 10),
      child: Opacity(
        opacity: inactive ? 0.52 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(radius),
            child: Container(
              padding: cardPad,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: borderColor,
                  width: selected ? (compact ? 1.5 : 2) : 1,
                ),
                boxShadow: compact || inactive
                    ? null
                    : [
                        BoxShadow(
                          color: cs.shadow.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: iconSize,
                        height: iconSize,
                        decoration: BoxDecoration(
                          color: iconBg,
                          borderRadius: BorderRadius.circular(compact ? 8 : 10),
                        ),
                        child: Icon(
                          lunchOptionKindIcon(kind),
                          size: iconGlyph,
                          color: iconFg,
                        ),
                      ),
                      SizedBox(width: compact ? 8 : 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: compact ? 4 : 6,
                              runSpacing: compact ? 2 : 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  option.label,
                                  style: TextStyle(
                                    fontSize: labelSize,
                                    fontWeight: FontWeight.w700,
                                    color: labelColor,
                                    height: 1.15,
                                  ),
                                ),
                              if (selected)
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: compact ? 6 : 8,
                                    vertical: compact ? 1 : 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: lunchBrandOrange,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    'YOUR VOTE',
                                    style: TextStyle(
                                      fontSize: compact ? 8 : 9,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              lunchOptionTypeBadge(
                                option.optionType,
                                fontSize: compact ? 8 : 9,
                                shortLabel: true,
                              ),
                            ],
                          ),
                          if (option.voters.isNotEmpty || count > 0) ...[
                            SizedBox(height: compact ? 4 : 8),
                            Row(
                              children: [
                                if (option.voters.isNotEmpty)
                                  Expanded(
                                    child: LunchVoterAvatarStack(
                                      voters: option.voters,
                                      compact: compact,
                                    ),
                                  )
                                else
                                  const Spacer(),
                                Text(
                                  '$count ${count == 1 ? 'vote' : 'votes'}',
                                  style: TextStyle(
                                    fontSize: compact ? 10 : 12,
                                    fontWeight: FontWeight.w500,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (selected) ...[
                      SizedBox(width: compact ? 4 : 6),
                      Container(
                        width: checkSize,
                        height: checkSize,
                        decoration: const BoxDecoration(
                          color: lunchBrandOrange,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: checkIcon,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: gap),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: fraction.clamp(0.0, 1.0),
                    minHeight: compact ? 3 : 5,
                    backgroundColor: progressBg,
                    color: progressFg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}

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
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final voteAccent = enabled
        ? lunchBrandPurple
        : textSecondary.withValues(alpha: 0.45);
    final count = option.effectiveVoteCount;
    final fraction = totalVotes > 0 ? count / totalVotes : 0.0;
    final labelColor = enabled ? voteAccent : textSecondary;
    final radioColor = voteAccent;
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
                                color: voteAccent,
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
                        LunchVoterAvatarStack(
                          voters: option.voters,
                          compact: compact,
                        ),
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

class LunchVoterAvatarStack extends StatelessWidget {
  const LunchVoterAvatarStack({super.key, required this.voters, this.compact = false});

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
    final accent = lunchBrandPurple;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: selected ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? accent : accent.withValues(alpha: 0.35),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: accent,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
