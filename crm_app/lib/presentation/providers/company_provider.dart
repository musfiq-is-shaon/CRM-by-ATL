import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/async_load_helper.dart';
import '../../data/models/company_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/company_repository.dart';
import '../../data/repositories/user_repository.dart';

class CompaniesState {
  final List<Company> companies;
  final bool isLoading;
  final bool isRefreshing;
  final String? error;
  final String? searchQuery;
  final String? countryFilter;
  final String? kamUserIdFilter;

  const CompaniesState({
    this.companies = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
    this.searchQuery,
    this.countryFilter,
    this.kamUserIdFilter,
  });

  CompaniesState copyWith({
    List<Company>? companies,
    bool? isLoading,
    bool? isRefreshing,
    String? error,
    bool clearError = false,
    String? searchQuery,
    bool clearSearchQuery = false,
    String? countryFilter,
    bool clearCountryFilter = false,
    String? kamUserIdFilter,
    bool clearKamUserIdFilter = false,
  }) {
    return CompaniesState(
      companies: companies ?? this.companies,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: clearError ? null : (error ?? this.error),
      searchQuery: clearSearchQuery ? null : (searchQuery ?? this.searchQuery),
      countryFilter:
          clearCountryFilter ? null : (countryFilter ?? this.countryFilter),
      kamUserIdFilter: clearKamUserIdFilter
          ? null
          : (kamUserIdFilter ?? this.kamUserIdFilter),
    );
  }

