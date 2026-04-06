import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/user_repository.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? error;

  const AuthState({this.status = AuthStatus.initial, this.user, this.error});

  AuthState copyWith({AuthStatus? status, User? user, String? error}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  final UserRepository _userRepository;

  AuthNotifier(this._authRepository, this._userRepository)
    : super(const AuthState());

  Future<void> checkAuthStatus() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final isLoggedIn = await _authRepository.isLoggedIn();
      if (isLoggedIn) {
        final user = await _authRepository.getCurrentUser();
        state = AuthState(status: AuthStatus.authenticated, user: user);
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    } catch (e) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final authResponse = await _authRepository.login(
        email: email,
        password: password,
      );
      await _authRepository.persistRememberMe(
        rememberMe: rememberMe,
        email: email,
        password: password,
      );
      state = AuthState(
        status: AuthStatus.authenticated,
        user: authResponse.user,
      );
    } catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Clears [AuthState.error] (e.g. when the user edits credentials after a failed login).
  void clearError() {
    if (state.error == null) return;
    state = state.copyWith(error: null);
  }

  Future<void> logout() async {
    await _authRepository.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> deleteAccount() async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      await _userRepository.deactivateAccount();
      await _authRepository.logout();
      state = const AuthState(status: AuthStatus.unauthenticated);
    } catch (e) {
      state = AuthState(
        status: AuthStatus.authenticated,
        user: state.user,
        error: 'Failed to delete account: ${e.toString()}',
      );
    }
  }

  /// `POST /api/auth/change-password` — Postman: Change password.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(error: null);
    try {
      await _authRepository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
    } catch (e) {
      state = AuthState(
        status: state.status,
        user: state.user,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      rethrow;
    }
  }

  /// `PATCH /api/users/me` — Postman: Update me (profile).
  Future<void> updateProfile({required String name, String phone = ''}) async {
    state = state.copyWith(error: null);
    try {
      final user = await _userRepository.updateMe(name: name, phone: phone);
      await _authRepository.persistUser(user);
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      state = AuthState(
        status: AuthStatus.authenticated,
        user: state.user,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      rethrow;
    }
  }
}

// Helper provider to get current user ID
final currentUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authProvider);
  return authState.user?.id;
});

// Helper provider to check if current user is admin
final isAdminProvider = Provider<bool>((ref) {
  final authState = ref.watch(authProvider);
  return authState.user?.isAdmin ?? false;
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final userRepository = ref.watch(userRepositoryProvider);
  return AuthNotifier(authRepository, userRepository);
});
