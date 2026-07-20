import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/async_load_helper.dart';
import '../../data/models/sale_model.dart';
import '../../data/models/company_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/sale_repository.dart';
import '../../data/repositories/company_repository.dart';
import '../../data/repositories/user_repository.dart';

class SalesState {
  final List<Sale> sales;
  final bool isLoading;
  final bool isRefreshing;
  final String? error;
  final String? selectedStatus;
  final String? selectedCategory;
  /// Passed to `GET /api/sales?search=`
  final String? listSearch;
  /// Passed to `GET /api/sales?companyId=`
  final String? listCompanyId;
  /// Passed to `GET /api/sales?category=`
  final String? listCategory;

  const SalesState({
    this.sales = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
    this.selectedStatus,
    this.selectedCategory,
    this.listSearch,
    this.listCompanyId,
    this.listCategory,
  });

  SalesState copyWith({
    List<Sale>? sales,
    bool? isLoading,
    bool? isRefreshing,
    String? error,
    String? selectedStatus,
    String? selectedCategory,
    String? listSearch,
    String? listCompanyId,
    String? listCategory,
    bool clearStatus = false,
    bool clearCategory = false,
    bool clearListSearch = false,
    bool clearListCompanyId = false,
    bool clearListCategory = false,
  }) {
    return SalesState(
      sales: sales ?? this.sales,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: error,
      selectedStatus: clearStatus
          ? null
          : (selectedStatus ?? this.selectedStatus),
      selectedCategory: clearCategory
          ? null
          : (selectedCategory ?? this.selectedCategory),
      listSearch: clearListSearch ? null : (listSearch ?? this.listSearch),
      listCompanyId:
          clearListCompanyId ? null : (listCompanyId ?? this.listCompanyId),
      listCategory:
          clearListCategory ? null : (listCategory ?? this.listCategory),
    );
  }

  List<Sale> get filteredSales {
    return sales.where((sale) {
      if (selectedStatus != null && sale.status != selectedStatus) {
        return false;
      }
      if (selectedCategory != null && sale.category != selectedCategory) {
        return false;
      }
      return true;
    }).toList();
  }

  List<Sale> get leads => sales.where((s) => s.status == 'lead').toList();
  List<Sale> get prospects =>
      sales.where((s) => s.status == 'prospect').toList();
  List<Sale> get negotiations =>
      sales.where((s) => s.status == 'negotiation').toList();
  List<Sale> get closed => sales
      .where((s) => s.status == 'closed' || s.status == 'closed_won')
      .toList();

  double get totalRevenue => sales
      .where(
        (s) =>
            (s.status == 'closed' || s.status == 'closed_won') &&
            s.expectedRevenue != null,
      )
      .fold(0.0, (sum, s) => sum + s.expectedRevenue!);
}

/// All authenticated users see the full deals list (same as server returns).
final userFilteredSalesProvider = Provider<List<Sale>>((ref) {
  return ref.watch(salesProvider).sales;
});

// Provider to get filtered leads
final userFilteredLeadsProvider = Provider<List<Sale>>((ref) {
  final userSales = ref.watch(userFilteredSalesProvider);
  return userSales.where((s) => s.status == 'lead').toList();
});

// Provider to get filtered prospects
final userFilteredProspectsProvider = Provider<List<Sale>>((ref) {
  final userSales = ref.watch(userFilteredSalesProvider);
  return userSales.where((s) => s.status == 'prospect').toList();
});

// Provider to get filtered closed deals
final userFilteredClosedProvider = Provider<List<Sale>>((ref) {
  final userSales = ref.watch(userFilteredSalesProvider);
  return userSales
      .where((s) => s.status == 'closed' || s.status == 'closed_won')
      .toList();
});

// Provider to get filtered total revenue
final userFilteredTotalRevenueProvider = Provider<double>((ref) {
  final userSales = ref.watch(userFilteredSalesProvider);
  return userSales
      .where(
        (s) =>
            (s.status == 'closed' || s.status == 'closed_won') &&
            s.expectedRevenue != null,
      )
      .fold(0.0, (sum, s) => sum + s.expectedRevenue!);
});

class SalesNotifier extends StateNotifier<SalesState> {
  final SaleRepository _saleRepository;
  final CompanyRepository _companyRepository;
  final UserRepository _userRepository;

  SalesNotifier(
    this._saleRepository,
    this._companyRepository,
    this._userRepository,
  ) : super(const SalesState());

