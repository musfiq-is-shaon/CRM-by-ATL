import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../models/expense_model.dart';

class ExpenseRepository {
  final ApiClient _apiClient;

  ExpenseRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<List<Expense>> getExpenses() async {
    final response = await _apiClient.get(AppConstants.expenses);
    final List<dynamic> data = response.data;
    return data.map((json) => Expense.fromJson(json)).toList();
  }

  Future<Expense> getExpenseById(String id) async {
    final response = await _apiClient.get('${AppConstants.expenses}/$id');
    return Expense.fromJson(response.data);
  }

  Future<Expense> createExpense({
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
    final response = await _apiClient.post(
      AppConstants.expenses,
      data: {
        'companyId': companyId,
        'date': date.toIso8601String().split('T')[0],
        'amount': amount,
        'amountReturn': amountReturn,
        'fromLocation': fromLocation,
        'toLocation': toLocation,
        'purposeId': purposeId,
        'purpose': purpose,
        'tripType': tripType,
        'status': status ?? 'unpaid',
        'createdByUserId': createdByUserId,
      },
    );
    return Expense.fromJson(response.data);
  }

  Future<Expense> updateExpense({
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
    final response = await _apiClient.put(
      '${AppConstants.expenses}/$id',
      data: {
        'companyId': companyId,
        if (date != null) 'date': date.toIso8601String().split('T')[0],
        'amount': amount,
        'amountReturn': amountReturn,
        'fromLocation': fromLocation,
        'toLocation': toLocation,
        'purposeId': purposeId,
        'purpose': purpose,
        'tripType': tripType,
        'status': status,
      },
    );
    return Expense.fromJson(response.data);
  }

  Future<void> deleteExpense(String id) async {
    await _apiClient.delete('${AppConstants.expenses}/$id');
  }

  // Expense Purposes
  Future<List<ExpensePurpose>> getExpensePurposes() async {
    final response = await _apiClient.get(AppConstants.expensePurposes);
    final List<dynamic> data = response.data;
    return data.map((json) => ExpensePurpose.fromJson(json)).toList();
  }

  Future<ExpensePurpose> getExpensePurposeById(String id) async {
    final response = await _apiClient.get(
      '${AppConstants.expensePurposes}/$id',
    );
    return ExpensePurpose.fromJson(response.data);
  }

  Future<ExpensePurpose> createExpensePurpose({
    required String name,
    int? sortOrder,
    bool? isActive,
  }) async {
    final response = await _apiClient.post(
      AppConstants.expensePurposes,
      data: {
        'name': name,
        'sortOrder': sortOrder,
        'isActive': isActive ?? true,
      },
    );
    return ExpensePurpose.fromJson(response.data);
  }

  Future<ExpensePurpose> updateExpensePurpose({
    required String id,
    String? name,
    int? sortOrder,
    bool? isActive,
  }) async {
    final response = await _apiClient.put(
      '${AppConstants.expensePurposes}/$id',
      data: {'name': name, 'sortOrder': sortOrder, 'isActive': isActive},
    );
    return ExpensePurpose.fromJson(response.data);
  }

  Future<void> deleteExpensePurpose(String id) async {
    await _apiClient.delete('${AppConstants.expensePurposes}/$id');
  }
}

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ExpenseRepository(apiClient: apiClient);
});
