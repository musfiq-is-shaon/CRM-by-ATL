import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../providers/lunch_provider.dart';
import '../../widgets/crm_button.dart';
import '../../widgets/crm_card.dart';
import '../../widgets/crm_text_field.dart';
import '../../widgets/loading_widget.dart';
import '../../../data/models/lunch_model.dart';

class LunchSettingsPage extends ConsumerStatefulWidget {
  const LunchSettingsPage({super.key});

  @override
  ConsumerState<LunchSettingsPage> createState() => _LunchSettingsPageState();
}

class _LunchSettingsPageState extends ConsumerState<LunchSettingsPage> {
  final _costCtrl = TextEditingController();
  bool _allowVoteChange = true;
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await ref.read(lunchProvider.notifier).loadSettings();
    final s = ref.read(lunchProvider).settings;
    if (s != null && mounted) {
      setState(() {
        _costCtrl.text = s.defaultCostAmount?.toString() ?? '';
        _allowVoteChange = s.allowVoteChange;
        _loaded = true;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final settings = LunchSettings(
        defaultCostAmount: num.tryParse(_costCtrl.text.trim()),
        allowVoteChange: _allowVoteChange,
      );
      await ref.read(lunchProvider.notifier).saveSettings(settings);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save settings')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _costCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);

    if (!_loaded) {
      return const LoadingWidget(message: 'Loading settings…');
    }

    return ListView(
      padding: AppThemeColors.pagePaddingAll,
      children: [
        Text(
          'Settings',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          'Default lunch cost and voting rules.',
          style: TextStyle(fontSize: 13, color: textSecondary),
        ),
        const SizedBox(height: 16),
        CRMCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CRMTextField(
                controller: _costCtrl,
                label: 'Default cost (${AppConstants.currencySymbol})',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow vote change'),
                subtitle: const Text('Employees can change their lunch choice'),
                value: _allowVoteChange,
                onChanged: (v) => setState(() => _allowVoteChange = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CRMButton(
          text: _saving ? 'Saving…' : 'Save settings',
          icon: Icons.save_outlined,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}
