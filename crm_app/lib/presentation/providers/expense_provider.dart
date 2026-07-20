import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/async_load_helper.dart';
import '../../data/models/expense_model.dart';
import '../../data/models/company_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/expense_repository.dart';
import '../../data/repositories/company_repository.dart';
import '../../data/repositories/user_repository.dart';

/// Client-side filters for the expenses list (tabs still apply status first).
class ExpenseListFilters {
  const ExpenseListFilters({
    this.companyId,
    this.tripType,
    this.dateFrom,
    this.dateTo,
    this.purposeId,
  });

  final String? companyId;
  /// `single_trip`, `round_trip`, or null for any.
  final String? tripType;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? purposeId;

  static const empty = ExpenseListFilters();

  int get activeCount {
    var n = 0;
    if (companyId != null && companyId!.trim().isNotEmpty) n++;
    if (tripType != null && tripType!.trim().isNotEmpty) n++;
    if (dateFrom != null) n++;
    if (dateTo != null) n++;
    if (purposeId != null && purposeId!.trim().isNotEmpty) n++;
    return n;
  }
}

class ExpensesState {
  final List<Expense> expenses;
  final bool isLoading;
  final bool isRefreshing;
  final String? error;
  final String? selectedStatus;
  final String? listSearch;
  final ExpenseListFilters listFilters;

  const ExpensesState({
    this.expenses = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
    this.selectedStatus,
    this.listSearch,
    this.listFilters = ExpenseListFilters.empty,
  });

  ExpensesState copyWith({
    List<Expense>? expenses,
    bool? isLoading,
    bool? isRefreshing,
    String? error,
    String? selectedStatus,
    bool clearStatus = false,
    String? listSearch,
    bool clearListSearch = false,
    ExpenseListFilters? listFilters,
  }) {
    return ExpensesState(
      expenses: expenses ?? this.expenses,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: error,
      selectedStatus: clearStatus
          ? null
          : (selectedStatus ?? this.selectedStatus),
      listSearch: clearListSearch ? null : (listSearch ?? this.listSearch),
      listFilters: listFilters ?? this.listFilters,
    );
  }

  List<Expense> get filteredExpenses {
    if (selectedStatus == null) return expenses;
    return expenses.where((e) => e.status == selectedStatus).toList();
  }

  /// Tab status: `'unpaid'`, `'paid'`, or `null` for all.
  List<Expense> visibleForTab(String? tabStatus) {
    Iterable<Expense> rows = expenses;
    if (tabStatus != null) {
      rows = rows.where((e) => e.status == tabStatus);
    }

    final q = listSearch?.trim().toLowerCase();
    if (q != null && q.isNotEmpty) {
      rows = rows.where((e) {
        final company = (e.company?.name ?? '').toLowerCase();
        final purpose = (e.purposeSummaryLine).toLowerCase();
        final from = (e.fromLocation ?? '').toLowerCase();
        final to = (e.toLocation ?? '').toLowerCase();
        final creator = (e.createdByUser?.name ?? '').toLowerCase();
        return company.contains(q) ||
            purpose.contains(q) ||
            from.contains(q) ||
            to.contains(q) ||
            creator.contains(q);
      });
    }

    final f = listFilters;
    if (f.companyId != null && f.companyId!.trim().isNotEmpty) {
      final id = f.companyId!.trim();
      rows = rows.where((e) => e.companyId == id);
    }
    if (f.tripType != null && f.tripType!.trim().isNotEmpty) {
      final t = f.tripType!.trim();
      rows = rows.where((e) => e.tripType == t);
    }
    if (f.purposeId != null && f.purposeId!.trim().isNotEmpty) {
      final id = f.purposeId!.trim();
      rows = rows.where((e) => e.purposeId == id);
    }
    if (f.dateFrom != null || f.dateTo != null) {
      rows = rows.where((e) {
        final d = e.date;
        if (d == null) return false;
        final day = DateTime(d.year, d.month, d.day);
        if (f.dateFrom != null) {
          final from = DateTime(
            f.dateFrom!.year,
            f.dateFrom!.month,
            f.dateFrom!.day,
          );
          if (day.isBefore(from)) return false;
        }
        if (f.dateTo != null) {
          final to = DateTime(
            f.dateTo!.year,
            f.dateTo!.month,
            f.dateTo!.day,
          );
          if (day.isAfter(to)) return false;
        }
        return true;
      });
    }

    return rows.toList();
  }

  List<Expense> get unpaidExpenses =>
      expenses.where((e) => e.status == 'unpaid').toList();

  List<Expense> get paidExpenses =>
      expenses.where((e) => e.status == 'paid').toList();

  double get totalUnpaid =>
      unpaidExpenses.fold(0.0, (sum, e) => sum + e.amount);

  double get totalPaid => paidExpenses.fold(0.0, (sum, e) => sum + e.amount);

