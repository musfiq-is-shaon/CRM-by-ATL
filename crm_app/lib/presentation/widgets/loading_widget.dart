import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

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
