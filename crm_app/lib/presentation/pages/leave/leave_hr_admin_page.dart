import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../core/utils/async_load_helper.dart';
import '../../../data/models/leave_model.dart';
import '../../providers/leave_hr_admin_provider.dart';
import '../../widgets/list_page_state.dart';
import '../../widgets/loading_widget.dart';

class LeaveHrAdminPage extends ConsumerStatefulWidget {
  const LeaveHrAdminPage({super.key});

  @override
  ConsumerState<LeaveHrAdminPage> createState() => _LeaveHrAdminPageState();
}

class _LeaveHrAdminPageState extends ConsumerState<LeaveHrAdminPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(_onTab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(leaveHrAdminProvider.notifier).loadTypes();
    });
  }

  void _onTab() {
    if (_tab.indexIsChanging) return;
    final n = ref.read(leaveHrAdminProvider.notifier);
    switch (_tab.index) {
      case 0:
        n.loadTypes();
        break;
      case 1:
        n.loadWeekends();
        break;
      case 2:
        n.loadHolidays();
        break;
    }
  }

  @override
  void dispose() {
    _tab.removeListener(_onTab);
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppThemeColors.backgroundColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
            final textSecondary = AppThemeColors.textSecondaryColor(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    ref.listen<LeaveHrAdminState>(leaveHrAdminProvider, (prev, next) {
      if (next.error != null &&
          prev?.error != next.error &&
          context.mounted) {
        final hasCached = next.types.isNotEmpty ||
            next.weekends.isNotEmpty ||
            next.holidays.isNotEmpty;
        if (hasCached) {
          showRefreshErrorSnackBar(context, next.error!);
        }
        ref.read(leaveHrAdminProvider.notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: bg,
      appBar: AppThemeColors.appBarTitle(
        context,
        'Leave HR (admin)',
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
                controller: _tab,
                labelColor: primaryColor,
                unselectedLabelColor: textSecondary,
                indicatorColor: primaryColor,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Types'),
                  Tab(text: 'Weekends'),
                  Tab(text: 'Holidays'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _TypesTab(textPrimary: textPrimary),
          _WeekendsTab(textPrimary: textPrimary),
          _HolidaysTab(textPrimary: textPrimary),
        ],
      ),
    );
  }
}

class _TypesTab extends ConsumerWidget {
  const _TypesTab({required this.textPrimary});

  final Color textPrimary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(leaveHrAdminProvider);
    final n = ref.read(leaveHrAdminProvider.notifier);

    return ListPageState(
      isLoading: s.loadingTypes,
      isRefreshing: s.refreshingTypes,
      hasCachedData: s.types.isNotEmpty,
      error: s.error,
      isEmpty: s.types.isEmpty,
      onRetry: () => n.loadTypes(),
      emptyTitle: 'No leave types',
      emptySubtitle: 'Add your first leave type to get started',
      emptyIcon: Icons.category_outlined,
      emptyButtonText: 'Add type',
      onEmptyAction: () => _addType(context, ref),
      content: RefreshIndicator(
        onRefresh: () => n.loadTypes(refresh: true),
        child: FadeInContent(
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppThemeColors.pagePaddingAll,
            itemCount: s.types.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () => _addType(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('Add type'),
                    ),
                  ),
                );
              }
              final t = s.types[i - 1];
              final inactive = t.isActive == false;
              final cs = Theme.of(context).colorScheme;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppThemeColors.cardColor(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppThemeColors.borderColor(context)),
                ),
                child: ListTile(
                  title: Text(t.name, style: TextStyle(color: textPrimary)),
                  subtitle: Text(
                    inactive ? 'Inactive' : 'Active',
                    style: TextStyle(
                      color: inactive ? cs.secondary : cs.tertiary,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Toggle active',
                        icon: const Icon(Icons.toggle_on_outlined),
                        onPressed: () async {
                          await n.updateLeaveType(
                            t.id,
                            isActive: inactive ? true : false,
                          );
                        },
                      ),
                      IconButton(
                        tooltip: 'Rename',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _renameType(context, ref, t),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        icon: Icon(Icons.delete_outline, color: cs.error),
                        onPressed: () => _confirmDeleteType(context, ref, t),
                      ),
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

  Future<void> _addType(BuildContext context, WidgetRef ref) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New leave type'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(labelText: 'Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      ),
    );
    if (ok == true && c.text.trim().isNotEmpty && context.mounted) {
      try {
        await ref.read(leaveHrAdminProvider.notifier).createLeaveType(c.text);
      } catch (_) {}
    }
    c.dispose();
  }

  Future<void> _renameType(
    BuildContext context,
    WidgetRef ref,
    LeaveTypeOption t,
  ) async {
    final c = TextEditingController(text: t.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename leave type'),
        content: TextField(controller: c, decoration: const InputDecoration(labelText: 'Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true && c.text.trim().isNotEmpty && context.mounted) {
      await ref.read(leaveHrAdminProvider.notifier).updateLeaveType(t.id, name: c.text);
    }
    c.dispose();
  }

  Future<void> _confirmDeleteType(
    BuildContext context,
    WidgetRef ref,
    LeaveTypeOption t,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete leave type'),
        content: Text('Delete "${t.name}"? This only works if unused.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await ref.read(leaveHrAdminProvider.notifier).deleteLeaveType(t.id);
    }
  }
}

class _WeekendsTab extends ConsumerWidget {
  const _WeekendsTab({required this.textPrimary});

  final Color textPrimary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(leaveHrAdminProvider);
    final n = ref.read(leaveHrAdminProvider.notifier);

    return ListPageState(
      isLoading: s.loadingWeekends,
      isRefreshing: s.refreshingWeekends,
      hasCachedData: s.weekends.isNotEmpty,
      error: s.error,
      isEmpty: s.weekends.isEmpty,
      onRetry: () => n.loadWeekends(),
      emptyTitle: 'No weekend days',
      emptySubtitle: 'Add weekend days for your leave calendar',
      emptyIcon: Icons.weekend_outlined,
      emptyButtonText: 'Add weekend day',
      onEmptyAction: () => _addWeekend(context, ref),
      content: RefreshIndicator(
        onRefresh: () => n.loadWeekends(refresh: true),
        child: FadeInContent(
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppThemeColors.pagePaddingAll,
            itemCount: s.weekends.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () => _addWeekend(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('Add weekend day'),
                    ),
                  ),
                );
              }
              final w = s.weekends[i - 1];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppThemeColors.cardColor(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppThemeColors.borderColor(context)),
                ),
                child: ListTile(
                  title: Text(
                    LeaveWeekend.weekdayLabel(w.dayOfWeek),
                    style: TextStyle(color: textPrimary),
                  ),
                  subtitle: Text(
                    'dayOfWeek: ${w.dayOfWeek} (0=Mon … 6=Sun)',
                    style: TextStyle(
                      color: AppThemeColors.textSecondaryColor(context),
                    ),
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: () async {
                      await n.deleteWeekend(w.id);
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _addWeekend(BuildContext context, WidgetRef ref) async {
    int selected = 5;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          title: const Text('Add weekend day'),
          content: DropdownButton<int>(
            isExpanded: true,
            value: selected,
            items: List.generate(7, (d) {
              return DropdownMenuItem(
                value: d,
                child: Text('${LeaveWeekend.weekdayLabel(d)} ($d)'),
              );
            }),
            onChanged: (v) {
              if (v != null) setSt(() => selected = v);
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (ok == true && context.mounted) {
      await ref.read(leaveHrAdminProvider.notifier).createWeekend(selected);
    }
  }
}

class _HolidaysTab extends ConsumerWidget {
  const _HolidaysTab({required this.textPrimary});

  final Color textPrimary;

  String _fmt(DateTime? d) {
    if (d == null) return '—';
    final x = d.toLocal();
    return '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(leaveHrAdminProvider);
    final n = ref.read(leaveHrAdminProvider.notifier);

    return ListPageState(
      isLoading: s.loadingHolidays,
      isRefreshing: s.refreshingHolidays,
      hasCachedData: s.holidays.isNotEmpty,
      error: s.error,
      isEmpty: s.holidays.isEmpty,
      onRetry: () => n.loadHolidays(),
      emptyTitle: 'No holidays',
      emptySubtitle: 'Add public holidays for leave planning',
      emptyIcon: Icons.celebration_outlined,
      emptyButtonText: 'Add holiday',
      onEmptyAction: () => _addHoliday(context, ref),
      content: RefreshIndicator(
        onRefresh: () => n.loadHolidays(refresh: true),
        child: FadeInContent(
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppThemeColors.pagePaddingAll,
            itemCount: s.holidays.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () => _addHoliday(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('Add holiday'),
                    ),
                  ),
                );
              }
              final h = s.holidays[i - 1];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppThemeColors.cardColor(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppThemeColors.borderColor(context)),
                ),
                child: ListTile(
                  title: Text(h.name, style: TextStyle(color: textPrimary)),
                  subtitle: Text(
                    '${_fmt(h.startDate)} → ${_fmt(h.endDate)}',
                    style: TextStyle(
                      color: AppThemeColors.textSecondaryColor(context),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _editHoliday(context, ref, h),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        onPressed: () async {
                          await n.deleteHoliday(h.id);
                        },
                      ),
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

  Future<void> _addHoliday(BuildContext context, WidgetRef ref) async {
    final nameC = TextEditingController();
    DateTime start = DateTime.now();
    DateTime end = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          title: const Text('New holiday'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameC,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text('Start'),
                  subtitle: Text(_fmt(start)),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: start,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setSt(() => start = d);
                  },
                ),
                ListTile(
                  title: const Text('End'),
                  subtitle: Text(_fmt(end)),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: end,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setSt(() => end = d);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
          ],
        ),
      ),
    );
    if (ok == true && nameC.text.trim().isNotEmpty && context.mounted) {
      await ref.read(leaveHrAdminProvider.notifier).createHoliday(
            name: nameC.text,
            start: start,
            end: end,
          );
    }
    nameC.dispose();
  }

  Future<void> _editHoliday(
    BuildContext context,
    WidgetRef ref,
    LeaveHoliday h,
  ) async {
    final nameC = TextEditingController(text: h.name);
    DateTime start = h.startDate ?? DateTime.now();
    DateTime end = h.endDate ?? h.startDate ?? DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          title: const Text('Edit holiday'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameC,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text('Start'),
                  subtitle: Text(_fmt(start)),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: start,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setSt(() => start = d);
                  },
                ),
                ListTile(
                  title: const Text('End'),
                  subtitle: Text(_fmt(end)),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: end,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setSt(() => end = d);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok == true && nameC.text.trim().isNotEmpty && context.mounted) {
      await ref.read(leaveHrAdminProvider.notifier).updateHoliday(
            h.id,
            name: nameC.text,
            startDate: start,
            endDate: end,
          );
    }
    nameC.dispose();
  }
}
