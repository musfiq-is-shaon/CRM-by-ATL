import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/rbac_page_keys.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/company_model.dart';
import '../../providers/expense_provider.dart';
import '../../providers/company_provider.dart';
import '../../providers/rbac_provider.dart'
    show rbacAccessDigestProvider, rbacModuleAdminProvider;
import '../../../core/utils/async_load_helper.dart';
import '../../widgets/app_search_filter_bar.dart';
import '../../widgets/crm_card.dart';
import '../../widgets/searchable_dropdown.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/list_page_state.dart';
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
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

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
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(rbacAccessDigestProvider);
    ref.watch(rbacModuleAdminProvider(RbacPageKey.expenses));
    final expensesState = ref.watch(expensesProvider);

    ref.listen<String?>(
      expensesProvider.select((s) => s.error),
      (previous, next) {
        if (next != null &&
            next != previous &&
            expensesState.expenses.isNotEmpty) {
          showRefreshErrorSnackBar(context, next);
        }
      },
    );

    final bgColor = AppThemeColors.backgroundColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppThemeColors.appBarTitle(
        context,
        'Expenses',
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(108),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppSearchFilterBar(
                controller: _searchController,
                hintText: 'Search expenses...',
                activeFilterCount: expensesState.listFilters.activeCount,
                onChanged: (value) {
                  setState(() {});
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(const Duration(milliseconds: 350), () {
                    ref.read(expensesProvider.notifier).setListSearch(value);
                  });
                },
                onClear: () {
                  _searchDebounce?.cancel();
                  _searchController.clear();
                  ref.read(expensesProvider.notifier).setListSearch(null);
                  setState(() {});
                },
                onFilterTap: () => _showExpenseFilterSheet(context),
              ),
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

  void _showExpenseFilterSheet(BuildContext context) {
    final expensesState = ref.read(expensesProvider);
    final companiesState = ref.read(companiesProvider);
    final purposesAsync = ref.read(expensePurposesProvider);
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final borderColor = AppThemeColors.borderColor(context);
    final f = expensesState.listFilters;

    String? selectedCompanyId = f.companyId;
    String? selectedTripType = f.tripType;
    DateTime? dateFrom = f.dateFrom;
    DateTime? dateTo = f.dateTo;
    String? selectedPurposeId = f.purposeId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.md,
              top: AppSpacing.md,
              bottom: AppSpacing.md + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        ref
                            .read(expensesProvider.notifier)
                            .clearExpenseSearchAndListFilters();
                        _searchController.clear();
                        setState(() {});
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Clear All',
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.md),
                Text(
                  'Company',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                Container(
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: SearchableDropdown<Company>(
                    items: companiesState.companies,
                    value: selectedCompanyId != null
                        ? companiesState.companies
                            .where((c) => c.id == selectedCompanyId)
                            .firstOrNull
                        : null,
                    hintText: 'All companies',
                    labelText: '',
                    dropdownColor: surfaceColor,
                    textColor: textPrimary,
                    hintColor: textSecondary,
                    itemLabelBuilder: (c) => c.name,
                    onChanged: (c) {
                      setModalState(() => selectedCompanyId = c?.id);
                    },
                  ),
                ),
                SizedBox(height: AppSpacing.md),
                Text(
                  'Trip type',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                DropdownButtonFormField<String>(
                  initialValue: selectedTripType,
                  isExpanded: true,
                  decoration: InputDecoration(
                    hintText: 'All types',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                  ),
                  dropdownColor: surfaceColor,
                  items: const [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text('All'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'single_trip',
                      child: Text('Single trip'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'round_trip',
                      child: Text('Round trip'),
                    ),
                  ],
                  onChanged: (v) => setModalState(() => selectedTripType = v),
                ),
                SizedBox(height: AppSpacing.md),
                Text(
                  'Expense date',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: _expenseDateFilterButton(
                        context: context,
                        label: 'From',
                        date: dateFrom,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        borderColor: borderColor,
                        surfaceColor: surfaceColor,
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: dateFrom ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (date != null) {
                            setModalState(() => dateFrom = date);
                          }
                        },
                        onClear: () => setModalState(() => dateFrom = null),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _expenseDateFilterButton(
                        context: context,
                        label: 'To',
                        date: dateTo,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        borderColor: borderColor,
                        surfaceColor: surfaceColor,
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: dateTo ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (date != null) {
                            setModalState(() => dateTo = date);
                          }
                        },
                        onClear: () => setModalState(() => dateTo = null),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.md),
                Text(
                  'Purpose',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                purposesAsync.when(
                  data: (purposes) {
                    final active = purposes.where((p) => p.isActive).toList();
                    return DropdownButtonFormField<String>(
                      initialValue: selectedPurposeId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        hintText: 'All purposes',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                      ),
                      dropdownColor: surfaceColor,
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('All'),
                        ),
                        ...active.map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name),
                          ),
                        ),
                      ],
                      onChanged: (v) =>
                          setModalState(() => selectedPurposeId = v),
                    );
                  },
                  loading: () => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ),
                  error: (e, st) => Text(
                    'Could not load purposes',
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                ),
                SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      ref.read(expensesProvider.notifier).setListFilters(
                            ExpenseListFilters(
                              companyId: selectedCompanyId,
                              tripType: selectedTripType,
                              dateFrom: dateFrom,
                              dateTo: dateTo,
                              purposeId: selectedPurposeId,
                            ),
                          );
                      Navigator.pop(context);
                    },
                    child: const Text('Apply Filters'),
                  ),
                ),
              ],
            ),
          ),
        ),
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
    final expenses = state.visibleForTab(status);

    return AsyncScreenView(
      isLoading: state.isLoading,
      isRefreshing: state.isRefreshing,
      hasCachedData: state.expenses.isNotEmpty,
      error: state.error,
      isEmpty: expenses.isEmpty,
      onRetry: () => ref.read(expensesProvider.notifier).loadExpenses(),
      emptyTitle: 'No expenses found',
      emptySubtitle: status != null
          ? 'No $status expenses match your search or filters'
          : 'Create your first expense or adjust filters',
      emptyIcon: Icons.receipt_long,
      emptyButtonText: 'Add Expense',
      onEmptyAction: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ExpenseFormPage()),
        );
      },
      content: RefreshIndicator(
        onRefresh: () => ref.read(expensesProvider.notifier).loadExpenses(),
        child: expenses.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
                ],
              )
            : FadeInContent(
                child: ListView.builder(
                  padding: AppThemeColors.listPagePadding,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: expenses.length,
                  itemBuilder: (context, index) {
                    final expense = expenses[index];
                    return Padding(
                      padding: AppThemeColors.cardListItemMargin,
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
              ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

Widget _expenseDateFilterButton({
  required BuildContext context,
  required String label,
  required DateTime? date,
  required Color textPrimary,
  required Color textSecondary,
  required Color borderColor,
  required Color surfaceColor,
  required VoidCallback onTap,
  required VoidCallback onClear,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today, size: 18, color: textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              date != null ? '${date.day}/${date.month}/${date.year}' : label,
              style: TextStyle(
                color: date != null ? textPrimary : textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          if (date != null)
            GestureDetector(
              onTap: onClear,
              child: Icon(Icons.close, size: 18, color: textSecondary),
            )
          else
            Icon(Icons.arrow_drop_down, color: textSecondary),
        ],
      ),
    ),
  );
}
