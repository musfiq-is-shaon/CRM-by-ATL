import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../data/models/leave_model.dart';
import '../../../data/repositories/leave_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leave_provider.dart';

class LeaveBalancesPage extends ConsumerStatefulWidget {
  const LeaveBalancesPage({super.key});

  @override
  ConsumerState<LeaveBalancesPage> createState() => _LeaveBalancesPageState();
}

class _LeaveBalancesPageState extends ConsumerState<LeaveBalancesPage> {
  late final TextEditingController _userIdController;
  final Map<String, TextEditingController> _balanceControllers = {};
  LeaveBalancesResult? _result;
  bool _loading = false;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final uid = ref.read(currentUserIdProvider) ?? '';
    _userIdController = TextEditingController(text: uid);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(leaveProvider.notifier).loadReportingInfo();
    });
  }

  @override
  void dispose() {
    _userIdController.dispose();
    for (final c in _balanceControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _disposeBalanceControllers() {
    for (final c in _balanceControllers.values) {
      c.dispose();
    }
    _balanceControllers.clear();
  }

  bool get _canEditBalances {
    final isAdmin = ref.read(isAdminProvider);
    final isMgr =
        ref.read(leaveProvider.select((s) => s.reportingInfo?.isReportingManager ?? false));
    return isAdmin || isMgr;
  }

  Future<void> _load() async {
    final userId = _userIdController.text.trim();
    if (userId.isEmpty) {
      setState(() => _error = 'Enter a user ID');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    _disposeBalanceControllers();
    try {
      final repo = ref.read(leaveRepositoryProvider);
      final r = await repo.getLeaveBalances(userId);
      if (!mounted) return;
      for (final row in r.balances) {
        _balanceControllers[row.leaveTypeId] = TextEditingController(
          text: _formatBalance(row.balance),
        );
      }
      setState(() {
        _result = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _formatBalance(double v) {
    if (v == v.roundToDouble()) return v.round().toString();
    return v.toString();
  }

  Future<void> _save() async {
    final userId = _userIdController.text.trim();
    if (userId.isEmpty || _result == null) return;
    final balances = <Map<String, dynamic>>[];
    for (final row in _result!.balances) {
      final c = _balanceControllers[row.leaveTypeId];
      if (c == null) continue;
      final parsed = double.tryParse(c.text.trim());
      if (parsed == null || parsed < 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid balance for ${row.leaveTypeName ?? row.leaveTypeId}'),
          ),
        );
        return;
      }
      balances.add({
        'leaveTypeId': row.leaveTypeId,
        'balance': parsed,
      });
    }
    if (balances.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No balances to save')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(leaveRepositoryProvider).setLeaveBalances(userId, balances);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Balances updated')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppThemeColors.backgroundColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final borderColor = AppThemeColors.borderColor(context);
    final cardFill = AppThemeColors.cardColor(context);
    final canEdit = _canEditBalances;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppThemeColors.appBarTitle(context, 'Leave balances'),
      body: ListView(
        padding: AppThemeColors.pagePaddingAll,
        children: [
          Text(
            'View or update allocated days per leave type. Access follows the API (self, admin, or reporting manager).',
            style: TextStyle(color: textSecondary, fontSize: 14, height: 1.35),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _userIdController,
            decoration: const InputDecoration(
              labelText: 'User ID',
              border: OutlineInputBorder(),
              hintText: 'Employee user id',
            ),
            style: TextStyle(color: textPrimary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton(
                onPressed: _loading ? null : _load,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Load'),
              ),
              if (canEdit && _result != null && _result!.balances.isNotEmpty) ...[
                const SizedBox(width: 12),
                FilledButton.tonal(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save balances'),
                ),
              ],
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Colors.red.shade700)),
          ],
          if (_result != null && _result!.balances.isEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'No balance rows returned.',
              style: TextStyle(color: textSecondary),
            ),
          ],
          if (_result != null && _result!.balances.isNotEmpty) ...[
            const SizedBox(height: 20),
            ..._result!.balances.map((row) {
              final inactive = row.isActive == false;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: cardFill,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.leaveTypeName ?? row.leaveTypeId,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      if (inactive)
                        Text(
                          'Inactive type',
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      const SizedBox(height: 8),
                      if (canEdit)
                        TextField(
                          controller: _balanceControllers[row.leaveTypeId],
                          decoration: const InputDecoration(
                            labelText: 'Days',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                          ],
                          style: TextStyle(color: textPrimary),
                        )
                      else
                        Text(
                          'Days: ${_formatBalance(row.balance)}',
                          style: TextStyle(color: textSecondary),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
