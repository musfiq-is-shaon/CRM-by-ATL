import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/expense_model.dart';
import '../../data/models/company_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/expense_repository.dart';
import '../../data/repositories/company_repository.dart';
import '../../data/repositories/user_repository.dart';

class ExpensesState {
  final List<Expense> expenses;
  final bool isLoading;
  final String? error;
  final String? selectedStatus;

  const ExpensesState({
    this.expenses = const [],
    this.isLoading = false,
    this.error,
    this.selectedStatus,
  });

  ExpensesState copyWith({
    List<Expense>? expenses,
    bool? isLoading,
    String? error,
    String? selectedStatus,
    bool clearStatus = false,
  }) {
    return ExpensesState(
      expenses: expenses ?? this.expenses,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedStatus: clearStatus
          ? null
          : (selectedStatus ?? this.selectedStatus),
    );
  }

  List<Expense> get filteredExpenses {
    if (selectedStatus == null) return expenses;
    return expenses.where((e) => e.status == selectedStatus).toList();
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
    state = state.copyWith(isLoading: true, error: null);
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

      state = state.copyWith(expenses: expensesWithData, isLoading: false);
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

  void clearFilters() {
    state = state.copyWith(clearStatus: true);
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
