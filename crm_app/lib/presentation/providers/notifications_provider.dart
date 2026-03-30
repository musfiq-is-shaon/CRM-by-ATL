import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/notification_model.dart';
import '../../data/repositories/notification_repository.dart';

class NotificationsState {
  const NotificationsState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  final List<NotificationItem> items;
  final bool isLoading;
  final String? error;

  int get unreadCount => items.where((e) => !e.isRead).length;

  NotificationsState copyWith({
    List<NotificationItem>? items,
    bool? isLoading,
    Object? error = _sentinel,
  }) {
    return NotificationsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }
}

const Object _sentinel = Object();

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  NotificationsNotifier(this._repository) : super(const NotificationsState()) {
    load();
  }

  final NotificationRepository _repository;

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isLoading: true, error: null);
    }
    try {
      final items = await _repository.getMyNotifications();
      state = NotificationsState(items: items, isLoading: false);
    } catch (e) {
      state = NotificationsState(
        items: state.items,
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> markAsRead(String id) async {
    await _repository.markAsRead(id);
    await load(silent: true);
  }

  Future<void> markAllRead() async {
    await _repository.markAllRead();
    await load(silent: true);
  }

  Future<void> deleteOne(String id) async {
    await _repository.deleteNotification(id);
    await load(silent: true);
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  return NotificationsNotifier(ref.watch(notificationRepositoryProvider));
});
