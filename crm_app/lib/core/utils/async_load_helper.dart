import 'package:flutter/material.dart';

import 'friendly_error_message.dart';

/// Shared cache-first load flags for Riverpod notifiers.
({bool isLoading, bool isRefreshing}) beginAsyncLoad({
  required bool hasCachedData,
}) {
  return (
    isLoading: !hasCachedData,
    isRefreshing: hasCachedData,
  );
}

/// On failure, always capture the error; UI keeps cached content when available.
String asyncLoadError(Object error) => error.toString();

void showRefreshErrorSnackBar(BuildContext context, Object error) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text(friendlyErrorMessage(error)),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
    ),
  );
}