  List<Company> get filteredCompanies {
    return companies.where((company) {
      // Search query filter
      if (searchQuery != null && searchQuery!.isNotEmpty) {
        final query = searchQuery!.toLowerCase();
        if (!company.name.toLowerCase().contains(query) &&
            !(company.location?.toLowerCase().contains(query) ?? false) &&
            !(company.country?.toLowerCase().contains(query) ?? false)) {
          return false;
        }
      }
      // Country filter
      if (countryFilter != null && countryFilter!.isNotEmpty) {
        if (company.country != countryFilter) {
          return false;
        }
      }
      // KAM filter
      if (kamUserIdFilter != null && kamUserIdFilter!.isNotEmpty) {
        if (company.kamUserId != kamUserIdFilter) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  List<String> get availableCountries {
    final countries = <String>{};
    for (final company in companies) {
      if (company.country != null && company.country!.isNotEmpty) {
        countries.add(company.country!);
      }
    }
    return countries.toList()..sort();
  }
}

class CompaniesNotifier extends StateNotifier<CompaniesState> {
  final CompanyRepository _companyRepository;
  final UserRepository _userRepository;
  int _loadGeneration = 0;
  DateTime? _lastLoadedAt;
  static const _backgroundRefreshAfter = Duration(minutes: 2);

  CompaniesNotifier(this._companyRepository, this._userRepository)
    : super(const CompaniesState());

  /// [refresh] true for pull-to-refresh — shows the inline updating indicator.
  Future<void> loadCompanies({bool refresh = false}) async {
    final hadCache = state.companies.isNotEmpty;

    if (hadCache && !refresh) {
      final last = _lastLoadedAt;
      if (last != null &&
          DateTime.now().difference(last) < _backgroundRefreshAfter) {
        return;
      }
    }

    final generation = ++_loadGeneration;

    if (!hadCache) {
      state = state.copyWith(isLoading: true, isRefreshing: false, error: null);
    } else if (refresh) {
      state = state.copyWith(isRefreshing: true, error: null);
    }
    try {
      final companies = await _companyRepository.getCompanies(
        forceRefresh: refresh || !hadCache,
      );

      if (generation != _loadGeneration) return;

      // Show companies immediately so pickers are usable while KAM users load.
      state = state.copyWith(
        companies: _mergeFetchedCompanies(companies),
        isLoading: false,
        isRefreshing: false,
        clearError: true,
      );
      _lastLoadedAt = DateTime.now();

      // Fetch users to get KAM data
      List<User> users = [];
      try {
        users = await _userRepository.getUsers();
      } catch (e) {
        // Ignore user fetch error — company list is already available.
      }

      if (generation != _loadGeneration) return;

      // Map users by ID for quick lookup
      final usersMap = {for (var u in users) u.id: u};

      // Attach kamUser to companies
      final companiesWithKam = companies.map((company) {
        User? kamUser;
        if (company.kamUserId != null &&
            usersMap.containsKey(company.kamUserId)) {
          kamUser = usersMap[company.kamUserId];
        }
        return Company(
          id: company.id,
          name: company.name,
          location: company.location,
          country: company.country,
          kamUserId: company.kamUserId,
          kamUser: kamUser,
          createdAt: company.createdAt,
          updatedAt: company.updatedAt,
        );
      }).toList();

      state = state.copyWith(
        companies: _mergeFetchedCompanies(companiesWithKam),
        isLoading: false,
        isRefreshing: false,
        clearError: true,
      );
    } catch (e) {
      if (generation != _loadGeneration) return;
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        error: asyncLoadError(e),
      );
    }
  }

  /// Keeps freshly created companies visible if a background [loadCompanies]
  /// finishes before the server list includes them.
  List<Company> _mergeFetchedCompanies(List<Company> fetched) {
    final fetchedIds = fetched.map((c) => c.id).where((id) => id.isNotEmpty).toSet();
    final localOnly = state.companies
        .where((c) => c.id.isNotEmpty && !fetchedIds.contains(c.id))
        .toList();
    if (localOnly.isEmpty) return fetched;
    return [...localOnly, ...fetched];
  }

  void setSearchQuery(String? query) {
    if (query == null || query.isEmpty) {
      state = state.copyWith(clearSearchQuery: true);
    } else {
      state = state.copyWith(searchQuery: query);
    }
  }

  void setCountryFilter(String? country) {
    if (country == null || country.isEmpty) {
      state = state.copyWith(clearCountryFilter: true);
    } else {
      state = state.copyWith(countryFilter: country);
    }
  }

  void setKamUserFilter(String? userId) {
    if (userId == null || userId.isEmpty) {
      state = state.copyWith(clearKamUserIdFilter: true);
    } else {
      state = state.copyWith(kamUserIdFilter: userId);
    }
  }

  void clearFilters() {
    state = state.copyWith(
      clearSearchQuery: true,
      clearCountryFilter: true,
      clearKamUserIdFilter: true,
    );
  }

  Future<Company?> createCompany({
    required String name,
    String? location,
    String? country,
    required String kamUserId,
    required String currencyId,
    String? createdByUserId,
  }) async {
    _loadGeneration++;
    state = state.copyWith(error: null);
    try {
      final company = await _companyRepository.createCompany(
        name: name,
        location: location,
        country: country,
        kamUserId: kamUserId,
        currencyId: currencyId,
        createdByUserId: createdByUserId,
      );
      User? kamUser;
      try {
        kamUser = await _userRepository.getUserById(kamUserId);
      } catch (_) {
        // KAM lookup is optional for display
      }
      final companyWithKam = Company(
        id: company.id,
        name: company.name,
        location: company.location,
        country: company.country,
        kamUserId: company.kamUserId,
        kamUser: kamUser,
        currencyId: company.currencyId,
        currency: company.currency,
        createdAt: company.createdAt,
        updatedAt: company.updatedAt,
      );
      state = state.copyWith(
        companies: [
          companyWithKam,
          ...state.companies.where((c) => c.id != companyWithKam.id),
        ],
        error: null,
      );
      return companyWithKam;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<void> updateCompany({
    required String id,
    String? name,
    String? location,
    String? country,
    String? kamUserId,
  }) async {
    try {
      final company = await _companyRepository.updateCompany(
        id: id,
        name: name,
        location: location,
        country: country,
        kamUserId: kamUserId,
      );
      final updatedCompanies = state.companies
          .map((c) => c.id == id ? company : c)
          .toList();
      state = state.copyWith(companies: updatedCompanies);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteCompany(String id) async {
    try {
      await _companyRepository.deleteCompany(id);
      final updatedCompanies = state.companies
          .where((c) => c.id != id)
          .toList();
      state = state.copyWith(companies: updatedCompanies);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final companiesProvider =
    StateNotifierProvider<CompaniesNotifier, CompaniesState>((ref) {
      final companyRepository = ref.watch(companyRepositoryProvider);
      final userRepository = ref.watch(userRepositoryProvider);
      return CompaniesNotifier(companyRepository, userRepository);
    });

final companyDetailProvider = FutureProvider.family<Company, String>((
  ref,
  id,
) async {
  final companyRepository = ref.watch(companyRepositoryProvider);
  final company = await companyRepository.getCompanyById(id);
  if (company == null) {
    throw Exception('Company not found');
  }
  return company;
});
