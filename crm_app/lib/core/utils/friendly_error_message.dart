/// Maps raw API / network errors to user-friendly copy.
String friendlyErrorMessage(Object? error, {bool offline = false}) {
  if (offline) {
    return "Couldn't connect to the internet. Check your connection and try again.";
  }

  final raw = error?.toString().trim() ?? '';
  if (raw.isEmpty) {
    return 'Something went wrong. Please try again.';
  }

  final lower = raw.toLowerCase();

  if (lower.contains('socketexception') ||
      lower.contains('network') ||
      lower.contains('connection') ||
      lower.contains('failed host lookup') ||
      lower.contains('no internet')) {
    return "Couldn't connect to the internet. Check your connection and try again.";
  }

  if (lower.contains('timeout') || lower.contains('timed out')) {
    return 'The request took too long. Please try again.';
  }

  if (lower.contains('401') || lower.contains('unauthorized')) {
    return 'Your session may have expired. Please sign in again.';
  }

  if (lower.contains('403') || lower.contains('forbidden')) {
    return "You don't have permission to view this content.";
  }

  if (lower.contains('404') || lower.contains('not found')) {
    return "We couldn't find what you're looking for.";
  }

  if (lower.contains('500') ||
      lower.contains('502') ||
      lower.contains('503') ||
      lower.contains('internal server')) {
    return 'Something went wrong on our end. Please try again.';
  }

  // Already friendly — keep short user-facing messages as-is.
  if (raw.length < 120 && !lower.contains('exception') && !lower.contains('error:')) {
    return raw;
  }

  return 'Something went wrong. Please try again.';
}
