import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/sale_model.dart';
import '../../data/models/company_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/sale_repository.dart';
import '../../data/repositories/company_repository.dart';
import '../../data/repositories/user_repository.dart';
import 'auth_provider.dart';

class SalesState {
  final List<Sale> sales;
  final bool isLoading;
  final String? error;
  final String? selectedStatus;
  final String? selectedCategory;

  const SalesState({
    this.sales = const [],
    this.isLoading = false,
    this.error,
    this.selectedStatus,
    this.selectedCategory,
  });

  SalesState copyWith({
    List<Sale>? sales,
    bool? isLoading,
    String? error,
    String? selectedStatus,
    String? selectedCategory,
    bool clearStatus = false,
    bool clearCategory = false,
  }) {
    return SalesState(
      sales: sales ?? this.sales,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedStatus: clearStatus
          ? null
          : (selectedStatus ?? this.selectedStatus),
      selectedCategory: clearCategory
          ? null
          : (selectedCategory ?? this.selectedCategory),
    );
  }

  List<Sale> get filteredSales {
    return sales.where((sale) {
      if (selectedStatus != null && sale.status != selectedStatus) return false;
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

// Provider to get filtered sales based on user role (KAM)
final userFilteredSalesProvider = Provider<List<Sale>>((ref) {
  final salesState = ref.watch(salesProvider);
  final currentUserId = ref.watch(currentUserIdProvider);
  final isAdmin = ref.watch(isAdminProvider);

  // Admin sees all sales, regular users see only their KAM deals
  if (isAdmin) {
    return salesState.sales;
  }

  // Filter sales where the user is the KAM of the associated company
  return salesState.sales
      .where((sale) => sale.company?.kamUserId == currentUserId)
      .toList();
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

  Future<void> loadSales() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final sales = await _saleRepository.getSales();

      // Collect all unique company IDs and user IDs needed
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

      // Batch fetch all companies and users in parallel
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

      // Now map sales with pre-fetched data
      final salesWithData = sales.map((sale) {
        Company? company;
        User? user;

        // Get company from map
        if (sale.companyId != null &&
            companiesMap.containsKey(sale.companyId)) {
          company = companiesMap[sale.companyId];
        }

        // Get user from map
        if (sale.createdByUserId != null &&
            usersMap.containsKey(sale.createdByUserId)) {
          user = usersMap[sale.createdByUserId];
        }

        return Sale(
          id: sale.id,
          companyId: sale.companyId,
          company: company,
          prospect: sale.prospect,
          category: sale.category,
          expectedClosingDate: sale.expectedClosingDate,
          expectedRevenue: sale.expectedRevenue,
          status: sale.status,
          createdByUserId: sale.createdByUserId,
          createdByUser: user,
          createdAt: sale.createdAt,
          updatedAt: sale.updatedAt,
        );
      }).toList();

      state = state.copyWith(sales: salesWithData, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
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
    String? createdByUserId,
  }) async {
    try {
      // Get current user if createdByUserId is not provided
      final userId = createdByUserId;

      final sale = await _saleRepository.createSale(
        companyId: companyId,
        prospect: prospect,
        expectedClosingDate: expectedClosingDate,
        category: category,
        expectedRevenue: expectedRevenue,
        status: status,
        createdByUserId: userId,
      );

      // Get the company details with KAM
      Company? company;
      try {
        final fetchedCompany = await _companyRepository.getCompanyById(
          companyId,
        );
        if (fetchedCompany != null) {
          company = fetchedCompany;
          // Fetch users to get KAM
          List<User> users = [];
          try {
            users = await _userRepository.getUsers();
          } catch (e) {
            // Ignore
          }
          final usersMap = {for (var u in users) u.id: u};
          // Attach KAM user to company
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

      final saleWithCompany = Sale(
        id: sale.id,
        companyId: sale.companyId,
        company: company,
        prospect: sale.prospect,
        category: sale.category,
        expectedClosingDate: sale.expectedClosingDate,
        expectedRevenue: sale.expectedRevenue,
        status: sale.status,
        createdByUserId: sale.createdByUserId,
        createdByUser: sale.createdByUser,
        createdAt: sale.createdAt,
        updatedAt: sale.updatedAt,
      );

      state = state.copyWith(sales: [saleWithCompany, ...state.sales]);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateSale({
    required String id,
    String? companyId,
    String? prospect,
    String? category,
    DateTime? expectedClosingDate,
    double? expectedRevenue,
  }) async {
    try {
      final sale = await _saleRepository.updateSale(
        id: id,
        companyId: companyId,
        prospect: prospect,
        category: category,
        expectedClosingDate: expectedClosingDate,
        expectedRevenue: expectedRevenue,
      );

      // Find existing sale to preserve company data
      final existingSale = state.sales.where((s) => s.id == id).firstOrNull;
      Company? company = existingSale?.company;

      // If companyId was changed, fetch new company
      if (companyId != null && companyId != existingSale?.companyId) {
        try {
          final fetchedCompany = await _companyRepository.getCompanyById(
            companyId,
          );
          if (fetchedCompany != null) {
            company = fetchedCompany;
          }
        } catch (e) {
          // Ignore
        }
      }

      final updatedSale = Sale(
        id: sale.id,
        companyId: companyId ?? sale.companyId,
        company: company ?? sale.company,
        prospect: sale.prospect,
        category: sale.category,
        expectedClosingDate: sale.expectedClosingDate,
        expectedRevenue: sale.expectedRevenue,
        status: sale.status,
        createdByUserId: sale.createdByUserId,
        createdByUser: sale.createdByUser,
        createdAt: sale.createdAt,
        updatedAt: sale.updatedAt,
      );

      final updatedSales = state.sales
          .map((s) => s.id == id ? updatedSale : s)
          .toList();
      state = state.copyWith(sales: updatedSales);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> changeSaleStatus({
    required String id,
    required String status,
    String? note,
  }) async {
    try {
      final sale = await _saleRepository.changeSaleStatus(
        id: id,
        status: status,
        note: note,
      );

      // Preserve company data
      final existingSale = state.sales.where((s) => s.id == id).firstOrNull;
      final updatedSale = Sale(
        id: sale.id,
        companyId: sale.companyId,
        company: existingSale?.company,
        prospect: sale.prospect,
        category: sale.category,
        expectedClosingDate: sale.expectedClosingDate,
        expectedRevenue: sale.expectedRevenue,
        status: sale.status,
        createdByUserId: sale.createdByUserId,
        createdByUser: sale.createdByUser,
        createdAt: sale.createdAt,
        updatedAt: sale.updatedAt,
      );

      final updatedSales = state.sales
          .map((s) => s.id == id ? updatedSale : s)
          .toList();
      state = state.copyWith(sales: updatedSales);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteSale(String id) async {
    try {
      await _saleRepository.deleteSale(id);
      final updatedSales = state.sales.where((s) => s.id != id).toList();
      state = state.copyWith(sales: updatedSales);
    } catch (e) {
      state = state.copyWith(error: e.toString());
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

  // Try to get company details with KAM
  if (sale.companyId != null && sale.company == null) {
    try {
      var fetchedCompany = await companyRepository.getCompanyById(
        sale.companyId!,
      );
      if (fetchedCompany != null) {
        var company = fetchedCompany;
        // Fetch users to get KAM
        List<User> users = [];
        try {
          users = await userRepository.getUsers();
        } catch (e) {
          // Ignore
        }
        final usersMap = {for (var u in users) u.id: u};
        // Attach KAM user to company
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
        sale = Sale(
          id: sale.id,
          companyId: sale.companyId,
          company: company,
          prospect: sale.prospect,
          category: sale.category,
          expectedClosingDate: sale.expectedClosingDate,
          expectedRevenue: sale.expectedRevenue,
          status: sale.status,
          createdByUserId: sale.createdByUserId,
          createdByUser: sale.createdByUser,
          createdAt: sale.createdAt,
          updatedAt: sale.updatedAt,
        );
      }
    } catch (e) {
      // Ignore
    }
  }

  // Try to get user details
  if (sale.createdByUserId != null && sale.createdByUser == null) {
    try {
      final user = await userRepository.getUserById(sale.createdByUserId!);
      sale = Sale(
        id: sale.id,
        companyId: sale.companyId,
        company: sale.company,
        prospect: sale.prospect,
        category: sale.category,
        expectedClosingDate: sale.expectedClosingDate,
        expectedRevenue: sale.expectedRevenue,
        status: sale.status,
        createdByUserId: sale.createdByUserId,
        createdByUser: user,
        createdAt: sale.createdAt,
        updatedAt: sale.updatedAt,
      );
    } catch (e) {
      // Ignore
    }
  }

  return sale;
});

// Provider for fetching sale activities
final saleActivitiesProvider =
    FutureProvider.family<List<SaleActivity>, String>((ref, saleId) async {
      final saleRepository = ref.watch(saleRepositoryProvider);
      return saleRepository.getSaleActivities(saleId);
    });
