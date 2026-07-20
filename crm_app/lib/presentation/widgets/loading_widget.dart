import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/theme/app_theme_colors.dart';
import '../../core/theme/design_tokens.dart';

class LoadingWidget extends StatelessWidget {
  final String? message;

  const LoadingWidget({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                color: cs.primary,
                strokeWidth: 2.5,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                message!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ShimmerLoading extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerLoading({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = AppRadius.sm,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: cs.surfaceContainerHighest,
      highlightColor: cs.surfaceContainerHigh,
      period: const Duration(milliseconds: 1100),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class ShimmerCard extends StatelessWidget {
  const ShimmerCard({super.key, this.height});

  final double? height;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: height,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxH = constraints.maxHeight;
          final bounded = maxH.isFinite;
          final lineCount = !bounded || maxH >= 76 ? 3 : 2;
          final gaps = (lineCount - 1) * AppSpacing.xs;
          final lineH = bounded
              ? ((maxH - gaps) / lineCount).clamp(8.0, 14.0)
              : 12.0;
          const widths = [100.0, 160.0, 120.0];

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < lineCount; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.xs),
                ShimmerLoading(width: widths[i], height: lineH),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Skeleton list for list pages — scrolls inside [Expanded] / slivers.
class ListSkeletonLoader extends StatelessWidget {
  const ListSkeletonLoader({
    super.key,
    this.itemCount = 6,
    this.padding,
    this.shrinkWrap = false,
  });

  final int itemCount;
  final EdgeInsetsGeometry? padding;
  /// Use true only inside unbounded parents (e.g. [SliverToBoxAdapter]).
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: shrinkWrap
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      shrinkWrap: shrinkWrap,
      padding: padding ?? EdgeInsets.zero,
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, _) => const ShimmerCard(height: 76),
    );
  }
}

/// Dashboard / detail hero skeleton.
class DashboardHeroSkeleton extends StatelessWidget {
  const DashboardHeroSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShimmerLoading(width: 120, height: 14),
        SizedBox(height: AppSpacing.sm),
        ShimmerLoading(width: 220, height: 28),
        SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(child: ShimmerCard(height: 76)),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: ShimmerCard(height: 76)),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: ShimmerCard(height: 76)),
          ],
        ),
      ],
    );
  }
}

// --- Global loading UX aliases & variants ---

typedef PageSkeleton = DashboardHeroSkeleton;
typedef CardSkeleton = ShimmerCard;
typedef ListSkeleton = ListSkeletonLoader;

/// Full dashboard page placeholder.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppThemeColors.pagePaddingAll,
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        DashboardHeroSkeleton(),
        SizedBox(height: AppSpacing.lg),
        ShimmerLoading(width: 140, height: 18),
        SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(child: ShimmerCard(height: 100)),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: ShimmerCard(height: 100)),
          ],
        ),
        SizedBox(height: AppSpacing.lg),
        ShimmerLoading(width: 160, height: 18),
        SizedBox(height: AppSpacing.sm),
        ShimmerCard(height: 72),
        SizedBox(height: AppSpacing.sm),
        ShimmerCard(height: 72),
        SizedBox(height: AppSpacing.sm),
        ShimmerCard(height: 72),
      ],
    );
  }
}

/// Detail / form page placeholder (title, hero, metadata, actions).
class DetailSkeleton extends StatelessWidget {
  const DetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppThemeColors.pagePaddingAll,
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        ShimmerLoading(width: 200, height: 24),
        SizedBox(height: AppSpacing.lg),
        ShimmerCard(height: 160),
        SizedBox(height: AppSpacing.lg),
        ShimmerCard(height: 56),
        SizedBox(height: AppSpacing.sm),
        ShimmerCard(height: 56),
        SizedBox(height: AppSpacing.sm),
        ShimmerCard(height: 56),
        SizedBox(height: AppSpacing.lg),
        ShimmerLoading(width: 140, height: 14),
        SizedBox(height: AppSpacing.sm),
        ShimmerCard(height: 100),
        SizedBox(height: AppSpacing.xl),
        ShimmerLoading(height: AppSizes.buttonHeight),
      ],
    );
  }
}

/// Profile / settings header skeleton.
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppThemeColors.pagePaddingAll,
      child: Column(
        children: [
          const ImageSkeleton(width: 88, height: 88, borderRadius: 44),
          const SizedBox(height: AppSpacing.md),
          const ShimmerLoading(width: 180, height: 22),
          const SizedBox(height: AppSpacing.xs),
          const ShimmerLoading(width: 140, height: 14),
          const SizedBox(height: AppSpacing.xl),
          for (var i = 0; i < 4; i++) ...[
            const ShimmerCard(height: 52),
            if (i < 3) const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.lg),
          const ShimmerLoading(
            width: double.infinity,
            height: AppSizes.buttonHeight,
          ),
        ],
      ),
    );
  }
}

/// Table / admin list rows.
class TableSkeleton extends StatelessWidget {
  const TableSkeleton({super.key, this.rowCount = 8});

  final int rowCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: AppThemeColors.pagePaddingHorizontal,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: rowCount,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (_, _) => const ShimmerCard(height: 48),
    );
  }
}

/// Form field placeholders while config loads.
class FormSkeleton extends StatelessWidget {
  const FormSkeleton({super.key, this.fieldCount = 4});

  final int fieldCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppThemeColors.pagePaddingAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < fieldCount; i++) ...[
            ShimmerLoading(width: 80 + (i * 12).toDouble(), height: 12),
            const SizedBox(height: AppSpacing.xs),
            const ShimmerLoading(height: AppSizes.textFieldHeight),
            const SizedBox(height: AppSpacing.md),
          ],
          const SizedBox(height: AppSpacing.sm),
          const ShimmerLoading(height: AppSizes.buttonHeight),
        ],
      ),
    );
  }
}

/// Fixed-size image placeholder — prevents layout shift.
class ImageSkeleton extends StatelessWidget {
  const ImageSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = AppRadius.md,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      width: width,
      height: height,
      borderRadius: borderRadius,
    );
  }
}

/// Inline refresh bar shown over cached content.
class InlineRefreshIndicator extends StatelessWidget {
  const InlineRefreshIndicator({super.key, this.message = 'Updating…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(AppRadius.full),
      color: cs.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              message,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom-of-list pagination loader.
class LoadMoreIndicator extends StatelessWidget {
  const LoadMoreIndicator({
    super.key,
    this.hasMore = true,
    this.isLoading = false,
    this.onRetry,
  });

  final bool hasMore;
  final bool isLoading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (!hasMore) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: Text(
            'You\'re all caught up',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
        ),
      );
    }
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }
    if (onRetry != null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Center(
          child: TextButton(onPressed: onRetry, child: const Text('Load more')),
        ),
      );
    }
    return const SizedBox(height: AppSpacing.lg);
  }
}

/// Stable-size button loading row (spinner + label).
class ButtonLoadingState extends StatelessWidget {
  const ButtonLoadingState({
    super.key,
    required this.label,
    this.color,
  });

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? Theme.of(context).colorScheme.onPrimary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(fg),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: AppTypography.button(context)?.copyWith(color: fg),
        ),
      ],
    );
  }
}

/// Fade-in wrapper for loaded content.
class FadeInContent extends StatefulWidget {
  const FadeInContent({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 220),
  });

  final Widget child;
  final Duration duration;

  @override
  State<FadeInContent> createState() => _FadeInContentState();
}

class _FadeInContentState extends State<FadeInContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}

