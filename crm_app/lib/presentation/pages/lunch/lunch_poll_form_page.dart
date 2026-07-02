import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/exceptions.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/lunch_model.dart';
import '../../../data/repositories/lunch_repository.dart';
import '../../providers/lunch_provider.dart';
import '../../widgets/crm_text_field.dart';
import 'lunch_poll_option_row.dart';
import 'lunch_ui_helpers.dart';

/// Opens create/edit poll sheet (web modal parity). Returns true when saved.
Future<bool> showLunchPollFormSheet(
  BuildContext context,
  WidgetRef ref, {
  LunchPoll? existing,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppThemeColors.backgroundColor(context),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.98,
        builder: (_, scrollController) => LunchPollFormSheet(
          scrollController: scrollController,
          existing: existing,
        ),
      ),
    ),
  );
  return saved ?? false;
}

class LunchPollFormSheet extends ConsumerStatefulWidget {
  const LunchPollFormSheet({
    super.key,
    required this.scrollController,
    this.existing,
  });

  final ScrollController scrollController;
  final LunchPoll? existing;

  @override
  ConsumerState<LunchPollFormSheet> createState() => _LunchPollFormSheetState();
}

class _LunchPollFormSheetState extends ConsumerState<LunchPollFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _endTimeCtrl;
  late DateTime _date;
  bool _allowVoteChange = true;
  bool _saving = false;
  bool _loadingPoll = false;
  String? _formError;
  LunchPoll? _baselinePoll;
  int? _selectedDurationMinutes = 60;
  final List<_OptionRow> _options = [];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? 'Today\'s Lunch');
    _endTimeCtrl = TextEditingController(
      text: e?.endTime != null
          ? formatLunchEndTimeDisplay(e!.endTime)
          : _defaultEndTime(),
    );
    _date = e?.date ?? DateTime.now();
    _allowVoteChange = e?.allowVoteChange ?? true;
    if (e != null) {
      _loadingPoll = true;
      _populateFromPoll(e);
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadExistingPoll());
    } else {
      _options.addAll([
        _OptionRow(label: 'Personal', kind: LunchOptionKind.personal),
        _OptionRow(label: 'Off', kind: LunchOptionKind.offAbsent),
      ]);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(lunchProvider.notifier).loadSettings();
    });
  }

  Future<void> _loadExistingPoll() async {
    final existing = widget.existing;
    if (existing == null || existing.id.isEmpty) {
      if (mounted) setState(() => _loadingPoll = false);
      return;
    }
    try {
      final repo = ref.read(lunchRepositoryProvider);
      final summary = await repo.getPollSummary(existing.id, poll: existing);
      if (!mounted) return;
      setState(() {
        _populateFromPoll(summary.poll, breakdown: summary.menuBreakdown);
        _loadingPoll = false;
      });
    } catch (_) {
      try {
        final full = await ref.read(lunchRepositoryProvider).refreshPollHydrated(
              existing.id,
            );
        if (!mounted) return;
        setState(() {
          _populateFromPoll(full);
          _loadingPoll = false;
        });
      } catch (_) {
        if (mounted) setState(() => _loadingPoll = false);
      }
    }
  }

  void _populateFromPoll(
    LunchPoll poll, {
    List<LunchMenuBreakdownRow>? breakdown,
  }) {
    _titleCtrl.text = poll.title;
    if (poll.endTime != null && poll.endTime!.isNotEmpty) {
      _endTimeCtrl.text = formatLunchEndTimeDisplay(poll.endTime);
      _selectedDurationMinutes = null;
    }
    _date = poll.date ?? _date;
    _allowVoteChange = poll.allowVoteChange;
    for (final o in _options) {
      o.labelCtrl.dispose();
    }
    _options.clear();
    final options = poll.optionsWithVoteTotals(breakdown);
    if (options.isNotEmpty) {
      for (final o in options) {
        _options.add(
          _OptionRow(
            id: o.id,
            label: o.label,
            kind: lunchOptionKindFrom(o.optionType),
            voteCount: o.voteCount,
          ),
        );
      }
    } else if (poll.options.isNotEmpty) {
      for (final o in poll.options) {
        _options.add(
          _OptionRow(
            id: o.id,
            label: o.label,
            kind: lunchOptionKindFrom(o.optionType),
            voteCount: o.voteCount,
          ),
        );
      }
    }
    if (_options.isEmpty) {
      _options.addAll([
        _OptionRow(label: 'Personal', kind: LunchOptionKind.personal),
        _OptionRow(label: 'Off', kind: LunchOptionKind.offAbsent),
      ]);
    }
    _syncBaseline();
  }

  void _syncBaseline() {
    final existing = widget.existing;
    if (existing == null) {
      _baselinePoll = null;
      return;
    }
    _baselinePoll = LunchPoll(
      id: existing.id,
      title: _titleCtrl.text.trim(),
      date: _date,
      costAmount: existing.costAmount,
      allowVoteChange: _allowVoteChange,
      endTime: lunchEndTimeToApi(_endTimeCtrl.text.trim()),
      options: _buildPollOptions().where((o) => o.id.isNotEmpty).toList(),
    );
  }

  static String _defaultEndTime() {
    final t = DateTime.now().add(const Duration(hours: 1));
    return DateFormat.jm().format(t);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _endTimeCtrl.dispose();
    for (final o in _options) {
      o.labelCtrl.dispose();
    }
    super.dispose();
  }

  void _addDuration(int minutes) {
    final now = DateTime.now();
    final end = now.add(Duration(minutes: minutes));
    setState(() {
      _selectedDurationMinutes = minutes;
      _endTimeCtrl.text = DateFormat.jm().format(end);
    });
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: lunchEndTimeOfDay(_endTimeCtrl.text),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null) {
      final dt = DateTime(2000, 1, 1, picked.hour, picked.minute);
      setState(() {
        _selectedDurationMinutes = null;
        _endTimeCtrl.text = DateFormat.jm().format(dt);
      });
    }
  }

  void _showFormError(String message) {
    setState(() => _formError = message);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  List<LunchPollOption> _buildPollOptions() {
    return _options
        .map(
          (o) => LunchPollOption(
            id: o.id,
            label: o.labelCtrl.text.trim(),
            optionType: lunchOptionKindApiValue(o.kind),
            voteCount: o.voteCount,
          ),
        )
        .where((o) => o.label.isNotEmpty)
        .toList();
  }

  String? _validateOptions() {
    for (final row in _options) {
      if (row.labelCtrl.text.trim().isEmpty) {
        return 'Every menu option needs a name (or remove empty rows)';
      }
    }
    return null;
  }

  String _formatSaveError(Object e) {
    if (e is ValidationException) {
      final fields = e.fieldErrors;
      if (fields != null && fields.isNotEmpty) {
        return fields.values.join('\n');
      }
      return e.message;
    }
    if (e is AppException) return e.message;
    return 'Failed to save poll: $e';
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _formError = null);

    if (_options.isEmpty) {
      _showFormError('Add at least one menu option');
      return;
    }

    if (!_formKey.currentState!.validate()) {
      _showFormError('Please enter a poll title');
      return;
    }

    final optionError = _validateOptions();
    if (optionError != null) {
      _showFormError(optionError);
      return;
    }

    final options = _buildPollOptions();
    if (options.isEmpty) {
      _showFormError('Add at least one menu option with a name');
      return;
    }

    setState(() => _saving = true);
    try {
      var settings = ref.read(lunchProvider).settings;
      if (settings == null) {
        await ref.read(lunchProvider.notifier).loadSettings();
        settings = ref.read(lunchProvider).settings;
      }
      final cost = settings?.defaultCostAmount ?? widget.existing?.costAmount;
      final hasOfficeMenu =
          options.any((o) => o.optionType == lunchOptionKindApiValue(LunchOptionKind.officeMenu));
      if (hasOfficeMenu && cost == null && widget.existing == null) {
        _showFormError(
          'Set a default meal cost in Lunch Settings before adding office menu items',
        );
        return;
      }
      final poll = LunchPoll(
        id: widget.existing?.id ?? '',
        title: _titleCtrl.text.trim(),
        date: _date,
        costAmount: cost,
        allowVoteChange: _allowVoteChange,
        endTime: lunchEndTimeToApi(_endTimeCtrl.text.trim()),
        options: options,
      );
      if (widget.existing == null) {
        await ref.read(lunchProvider.notifier).createPoll(poll);
      } else {
        await ref.read(lunchProvider.notifier).updatePoll(
              widget.existing!.id,
              poll,
              original: _baselinePoll ?? widget.existing,
            );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _showFormError(_formatSaveError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final border = AppThemeColors.borderColor(context);
    final isEdit = widget.existing != null;
    final dateLabel = formatLunchPollDate(_date);
    final settings = ref.watch(lunchProvider).settings;

    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: lunchBrandGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add_circle_outline, color: lunchBrandGreen),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEdit ? 'Edit lunch poll' : 'Create lunch poll',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      'Post today\'s menu for $dateLabel. Meal cost comes from Settings${settings?.defaultCostAmount != null ? ' (${settings!.defaultCostAmount} TK)' : ''}.',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _FormSection(
            title: 'Poll details',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Poll date', style: TextStyle(fontSize: 12, color: textSecondary)),
                const SizedBox(height: 4),
                Text(
                  '$dateLabel (today)',
                  style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary),
                ),
                const SizedBox(height: 14),
                CRMTextField(
                  controller: _titleCtrl,
                  label: 'Poll title',
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Text('Poll end time', style: TextStyle(fontSize: 12, color: textSecondary)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickEndTime,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: border),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _endTimeCtrl.text,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                        ),
                        Icon(Icons.schedule, color: textSecondary, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    _DurationChip(
                      label: '15 M',
                      selected: _selectedDurationMinutes == 15,
                      onTap: () => _addDuration(15),
                    ),
                    _DurationChip(
                      label: '30 M',
                      selected: _selectedDurationMinutes == 30,
                      onTap: () => _addDuration(30),
                    ),
                    _DurationChip(
                      label: '60 M',
                      selected: _selectedDurationMinutes == 60,
                      onTap: () => _addDuration(60),
                    ),
                    _DurationChip(
                      label: '2 H',
                      selected: _selectedDurationMinutes == 120,
                      onTap: () => _addDuration(120),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _FormSection(
            title: 'Voting rules',
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow vote changes'),
              value: _allowVoteChange,
              activeTrackColor: lunchBrandGreen.withValues(alpha: 0.4),
              activeThumbColor: lunchBrandGreen,
              onChanged: (v) => setState(() => _allowVoteChange = v),
            ),
          ),
          const SizedBox(height: 16),
          if (_loadingPoll)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            _FormSection(
            title: 'Menu options',
            trailing: isEdit
                ? null
                : TextButton.icon(
                    onPressed: () => setState(
                      () => _options.add(
                        _OptionRow(label: '', kind: LunchOptionKind.officeMenu),
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add option'),
                  ),
            child: Column(
              children: _options.asMap().entries.map((entry) {
                final i = entry.key;
                final row = entry.value;
                return Container(
                  key: row.key,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: border),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.drag_handle, color: textSecondary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: row.labelCtrl,
                              decoration: const InputDecoration(
                                hintText: 'Menu item name',
                                isDense: true,
                              ),
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                          if (!isEdit)
                            IconButton(
                              onPressed: _options.length <= 1
                                  ? null
                                  : () => setState(() {
                                      row.labelCtrl.dispose();
                                      _options.removeAt(i);
                                    }),
                              icon: const Icon(Icons.delete_outline, size: 20),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LunchOptionTypeSelector(
                        selected: row.kind,
                        onChanged: (k) => setState(() => row.kind = k),
                      ),
                      if (isEdit) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${row.voteCount} vote${row.voteCount == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
              ],
            ),
          ),
          if (_formError != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                _formError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13),
              ),
            ),
          ],
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: lunchBrandGreen,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _saving || _loadingPoll ? null : _save,
                      child: Text(_saving ? 'Saving…' : (isEdit ? 'Save poll' : 'Create poll')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final border = AppThemeColors.borderColor(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppThemeColors.cardColor(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: textPrimary,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? lunchBrandGreen.withValues(alpha: 0.15)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? lunchBrandGreen : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? lunchBrandGreen : null,
          ),
        ),
      ),
    );
  }
}

class _OptionRow {
  _OptionRow({
    this.id = '',
    required String label,
    required this.kind,
    this.voteCount = 0,
  })  : key = UniqueKey(),
        labelCtrl = TextEditingController(text: label);

  final Key key;
  final String id;
  final TextEditingController labelCtrl;
  LunchOptionKind kind;
  final int voteCount;
}

/// Legacy full-page route — delegates to sheet when pushed.
class LunchPollFormPage extends ConsumerWidget {
  const LunchPollFormPage({super.key, this.existing});

  final LunchPoll? existing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pop(context);
      showLunchPollFormSheet(context, ref, existing: existing);
    });
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