  Future<void> loadSales({bool refresh = false}) async {
    final hadCache = state.sales.isNotEmpty;
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
      final sales = await _saleRepository.getSales(
        search: state.listSearch,
        companyId: state.listCompanyId,
        category: state.listCategory,
      );

      final companyIds = <String>{};
      final userIds = <String>{};

      for (final sale in sales) {
        if (sale.companyId != null) {
          companyIds.add(sale.companyId!);
        }
        if (sale.createdByUserId != null) {
          userIds.add(sale.createdByUserId!);
        }
      }

      final companiesFuture = companyIds.isNotEmpty
          ? _companyRepository.getCompaniesByIds(companyIds.toList())
          : Future.value(<String, Company>{});
      final usersFuture = userIds.isNotEmpty
          ? _userRepository.getUsersByIds(userIds.toList())
          : Future.value(<String, User>{});

      final List<dynamic> results = await Future.wait([
        companiesFuture,
        usersFuture,
      ]);

      final companiesMap = results[0] as Map<String, Company>;
      final usersMap = results[1] as Map<String, User>;

      final salesWithData = sales.map((sale) {
        Company? company;
        User? user;

        if (sale.companyId != null &&
            companiesMap.containsKey(sale.companyId)) {
          company = companiesMap[sale.companyId];
        }

        if (sale.createdByUserId != null &&
            usersMap.containsKey(sale.createdByUserId)) {
          user = usersMap[sale.createdByUserId];
        }

        return sale.copyWith(company: company, createdByUser: user);
      }).toList();

      state = state.copyWith(
        sales: List<Sale>.from(salesWithData),
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

  /// Updates server-side search and reloads (`GET /api/sales?search=`).
  Future<void> setListSearchAndReload(String? search) async {
    final trimmed = search?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      state = state.copyWith(clearListSearch: true);
    } else {
      state = state.copyWith(listSearch: trimmed, clearListSearch: false);
    }
    await loadSales();
  }

  /// Updates company/category API filters and reloads.
  Future<void> setListCompanyCategoryAndReload({
    String? companyId,
    String? category,
  }) async {
    state = state.copyWith(
      listCompanyId: companyId,
      listCategory: category,
      clearListCompanyId: companyId == null || companyId.isEmpty,
      clearListCategory: category == null || category.isEmpty,
    );
    await loadSales();
  }

  Future<void> clearListApiFiltersAndReload() async {
    state = state.copyWith(
      clearListSearch: true,
      clearListCompanyId: true,
      clearListCategory: true,
    );
    await loadSales();
  }

  void setStatusFilter(String? status) {
    if (status == null) {
      state = state.copyWith(clearStatus: true);
    } else {
      state = state.copyWith(selectedStatus: status, clearStatus: false);
    }
  }

  void setCategoryFilter(String? category) {
    if (category == null) {
      state = state.copyWith(clearCategory: true);
    } else {
      state = state.copyWith(selectedCategory: category, clearCategory: false);
    }
  }

  void clearFilters() {
    state = state.copyWith(clearStatus: true, clearCategory: true);
  }

  Future<void> createSale({
    required String companyId,
    required String prospect,
    required DateTime expectedClosingDate,
    String? category,
    double? expectedRevenue,
    String? status,
    String? nextAction,
    DateTime? nextActionDate,
  }) async {
    try {
      final sale = await _saleRepository.createSale(
        companyId: companyId,
        prospect: prospect,
        expectedClosingDate: expectedClosingDate,
        category: category,
        expectedRevenue: expectedRevenue,
        status: status,
        nextAction: nextAction,
        nextActionDate: nextActionDate,
      );

      Company? company;
      try {
        final fetchedCompany =
            await _companyRepository.getCompanyById(companyId);
        if (fetchedCompany != null) {
          company = fetchedCompany;
          List<User> users = [];
          try {
            users = await _userRepository.getUsers();
          } catch (e) {
            // Ignore
          }
          final usersMap = {for (var u in users) u.id: u};
          if (company.kamUserId != null &&
              usersMap.containsKey(company.kamUserId)) {
            company = Company(
              id: company.id,
              name: company.name,
              location: company.location,
              country: company.country,
              kamUserId: company.kamUserId,
              kamUser: usersMap[company.kamUserId],
              createdAt: company.createdAt,
              updatedAt: company.updatedAt,
            );
          }
        }
      } catch (e) {
        // Ignore company fetch error
      }

      User? createdBy;
      if (sale.createdByUserId != null) {
        try {
          createdBy =
              await _userRepository.getUserById(sale.createdByUserId!);
        } catch (e) {
          // Ignore
        }
      }

      final saleWithCompany = sale.copyWith(
        company: company ?? sale.company,
        createdByUser: createdBy ?? sale.createdByUser,
      );

      state = state.copyWith(sales: [saleWithCompany, ...state.sales]);
      await loadSales();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateSale({
    required String id,
    String? companyId,
    String? prospect,
    String? category,
    DateTime? expectedClosingDate,
    double? expectedRevenue,
    String? nextAction,
    DateTime? nextActionDate,
  }) async {
    try {
      final sale = await _saleRepository.updateSale(
        id: id,
        companyId: companyId,
        prospect: prospect,
        category: category,
        expectedClosingDate: expectedClosingDate,
        expectedRevenue: expectedRevenue,
        nextAction: nextAction,
        nextActionDate: nextActionDate,
      );

      final existingSale = state.sales.where((s) => s.id == id).firstOrNull;
      Company? company = existingSale?.company;

      if (companyId != null && companyId != existingSale?.companyId) {
        try {
          final fetchedCompany =
              await _companyRepository.getCompanyById(companyId);
          if (fetchedCompany != null) {
            company = fetchedCompany;
          }
        } catch (e) {
          // Ignore
        }
      }

      final updatedSale = sale.copyWith(
        companyId: companyId ?? sale.companyId,
        company: company ?? sale.company,
        createdByUser: existingSale?.createdByUser ?? sale.createdByUser,
      );

      final updatedSales =
          state.sales.map((s) => s.id == id ? updatedSale : s).toList();
      state = state.copyWith(sales: updatedSales);
      await loadSales();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> changeSaleStatus({
    required String id,
    required String status,
    String? note,
    String? changedByUserId,
  }) async {
    try {
      final sale = await _saleRepository.changeSaleStatus(
        id: id,
        status: status,
        note: note,
        changedByUserId: changedByUserId,
      );

      final existingSale = state.sales.where((s) => s.id == id).firstOrNull;
      final updatedSale = sale.copyWith(
        company: existingSale?.company ?? sale.company,
        createdByUser: existingSale?.createdByUser ?? sale.createdByUser,
      );

      final updatedSales =
          state.sales.map((s) => s.id == id ? updatedSale : s).toList();
      state = state.copyWith(sales: updatedSales);
      await loadSales();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteSale(String id) async {
    try {
      await _saleRepository.deleteSale(id);
      final updatedSales = state.sales.where((s) => s.id != id).toList();
      state = state.copyWith(sales: updatedSales);
      await loadSales();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }
}

final salesProvider = StateNotifierProvider<SalesNotifier, SalesState>((ref) {
  final saleRepository = ref.watch(saleRepositoryProvider);
  final companyRepository = ref.watch(companyRepositoryProvider);
  final userRepository = ref.watch(userRepositoryProvider);
  return SalesNotifier(saleRepository, companyRepository, userRepository);
});

final saleDetailProvider = FutureProvider.family<Sale, String>((ref, id) async {
  final saleRepository = ref.watch(saleRepositoryProvider);
  final companyRepository = ref.watch(companyRepositoryProvider);
  final userRepository = ref.watch(userRepositoryProvider);

  var sale = await saleRepository.getSaleById(id);

  if (sale.companyId != null && sale.company == null) {
    try {
      var fetchedCompany =
          await companyRepository.getCompanyById(sale.companyId!);
      if (fetchedCompany != null) {
        var company = fetchedCompany;
        List<User> users = [];
        try {
          users = await userRepository.getUsers();
        } catch (e) {
          // Ignore
        }
        final usersMap = {for (var u in users) u.id: u};
        if (company.kamUserId != null &&
            usersMap.containsKey(company.kamUserId)) {
          company = Company(
            id: company.id,
            name: company.name,
            location: company.location,
            country: company.country,
            kamUserId: company.kamUserId,
            kamUser: usersMap[company.kamUserId],
            createdAt: company.createdAt,
            updatedAt: company.updatedAt,
          );
        }
        sale = sale.copyWith(company: company);
      }
    } catch (e) {
      // Ignore
    }
  }

  if (sale.createdByUserId != null && sale.createdByUser == null) {
    try {
      final user = await userRepository.getUserById(sale.createdByUserId!);
      sale = sale.copyWith(createdByUser: user);
    } catch (e) {
      // Ignore
    }
  }

  return sale;
});

final saleActivitiesProvider =
    FutureProvider.family<List<SaleActivity>, String>((ref, saleId) async {
  final saleRepository = ref.watch(saleRepositoryProvider);
  return saleRepository.getSaleActivities(saleId);
});

final saleLogsProvider =
    FutureProvider.family<List<SaleLog>, String>((ref, saleId) async {
  final saleRepository = ref.watch(saleRepositoryProvider);
  return saleRepository.getSaleLogs(saleId);
});
