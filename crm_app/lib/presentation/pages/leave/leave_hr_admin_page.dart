import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../data/models/leave_model.dart';
import '../../providers/leave_hr_admin_provider.dart';

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
    final surface = AppThemeColors.surfaceColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    ref.listen<LeaveHrAdminState>(leaveHrAdminProvider, (prev, next) {
      if (next.error != null &&
          prev?.error != next.error &&
          context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Colors.red.shade700,
          ),
        );
        ref.read(leaveHrAdminProvider.notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(
          'Leave HR (admin)',
          style: TextStyle(color: textPrimary),
        ),
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
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

    return Stack(
      children: [
        if (s.loadingTypes)
          const Center(child: CircularProgressIndicator())
        else
          RefreshIndicator(
            onRefresh: n.loadTypes,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
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
      ],
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
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
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

    return Stack(
      children: [
        if (s.loadingWeekends)
          const Center(child: CircularProgressIndicator())
        else
          RefreshIndicator(
            onRefresh: n.loadWeekends,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
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
      ],
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

    return Stack(
      children: [
        if (s.loadingHolidays)
          const Center(child: CircularProgressIndicator())
        else
          RefreshIndicator(
            onRefresh: n.loadHolidays,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
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
      ],
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
