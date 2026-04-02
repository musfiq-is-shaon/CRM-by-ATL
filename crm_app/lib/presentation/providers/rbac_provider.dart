import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/rbac_model.dart';
import '../../data/repositories/rbac_repository.dart';

enum RbacLoadStatus { idle, loading, loaded, error }

class RbacState {
  const RbacState({
    this.status = RbacLoadStatus.idle,
    this.me,
    this.errorMessage,
  });

  /// Empty state for comparisons before first RBAC emission.
  static const empty = RbacState();

  final RbacLoadStatus status;
  final RbacMe? me;
  final String? errorMessage;

  RbacState copyWith({
    RbacLoadStatus? status,
    RbacMe? me,
    String? errorMessage,
  }) {
    return RbacState(
      status: status ?? this.status,
      me: me ?? this.me,
      errorMessage: errorMessage,
    );
  }

  bool get isReady =>
      status == RbacLoadStatus.loaded && me != null;
}

class RbacNotifier extends StateNotifier<RbacState> {
  RbacNotifier(this._repository) : super(const RbacState());

  final RbacRepository _repository;
  bool _loadInFlight = false;

  Future<void> load() async {
    if (_loadInFlight) return;
    _loadInFlight = true;
    try {
      state = state.copyWith(status: RbacLoadStatus.loading, errorMessage: null);
      try {
        final me = await _repository.fetchMe();
        state = RbacState(status: RbacLoadStatus.loaded, me: me);
      } catch (e) {
        state = RbacState(
          status: RbacLoadStatus.error,
          me: state.me,
          errorMessage: e.toString(),
        );
      }
    } finally {
      _loadInFlight = false;
    }
  }

  void clear() {
    state = const RbacState();
  }
}

final rbacProvider = StateNotifierProvider<RbacNotifier, RbacState>((ref) {
  return RbacNotifier(ref.watch(rbacRepositoryProvider));
});

/// Convenience: current RBAC payload when loaded.
final rbacMeProvider = Provider<RbacMe?>((ref) {
  return ref.watch(rbacProvider).me;
});
