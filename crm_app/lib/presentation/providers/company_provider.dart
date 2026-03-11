import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/company_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/company_repository.dart';
import '../../data/repositories/user_repository.dart';

class CompaniesState {
  final List<Company> companies;
  final bool isLoading;
  final String? error;
  final String? searchQuery;
  final String? countryFilter;
  final String? kamUserIdFilter;

  const CompaniesState({
    this.companies = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery,
    this.countryFilter,
    this.kamUserIdFilter,
  });

  CompaniesState copyWith({
    List<Company>? companies,
    bool? isLoading,
    String? error,
    String? searchQuery,
    String? countryFilter,
    String? kamUserIdFilter,
  }) {
    return CompaniesState(
      companies: companies ?? this.companies,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      countryFilter: countryFilter,
      kamUserIdFilter: kamUserIdFilter,
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

  CompaniesNotifier(this._companyRepository, this._userRepository)
    : super(const CompaniesState());

  Future<void> loadCompanies() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final companies = await _companyRepository.getCompanies();

      // Fetch users to get KAM data
      List<User> users = [];
      try {
        users = await _userRepository.getUsers();
      } catch (e) {
        // Ignore user fetch error
      }

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

      state = state.copyWith(companies: companiesWithKam, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setSearchQuery(String? query) {
    state = state.copyWith(searchQuery: query);
  }

  void setCountryFilter(String? country) {
    state = state.copyWith(countryFilter: country);
  }

  void setKamUserFilter(String? userId) {
    state = state.copyWith(kamUserIdFilter: userId);
  }

  void clearFilters() {
    state = state.copyWith(
      searchQuery: null,
      countryFilter: null,
      kamUserIdFilter: null,
    );
  }

  Future<void> createCompany({
    required String name,
    String? location,
    String? country,
    required String kamUserId,
    required String currencyId,
  }) async {
    try {
      final company = await _companyRepository.createCompany(
        name: name,
        location: location,
        country: country,
        kamUserId: kamUserId,
        currencyId: currencyId,
      );
      state = state.copyWith(companies: [company, ...state.companies]);
    } catch (e) {
      state = state.copyWith(error: e.toString());
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
