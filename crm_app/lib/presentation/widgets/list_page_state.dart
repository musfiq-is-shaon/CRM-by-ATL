import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/utils/async_screen_status.dart';
import '../../core/utils/friendly_error_message.dart';
import '../providers/connectivity_provider.dart';
import 'error_widget.dart' as app_widgets;
import 'loading_widget.dart';
import 'offline_banner.dart';

/// Reusable loading/error/empty/content wrapper for list pages.
class ListPageState extends StatelessWidget {
  const ListPageState({
    super.key,
    required this.isLoading,
    this.isRefreshing = false,
    this.hasCachedData = false,
    this.error,
    required this.isEmpty,
    required this.onRetry,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.emptyIcon,
    required this.content,
    this.useSkeleton = true,
    this.skeletonCount = 6,
    this.loadingMessage,
    this.emptyButtonText,
    this.onEmptyAction,
    this.skeleton,
    this.refreshMessage = 'Updating…',
  });

  final bool isLoading;
  final bool isRefreshing;
  final bool hasCachedData;
  final String? error;
  final bool isEmpty;
  final VoidCallback onRetry;
  final String emptyTitle;
  final String emptySubtitle;
  final IconData emptyIcon;
  final Widget content;
  final bool useSkeleton;
  final int skeletonCount;
  final String? loadingMessage;
  final String? emptyButtonText;
  final VoidCallback? onEmptyAction;
  final Widget? skeleton;
  final String refreshMessage;

  AsyncScreenFlags get _flags => AsyncScreenFlags(
        isLoading: isLoading,
        isRefreshing: isRefreshing || (isLoading && hasCachedData),
        hasCachedData: hasCachedData,
        error: error,
        isEmpty: isEmpty,
      );

  @override
  Widget build(BuildContext context) {
    final flags = _flags;

    if (flags.showSkeleton) {
      if (skeleton != null) return skeleton!;
      if (useSkeleton) {
        return ListSkeletonLoader(itemCount: skeletonCount);
      }
      return LoadingWidget(message: loadingMessage);
    }

    if (flags.showFullError) {
      return app_widgets.ErrorState(
        message: friendlyErrorMessage(error),
        onRetry: onRetry,
      );
    }

    if (flags.showEmpty) {
      return app_widgets.EmptyStateWidget(
        title: emptyTitle,
        subtitle: emptySubtitle,
        icon: emptyIcon,
        buttonText: emptyButtonText,
        onButtonPressed: onEmptyAction,
      );
    }

    if (flags.showInlineRefresh) {
      return Stack(
        alignment: Alignment.topCenter,
        children: [
          content,
          Positioned(
            top: AppSpacing.sm,
            child: InlineRefreshIndicator(message: refreshMessage),
          ),
        ],
      );
    }

    return content;
  }
}

/// Async screen with optional offline detection via Riverpod.
class AsyncScreenView extends ConsumerWidget {
  const AsyncScreenView({
    super.key,
    required this.isLoading,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.hasCachedData = false,
    this.error,
    required this.isEmpty,
    required this.onRetry,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.emptyIcon,
    required this.content,
    this.useSkeleton = true,
    this.skeletonCount = 6,
    this.skeleton,
    this.emptyButtonText,
    this.onEmptyAction,
    this.bottom,
  });

  final bool isLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final bool hasCachedData;
  final String? error;
  final bool isEmpty;
  final VoidCallback onRetry;
  final String emptyTitle;
  final String emptySubtitle;
  final IconData emptyIcon;
  final Widget content;
  final bool useSkeleton;
  final int skeletonCount;
  final Widget? skeleton;
  final String? emptyButtonText;
  final VoidCallback? onEmptyAction;
  final Widget? bottom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(connectivityProvider);
    final cached = hasCachedData;

    if (!online && !cached && !isLoading) {
      return OfflineState(onRetry: onRetry);
    }

    final body = ListPageState(
      isLoading: isLoading,
      isRefreshing: isRefreshing,
      hasCachedData: cached,
      error: online ? error : null,
      isEmpty: isEmpty,
      onRetry: onRetry,
      emptyTitle: emptyTitle,
      emptySubtitle: emptySubtitle,
      emptyIcon: emptyIcon,
      content: content,
      useSkeleton: useSkeleton,
      skeletonCount: skeletonCount,
      skeleton: skeleton,
      emptyButtonText: emptyButtonText,
      onEmptyAction: onEmptyAction,
    );

    if (bottom == null && !isLoadingMore) return body;

    return Column(
      children: [
        Expanded(child: body),
        if (isLoadingMore) const LoadMoreIndicator(isLoading: true),
        ?bottom,
      ],
    );
  }
}
