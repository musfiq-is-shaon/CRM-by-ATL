import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme_colors.dart';

/// Wraps [child] (usually a [Scaffold]) with optional confetti + message overlay.
/// Blocks back navigation while [celebrating] is true.
class CelebrationShell extends StatelessWidget {
  const CelebrationShell({
    super.key,
    required this.celebrating,
    required this.confettiController,
    required this.child,
    required this.title,
    required this.message,
    this.icon = Icons.celebration_rounded,
  });

  final bool celebrating;
  final ConfettiController confettiController;
  final Widget child;
  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final tertiaryColor = Theme.of(context).colorScheme.tertiary;

    return PopScope(
      canPop: !celebrating,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          if (celebrating)
            Positioned.fill(
              child: AbsorbPointer(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: Colors.black.withValues(alpha: 0.32),
                    ),
                    ConfettiWidget(
                      confettiController: confettiController,
                      blastDirectionality: BlastDirectionality.explosive,
                      emissionFrequency: 0.05,
                      numberOfParticles: 20,
                      maxBlastForce: 34,
                      minBlastForce: 11,
                      gravity: 0.14,
                      colors: [
                        primaryColor,
                        tertiaryColor,
                        Colors.amber.shade400,
                        Colors.pinkAccent.shade200,
                        Colors.lightBlueAccent.shade100,
                      ],
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Material(
                          color: surfaceColor,
                          elevation: 12,
                          shadowColor: primaryColor.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 28,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  icon,
                                  size: 56,
                                  color: primaryColor,
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  title,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  message,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
