import 'package:flutter/material.dart';

import 'error_widget.dart' as app_widgets;
import 'loading_widget.dart';

/// Reusable loading/error/empty/content wrapper for list pages.
class ListPageState extends StatelessWidget {
  const ListPageState({
    super.key,
    required this.isLoading,
    this.error,
    required this.isEmpty,
    required this.onRetry,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.emptyIcon,
    required this.content,
  });

  final bool isLoading;
  final String? error;
  final bool isEmpty;
  final VoidCallback onRetry;
  final String emptyTitle;
  final String emptySubtitle;
  final IconData emptyIcon;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const LoadingWidget();
    if (error != null) {
      return app_widgets.ErrorWidget(
        message: error!,
        onRetry: onRetry,
      );
    }
    if (isEmpty) {
      return app_widgets.EmptyStateWidget(
        title: emptyTitle,
        subtitle: emptySubtitle,
        icon: emptyIcon,
      );
    }
    return content;
  }
}
