/// Standard async screen phases for list/detail/dashboard pages.
enum AsyncScreenStatus {
  initialLoading,
  refreshing,
  loadingMore,
  success,
  empty,
  error,
  offline,
}

/// Helpers for deciding what to show in the UI.
class AsyncScreenFlags {
  const AsyncScreenFlags({
    required this.isLoading,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.hasCachedData = false,
    this.isOffline = false,
    this.error,
    this.isEmpty = false,
  });

  final bool isLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final bool hasCachedData;
  final bool isOffline;
  final String? error;
  final bool isEmpty;

  AsyncScreenStatus get status {
    if (isOffline && !hasCachedData) return AsyncScreenStatus.offline;
    if (isLoading && !hasCachedData) return AsyncScreenStatus.initialLoading;
    if (isRefreshing) return AsyncScreenStatus.refreshing;
    if (isLoadingMore) return AsyncScreenStatus.loadingMore;
    if (error != null && !hasCachedData) return AsyncScreenStatus.error;
    if (isEmpty && !isLoading) return AsyncScreenStatus.empty;
    return AsyncScreenStatus.success;
  }

  bool get showSkeleton => status == AsyncScreenStatus.initialLoading;

  bool get showFullError =>
      error != null && !hasCachedData && !isLoading;

  bool get showEmpty =>
      isEmpty && !isLoading && error == null;

  bool get showInlineRefresh =>
      (isRefreshing || (isLoading && hasCachedData)) && hasCachedData;
}
