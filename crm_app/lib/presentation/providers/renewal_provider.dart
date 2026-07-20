import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/async_load_helper.dart';
import '../../data/models/company_model.dart';
import '../../data/models/renewal_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/company_repository.dart'
    show CompanyRepository, companyRepositoryProvider;
import '../../data/repositories/renewal_repository.dart';
import '../../data/repositories/user_repository.dart'
    show UserRepository, userRepositoryProvider;

/// Query filters supported by `GET /api/renewals` (see [RenewalRepository.getRenewals]).
class RenewalListFilters {
  const RenewalListFilters({
    this.companyId,
    this.kamUserId,
    this.source,
  });

  final String? companyId;
  final String? kamUserId;
  final String? source;

  static const empty = RenewalListFilters();

  int get activeCount {
    var n = 0;
    if (companyId != null && companyId!.trim().isNotEmpty) n++;
    if (kamUserId != null && kamUserId!.trim().isNotEmpty) n++;
    if (source != null && source!.trim().isNotEmpty) n++;
    return n;
  }
}

class RenewalsState {
  final List<Renewal> renewals;
  final bool isLoading;
  final bool isRefreshing;
  final String? error;
  final String? listSearch;
  final RenewalListFilters listFilters;

  const RenewalsState({
    this.renewals = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
    this.listSearch,
    this.listFilters = RenewalListFilters.empty,
  });

  RenewalsState copyWith({
    List<Renewal>? renewals,
    bool? isLoading,
    bool? isRefreshing,
    String? error,
    String? listSearch,
    bool clearListSearch = false,
    RenewalListFilters? listFilters,
  }) {
    return RenewalsState(
      renewals: renewals ?? this.renewals,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: error,
      listSearch: clearListSearch ? null : (listSearch ?? this.listSearch),
      listFilters: listFilters ?? this.listFilters,
    );
  }
}

class RenewalsNotifier extends StateNotifier<RenewalsState> {
  final RenewalRepository _renewalRepository;
  final CompanyRepository _companyRepository;
  final UserRepository _userRepository;

  RenewalsNotifier(
    this._renewalRepository,
    this._companyRepository,
    this._userRepository,
  ) : super(const RenewalsState());

  Future<void> loadRenewals({bool refresh = false}) async {
    final hadCache = state.renewals.isNotEmpty;
    if (!hadCache) {
      state = state.copyWith(isLoading: true, isRefreshing: false, error: null);
    } else if (refresh) {
      state = state.copyWith(isRefreshing: true, error: null);
    } else {
      final flags = beginAsyncLoad(hasCachedData: true);
      state = state.copyWith(
        isLoading: flags.isLoading,
        isRefreshing: flags.isRefreshing,
        error: null,
      );
    }
    try {
      final search = state.listSearch?.trim();
      final f = state.listFilters;
      final renewals = await _renewalRepository.getRenewals(
        search: search != null && search.isNotEmpty ? search : null,
        companyId: f.companyId?.trim().isNotEmpty == true
            ? f.companyId!.trim()
            : null,
        kamUserId:
            f.kamUserId?.trim().isNotEmpty == true ? f.kamUserId!.trim() : null,
        source: f.source?.trim().isNotEmpty == true ? f.source!.trim() : null,
      );

      final companyIds = <String>{};
      final userIds = <String>{};
      for (final r in renewals) {
        if (r.companyId != null) companyIds.add(r.companyId!);
        if (r.kamUserId != null) userIds.add(r.kamUserId!);
      }

      final companiesFuture = companyIds.isNotEmpty
          ? _companyRepository.getCompaniesByIds(companyIds.toList())
          : Future.value(<String, Company>{});
      final usersFuture = userIds.isNotEmpty
          ? _userRepository.getUsersByIds(userIds.toList())
          : Future.value(<String, User>{});

      final results = await Future.wait([companiesFuture, usersFuture]);
      final companiesMap = results[0] as Map<String, Company>;
      final usersMap = results[1] as Map<String, User>;

      final enriched = renewals.map((r) {
        Company? company;
        if (r.companyId != null && companiesMap.containsKey(r.companyId)) {
          company = companiesMap[r.companyId];
        }
        User? kam = r.kamUser;
        if (kam == null &&
            r.kamUserId != null &&
            usersMap.containsKey(r.kamUserId)) {
          kam = usersMap[r.kamUserId];
        }
        return r.copyWith(company: company, kamUser: kam);
      }).toList();

      state = state.copyWith(
        renewals: List<Renewal>.from(enriched),
        isLoading: false,
        isRefreshing: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        error: asyncLoadError(e),
      );
    }
  }

  Future<void> setListSearchAndReload(String? search) async {
    final trimmed = search?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      state = state.copyWith(clearListSearch: true);
    } else {
      state = state.copyWith(listSearch: trimmed, clearListSearch: false);
    }
    await loadRenewals();
  }

  Future<void> setListFiltersAndReload(RenewalListFilters filters) async {
    state = state.copyWith(listFilters: filters);
    await loadRenewals();
  }

  Future<void> clearListFiltersAndReload() async {
    state = state.copyWith(listFilters: RenewalListFilters.empty);
    await loadRenewals();
  }
}

final renewalsProvider =
    StateNotifierProvider<RenewalsNotifier, RenewalsState>((ref) {
  return RenewalsNotifier(
    ref.watch(renewalRepositoryProvider),
    ref.watch(companyRepositoryProvider),
    ref.watch(userRepositoryProvider),
  );
});
