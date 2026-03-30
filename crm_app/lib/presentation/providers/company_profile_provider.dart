import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/company_profile_model.dart';
import '../../data/repositories/company_profile_repository.dart';

class CompanyProfileState {
  final CompanyProfile? profile;
  final bool isLoading;
  final String? error;

  const CompanyProfileState({
    this.profile,
    this.isLoading = false,
    this.error,
  });

  CompanyProfileState copyWith({
    CompanyProfile? profile,
    bool? isLoading,
    Object? error = _sentinel,
  }) {
    return CompanyProfileState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }
}

const Object _sentinel = Object();

class CompanyProfileNotifier extends StateNotifier<CompanyProfileState> {
  CompanyProfileNotifier(this._repository) : super(const CompanyProfileState());

  final CompanyProfileRepository _repository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final profile = await _repository.getCompanyProfile();
      state = CompanyProfileState(profile: profile, isLoading: false);
    } catch (e) {
      state = CompanyProfileState(
        profile: state.profile,
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> update(CompanyProfile profile) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final saved = await _repository.updateCompanyProfile(profile);
      state = CompanyProfileState(profile: saved, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      rethrow;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final companyProfileProvider =
    StateNotifierProvider<CompanyProfileNotifier, CompanyProfileState>((ref) {
  return CompanyProfileNotifier(ref.watch(companyProfileRepositoryProvider));
});
