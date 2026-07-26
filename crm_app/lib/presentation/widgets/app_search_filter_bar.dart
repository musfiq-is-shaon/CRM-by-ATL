import 'package:flutter/material.dart';

import '../../core/theme/app_theme_colors.dart';
import '../../core/theme/design_tokens.dart';

/// Shared search + optional filter action row for list screens.
class AppSearchFilterBar extends StatefulWidget {
  const AppSearchFilterBar({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
    this.focusNode,
    this.onFilterTap,
    this.activeFilterCount = 0,
    this.padding = AppThemeColors.searchFilterBarPadding,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback? onFilterTap;
  final int activeFilterCount;
  final EdgeInsetsGeometry padding;

  @override
  State<AppSearchFilterBar> createState() => _AppSearchFilterBarState();
}

class _AppSearchFilterBarState extends State<AppSearchFilterBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant AppSearchFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    widget.onChanged(widget.controller.text);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final textTertiary = AppThemeColors.textTertiaryColor(context);
    final borderColor = AppThemeColors.borderColor(context);
    final primary = Theme.of(context).colorScheme.primary;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    return Padding(
      padding: widget.padding,
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: AppSizes.searchBarHeight,
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                style: AppTypography.input(context)?.copyWith(color: textPrimary),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: AppTypography.bodySmall(context)?.copyWith(
                        color: textTertiary,
                      ),
                  prefixIcon: Icon(Icons.search, color: textSecondary),
                  suffixIcon: widget.controller.text.isNotEmpty
                      ? IconButton(
                          tooltip: 'Clear search',
                          icon: Icon(Icons.clear, color: textSecondary),
                          onPressed: widget.onClear,
                        )
                      : null,
                  filled: true,
                  fillColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide:
                        BorderSide(color: borderColor.withValues(alpha: 0.6)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide:
                        BorderSide(color: borderColor.withValues(alpha: 0.45)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: primary, width: 2),
                  ),
                ),
              ),
            ),
          ),
          if (widget.onFilterTap != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Semantics(
              button: true,
              label: widget.activeFilterCount > 0
                  ? 'Open filters, ${widget.activeFilterCount} active'
                  : 'Open filters',
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: widget.onFilterTap,
                  child: SizedBox(
                    width: AppSizes.searchBarHeight,
                    height: AppSizes.searchBarHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Center(
                          child: Icon(Icons.filter_list, color: primary),
                        ),
                        if (widget.activeFilterCount > 0)
                          Positioned(
                            right: AppSpacing.xs,
                            top: AppSpacing.xs,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: primary,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.sm),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 14,
                              ),
                              child: Text(
                                '${widget.activeFilterCount}',
                                style: AppTypography.caption(context)?.copyWith(
                                      color: onPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
