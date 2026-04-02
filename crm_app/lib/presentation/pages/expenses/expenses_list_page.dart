import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../providers/expense_provider.dart';
import '../../providers/company_provider.dart';
import '../../widgets/crm_card.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/error_widget.dart' as app_widgets;
import 'expense_detail_page.dart';
import 'expense_form_page.dart';

class ExpensesListPage extends ConsumerStatefulWidget {
  const ExpensesListPage({super.key});

  @override
  ConsumerState<ExpensesListPage> createState() => _ExpensesListPageState();
}

class _ExpensesListPageState extends ConsumerState<ExpensesListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(expensesProvider.notifier).loadExpenses();
      ref.read(companiesProvider.notifier).loadCompanies();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expensesState = ref.watch(expensesProvider);

    final bgColor = AppThemeColors.backgroundColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppThemeColors.appBarTitle(
        context,
        'Expenses',
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Divider(
                height: 1,
                thickness: 1,
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.45),
              ),
              TabBar(
                controller: _tabController,
                isScrollable: false,
                padding: AppThemeColors.pagePaddingHorizontal,
                automaticIndicatorColorAdjustment: false,
                labelColor: primaryColor,
                unselectedLabelColor: textSecondary,
                indicatorColor: primaryColor,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Unpaid'),
                  Tab(text: 'Paid'),
                  Tab(text: 'All'),
                ],
                onTap: (index) {
                  final statuses = ['unpaid', 'paid', null];
                  ref
                      .read(expensesProvider.notifier)
                      .setStatusFilter(statuses[index]);
                },
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildExpensesList(expensesState, 'unpaid'),
          _buildExpensesList(expensesState, 'paid'),
          _buildExpensesList(expensesState, null),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ExpenseFormPage()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildExpensesList(ExpensesState state, String? status) {
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final textTertiary = AppThemeColors.textTertiaryColor(context);
    final cs = Theme.of(context).colorScheme;
    final primaryColor = cs.primary;
    final expenseIconTonal = AppThemeColors.tonalForAccent(context, primaryColor);

    if (state.isLoading) {
      return const LoadingWidget();
    }

    if (state.error != null) {
      return app_widgets.ErrorWidget(
        message: state.error!,
        onRetry: () => ref.read(expensesProvider.notifier).loadExpenses(),
      );
    }

    var expenses = state.expenses;

    // Apply status filter
    if (status != null) {
      expenses = expenses.where((e) => e.status == status).toList();
    }

    if (expenses.isEmpty) {
      return app_widgets.EmptyStateWidget(
        title: 'No expenses found',
        subtitle: status != null
            ? 'No $status expenses yet'
            : 'Create your first expense',
        icon: Icons.receipt_long,
        buttonText: 'Add Expense',
        onButtonPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ExpenseFormPage()),
          );
        },
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(expensesProvider.notifier).loadExpenses(),
      child: ListView.builder(
        padding: AppThemeColors.pagePaddingAll,
        itemCount: expenses.length,
        itemBuilder: (context, index) {
          final expense = expenses[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CRMCard(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ExpenseDetailPage(expenseId: expense.id),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: expenseIconTonal.background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.receipt_long,
                          color: expenseIconTonal.foreground,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              expense.company?.name ?? 'No company',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              expense.purposeSummaryLine.isEmpty
                                  ? 'No description'
                                  : expense.purposeSummaryLine,
                              style: TextStyle(
                                fontSize: 14,
                                color: textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            expense.formattedAmount,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          StatusBadge(status: expense.status, type: 'expense'),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (expense.date != null) ...[
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(expense.date!),
                          style: TextStyle(fontSize: 12, color: textTertiary),
                        ),
                      ],
                      if (expense.fromLocation != null &&
                          expense.fromLocation!.isNotEmpty) ...[
                        const SizedBox(width: 16),
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${expense.fromLocation} → ${expense.toLocation ?? ''}',
                            style: TextStyle(fontSize: 12, color: textTertiary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (expense.createdByUser != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 14,
                          color: textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Created by ${expense.createdByUser!.name}',
                          style: TextStyle(fontSize: 12, color: textTertiary),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