  double get totalAmount => expenses.fold(0.0, (sum, e) => sum + e.amount);
}

class ExpensesNotifier extends StateNotifier<ExpensesState> {
  final ExpenseRepository _expenseRepository;
  final CompanyRepository _companyRepository;
  final UserRepository _userRepository;

  ExpensesNotifier(
    this._expenseRepository,
    this._companyRepository,
    this._userRepository,
  ) : super(const ExpensesState());

  Future<void> loadExpenses() async {
    final flags = beginAsyncLoad(hasCachedData: state.expenses.isNotEmpty);
    state = state.copyWith(
      isLoading: flags.isLoading,
      isRefreshing: flags.isRefreshing,
      error: null,
    );
    try {
      final expenses = await _expenseRepository.getExpenses();

      // Load company and user data for each expense
      final expensesWithData = await Future.wait(
        expenses.map((expense) async {
          Company? company;
          User? createdByUser;

          // Get company details
          if (expense.company != null) {
            company = expense.company;
          } else if (expense.companyId != null) {
            try {
              company = await _companyRepository.getCompanyById(
                expense.companyId!,
              );
            } catch (e) {
              // Ignore
            }
          }

          // Get user details (created by)
          if (expense.createdByUser != null) {
            createdByUser = expense.createdByUser;
          } else if (expense.createdByUserId != null) {
            try {
              createdByUser = await _userRepository.getUserById(
                expense.createdByUserId!,
              );
            } catch (e) {
              // Ignore
            }
          }

          return Expense(
            id: expense.id,
            companyId: expense.companyId,
            company: company,
            date: expense.date,
            amount: expense.amount,
            amountReturn: expense.amountReturn,
            fromLocation: expense.fromLocation,
            toLocation: expense.toLocation,
            purposeId: expense.purposeId,
            purposeName: expense.purposeName,
            purpose: expense.purpose,
            tripType: expense.tripType,
            status: expense.status,
            createdByUserId: expense.createdByUserId,
            createdByUser: createdByUser,
            createdAt: expense.createdAt,
            updatedAt: expense.updatedAt,
          );
        }),
      );

      state = state.copyWith(
        expenses: expensesWithData,
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

  void setStatusFilter(String? status) {
    if (status == null) {
      state = state.copyWith(clearStatus: true);
    } else {
      state = state.copyWith(selectedStatus: status, clearStatus: false);
    }
  }

  void setListSearch(String? search) {
    final trimmed = search?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      state = state.copyWith(clearListSearch: true);
    } else {
      state = state.copyWith(listSearch: trimmed, clearListSearch: false);
    }
  }

  void setListFilters(ExpenseListFilters filters) {
    state = state.copyWith(listFilters: filters);
  }

  void clearFilters() {
    state = state.copyWith(clearStatus: true);
  }

  /// Clears search + list filters (tabs / [selectedStatus] unchanged).
  void clearExpenseSearchAndListFilters() {
    state = state.copyWith(
      clearListSearch: true,
      listFilters: ExpenseListFilters.empty,
    );
  }

  Future<void> createExpense({
    required String companyId,
    required DateTime date,
    required double amount,
    double? amountReturn,
    String? fromLocation,
    String? toLocation,
    String? purposeId,
    String? purpose,
    String? tripType,
    String? status,
    String? createdByUserId,
  }) async {
    try {
      final expense = await _expenseRepository.createExpense(
        companyId: companyId,
        date: date,
        amount: amount,
        amountReturn: amountReturn,
        fromLocation: fromLocation,
        toLocation: toLocation,
        purposeId: purposeId,
        purpose: purpose,
        tripType: tripType,
        status: status,
        createdByUserId: createdByUserId,
      );

      // Get company details
      Company? company;
      try {
        company = await _companyRepository.getCompanyById(companyId);
      } catch (e) {
        // Ignore
      }

      // Get user details
      User? createdByUser;
      if (expense.createdByUserId != null) {
        try {
          createdByUser = await _userRepository.getUserById(
            expense.createdByUserId!,
          );
        } catch (e) {
          // Ignore
        }
      }

      final expenseWithCompany = Expense(
        id: expense.id,
        companyId: expense.companyId,
        company: company,
        date: expense.date,
        amount: expense.amount,
        amountReturn: expense.amountReturn,
        fromLocation: expense.fromLocation,
        toLocation: expense.toLocation,
        purposeId: expense.purposeId,
        purposeName: expense.purposeName,
        purpose: expense.purpose,
        tripType: expense.tripType,
        status: expense.status,
        createdByUserId: expense.createdByUserId,
        createdByUser: createdByUser,
        createdAt: expense.createdAt,
        updatedAt: expense.updatedAt,
      );

      state = state.copyWith(expenses: [expenseWithCompany, ...state.expenses]);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateExpense({
    required String id,
    String? companyId,
    DateTime? date,
    double? amount,
    double? amountReturn,
    String? fromLocation,
    String? toLocation,
    String? purposeId,
    String? purpose,
    String? tripType,
    String? status,
  }) async {
    try {
      final expense = await _expenseRepository.updateExpense(
        id: id,
        companyId: companyId,
        date: date,
        amount: amount,
        amountReturn: amountReturn,
        fromLocation: fromLocation,
        toLocation: toLocation,
        purposeId: purposeId,
        purpose: purpose,
        tripType: tripType,
        status: status,
      );

      // Find existing expense to preserve company and user data
      final existingExpense = state.expenses
          .where((e) => e.id == id)
          .firstOrNull;
      Company? company = existingExpense?.company;
      User? createdByUser = existingExpense?.createdByUser;

      // If companyId was changed, fetch new company
      if (companyId != null && companyId != existingExpense?.companyId) {
        try {
          company = await _companyRepository.getCompanyById(companyId);
        } catch (e) {
          // Ignore
        }
      }

      final updatedExpense = Expense(
        id: expense.id,
        companyId: companyId ?? expense.companyId,
        company: company ?? expense.company,
        date: expense.date,
        amount: expense.amount,
        amountReturn: expense.amountReturn,
        fromLocation: expense.fromLocation,
        toLocation: expense.toLocation,
        purposeId: expense.purposeId,
        purposeName: expense.purposeName,
        purpose: expense.purpose,
        tripType: expense.tripType,
        status: expense.status,
        createdByUserId: expense.createdByUserId,
        createdByUser: createdByUser ?? expense.createdByUser,
        createdAt: expense.createdAt,
        updatedAt: expense.updatedAt,
      );

      final updatedExpenses = state.expenses
          .map((e) => e.id == id ? updatedExpense : e)
          .toList();
      state = state.copyWith(expenses: updatedExpenses);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteExpense(String id) async {
    try {
      await _expenseRepository.deleteExpense(id);
      final updatedExpenses = state.expenses.where((e) => e.id != id).toList();
      state = state.copyWith(expenses: updatedExpenses);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final expensesProvider = StateNotifierProvider<ExpensesNotifier, ExpensesState>(
  (ref) {
    final expenseRepository = ref.watch(expenseRepositoryProvider);
    final companyRepository = ref.watch(companyRepositoryProvider);
    final userRepository = ref.watch(userRepositoryProvider);
    return ExpensesNotifier(
      expenseRepository,
      companyRepository,
      userRepository,
    );
  },
);

final expenseDetailProvider = FutureProvider.family<Expense, String>((
  ref,
  id,
) async {
  final expenseRepository = ref.watch(expenseRepositoryProvider);
  final companyRepository = ref.watch(companyRepositoryProvider);
  final userRepository = ref.watch(userRepositoryProvider);

  var expense = await expenseRepository.getExpenseById(id);

  // Try to get company details
  if (expense.companyId != null && expense.company == null) {
    try {
      final company = await companyRepository.getCompanyById(
        expense.companyId!,
      );
      expense = Expense(
        id: expense.id,
        companyId: expense.companyId,
        company: company,
        date: expense.date,
        amount: expense.amount,
        amountReturn: expense.amountReturn,
        fromLocation: expense.fromLocation,
        toLocation: expense.toLocation,
        purposeId: expense.purposeId,
        purposeName: expense.purposeName,
        purpose: expense.purpose,
        tripType: expense.tripType,
        status: expense.status,
        createdByUserId: expense.createdByUserId,
        createdByUser: expense.createdByUser,
        createdAt: expense.createdAt,
        updatedAt: expense.updatedAt,
      );
    } catch (e) {
      // Ignore
    }
  }

  // Try to get user details (created by)
  if (expense.createdByUserId != null && expense.createdByUser == null) {
    try {
      final user = await userRepository.getUserById(expense.createdByUserId!);
      expense = Expense(
        id: expense.id,
        companyId: expense.companyId,
        company: expense.company,
        date: expense.date,
        amount: expense.amount,
        amountReturn: expense.amountReturn,
        fromLocation: expense.fromLocation,
        toLocation: expense.toLocation,
        purposeId: expense.purposeId,
        purposeName: expense.purposeName,
        purpose: expense.purpose,
        tripType: expense.tripType,
        status: expense.status,
        createdByUserId: expense.createdByUserId,
        createdByUser: user,
        createdAt: expense.createdAt,
        updatedAt: expense.updatedAt,
      );
    } catch (e) {
      // Ignore
    }
  }

  return expense;
});

// Provider for expense purposes
final expensePurposesProvider = FutureProvider<List<ExpensePurpose>>((
  ref,
) async {
  final expenseRepository = ref.watch(expenseRepositoryProvider);
  return expenseRepository.getExpensePurposes();
});
