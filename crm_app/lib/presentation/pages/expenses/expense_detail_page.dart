import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../providers/expense_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/error_widget.dart' as app_widgets;
import 'expense_form_page.dart';

class ExpenseDetailPage extends ConsumerWidget {
  final String expenseId;

  const ExpenseDetailPage({super.key, required this.expenseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    final expenseAsync = ref.watch(expenseDetailProvider(expenseId));

    final bgColor = AppThemeColors.backgroundColor(context);
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final textTertiary = AppThemeColors.textTertiaryColor(context);
    final borderColor = AppThemeColors.borderColor(context);
    final cs = Theme.of(context).colorScheme;
    final primaryColor = cs.primary;
    final errorColor = cs.error;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppThemeColors.appBarTitle(
        context,
        'Expense Details',
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: 'Edit expense',
              icon: const Icon(Icons.edit),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ExpenseFormPage(expenseId: expenseId),
                  ),
                );
              },
            ),
          IconButton(
            tooltip: 'Delete expense',
            icon: Icon(Icons.delete, color: errorColor),
            onPressed: () => _showDeleteDialog(context, ref),
          ),
        ],
      ),
      body: expenseAsync.when(
        data: (expense) => SingleChildScrollView(
          padding: AppThemeColors.pagePaddingAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                width: double.infinity,
                padding: AppThemeColors.pagePaddingAll,
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.receipt_long,
                        color: primaryColor,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      expense.company?.name ?? 'No company',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      expense.formattedAmount,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    StatusBadge(status: expense.status, type: 'expense'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Details Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Details',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Date',
                      value: expense.date != null
                          ? '${expense.date!.day}/${expense.date!.month}/${expense.date!.year}'
                          : 'Not set',
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      textTertiary: textTertiary,
                    ),
                    _buildDivider(borderColor),
                    _buildDetailRow(
                      icon: Icons.location_on_outlined,
                      label: 'From',
                      value: expense.fromLocation ?? 'Not set',
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      textTertiary: textTertiary,
                    ),
                    _buildDivider(borderColor),
                    _buildDetailRow(
                      icon: Icons.location_on,
                      label: 'To',
                      value: expense.toLocation ?? 'Not set',
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      textTertiary: textTertiary,
                    ),
                    _buildDivider(borderColor),
                    _buildDetailRow(
                      icon: Icons.directions_car_outlined,
                      label: 'Trip Type',
                      value: expense.tripType != null
                          ? expense.tripType!.replaceAll('_', ' ').toUpperCase()
                          : 'Not set',
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      textTertiary: textTertiary,
                    ),
                    if (expense.tripType == 'round_trip' &&
                        expense.amountReturn != null) ...[
                      _buildDivider(borderColor),
                      _buildDetailRow(
                        icon: Icons.money_outlined,
                        label: 'Return Amount',
                        value: '\$${expense.amountReturn!.toStringAsFixed(2)}',
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        textTertiary: textTertiary,
                      ),
                    ],
                    if (expense.amountReturn != null) ...[
                      _buildDivider(borderColor),
                      _buildDetailRow(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Total Amount',
                        value: expense.formattedTotalAmount,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        textTertiary: textTertiary,
                        isHighlighted: true,
                        highlightColor: primaryColor,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Purpose Card
              if (expense.purpose != null && expense.purpose!.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Purpose',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        expense.purpose!,
                        style: TextStyle(fontSize: 14, color: textSecondary),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Created Info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Created Info',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (expense.createdByUser != null)
                      Text(
                        'By: ${expense.createdByUser!.name}',
                        style: TextStyle(fontSize: 14, color: textSecondary),
                      ),
                    if (expense.createdAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'On: ${expense.createdAt!.day}/${expense.createdAt!.month}/${expense.createdAt!.year}',
                        style: TextStyle(fontSize: 14, color: textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        loading: () => const LoadingWidget(),
        error: (error, _) => app_widgets.ErrorWidget(
          message: error.toString(),
          onRetry: () => ref.refresh(expenseDetailProvider(expenseId)),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color textPrimary,
    required Color textSecondary,
    required Color textTertiary,
    bool isHighlighted = false,
    Color? highlightColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: textTertiary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: textSecondary),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
              color: isHighlighted ? highlightColor : textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(Color borderColor) {
    return Divider(color: borderColor, height: 1);
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Expense', style: TextStyle(color: textPrimary)),
        content: Text(
          'Are you sure you want to delete this expense? This action cannot be undone.',
          style: TextStyle(color: textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await ref
                  .read(expensesProvider.notifier)
                  .deleteExpense(expenseId);
              if (context.mounted) {
                Navigator.pop(context); // Go back to list
              }
            },
            child: Text('Delete', style: TextStyle(color: cs.error)),
          ),
        ],
      ),
    );
  }
}
