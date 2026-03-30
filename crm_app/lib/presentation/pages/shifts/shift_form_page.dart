import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../data/models/shift_model.dart';
import '../../providers/shift_provider.dart';

/// Create or edit a shift (admin). Matches Postman body: name, startTime, endTime, weekendDays, gracePeriod, employeeIds.
class ShiftFormPage extends ConsumerStatefulWidget {
  const ShiftFormPage({super.key, this.existing});

  final WorkShift? existing;

  @override
  ConsumerState<ShiftFormPage> createState() => _ShiftFormPageState();
}

class _ShiftFormPageState extends ConsumerState<ShiftFormPage> {
  late final TextEditingController _name;
  late final TextEditingController _start;
  late final TextEditingController _end;
  late final TextEditingController _grace;
  late Set<int> _weekendDays;
  bool _saving = false;

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _start = TextEditingController(text: e?.startTime ?? '09:00');
    _end = TextEditingController(text: e?.endTime ?? '18:00');
    _grace = TextEditingController(
      text: e != null ? '${e.gracePeriod}' : '15',
    );
    _weekendDays = e != null && e.weekendDays.isNotEmpty
        ? e.weekendDays.toSet()
        : {5, 6};
  }

  @override
  void dispose() {
    _name.dispose();
    _start.dispose();
    _end.dispose();
    _grace.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a shift name')),
      );
      return;
    }
    final start = _start.text.trim();
    final end = _end.text.trim();
    if (start.isEmpty || end.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter start and end times (HH:mm)')),
      );
      return;
    }
    final grace = int.tryParse(_grace.text.trim()) ?? 0;
    final sortedDays = _weekendDays.toList()..sort();
    final existing = widget.existing;
    final draft = WorkShift(
      id: existing?.id ?? '',
      name: name,
      startTime: start,
      endTime: end,
      weekendDays: sortedDays,
      gracePeriod: grace,
      employeeIds: existing?.employeeIds ?? const [],
    );

    setState(() => _saving = true);
    try {
      if (existing != null && existing.id.isNotEmpty) {
        await ref.read(shiftProvider.notifier).updateShift(existing.id, draft);
      } else {
        await ref.read(shiftProvider.notifier).createShift(draft);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final surface = AppThemeColors.surfaceColor(context);
    final isEdit = widget.existing != null && widget.existing!.id.isNotEmpty;

    return Scaffold(
      backgroundColor: AppThemeColors.backgroundColor(context),
      appBar: AppBar(
        title: Text(isEdit ? 'Edit shift' : 'New shift'),
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        actions: [
          if (_saving)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Shift name',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _start,
                  decoration: const InputDecoration(
                    labelText: 'Start (HH:mm)',
                    border: OutlineInputBorder(),
                    hintText: '09:00',
                  ),
                  keyboardType: TextInputType.datetime,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _end,
                  decoration: const InputDecoration(
                    labelText: 'End (HH:mm)',
                    border: OutlineInputBorder(),
                    hintText: '18:00',
                  ),
                  keyboardType: TextInputType.datetime,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _grace,
            decoration: const InputDecoration(
              labelText: 'Grace period (minutes)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 20),
          Text(
            'Weekend days (0=Mon … 6=Sun)',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'These days are treated as weekend for this shift.',
            style: TextStyle(fontSize: 13, color: textSecondary),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(7, (i) {
              final on = _weekendDays.contains(i);
              return FilterChip(
                label: Text(_dayLabels[i]),
                selected: on,
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      _weekendDays.add(i);
                    } else {
                      _weekendDays.remove(i);
                    }
                  });
                },
              );
            }),
          ),
          if (isEdit) ...[
            const SizedBox(height: 24),
            Text(
              'Employee IDs on this shift are updated when you assign people from the shift list (Assign) or here after backend sync.',
              style: TextStyle(fontSize: 12, color: textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
