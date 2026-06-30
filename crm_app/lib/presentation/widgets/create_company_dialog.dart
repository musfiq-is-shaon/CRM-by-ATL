import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/company_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/user_provider.dart';

/// Shows create-company dialog. Required: name, location, country, currency, KAM.
/// Opens immediately; currencies/users load in the background if needed.
Future<String?> showCreateCompanyDialog(
  BuildContext context,
  WidgetRef ref, {
  String? initialName,
  String? initialLocation,
  String? initialCountry,
}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  return showDialog<String>(
    context: context,
    useRootNavigator: true,
    builder: (_) => _CreateCompanyDialog(
      initialName: initialName,
      initialLocation: initialLocation,
      initialCountry: initialCountry,
    ),
  );
}

class _CreateCompanyDialog extends ConsumerStatefulWidget {
  const _CreateCompanyDialog({
    this.initialName,
    this.initialLocation,
    this.initialCountry,
  });

  final String? initialName;
  final String? initialLocation;
  final String? initialCountry;

  @override
  ConsumerState<_CreateCompanyDialog> createState() =>
      _CreateCompanyDialogState();
}

class _CreateCompanyDialogState extends ConsumerState<_CreateCompanyDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _locationController;
  late final TextEditingController _countryController;

  String? _selectedCurrencyId;
  String? _selectedKamUserId;
  bool _isCreating = false;
  bool _defaultsApplied = false;

  @override
  void initState() {
    super.initState();
    final split = _splitLocationAndCountry(
      widget.initialLocation,
      initialCountry: widget.initialCountry,
    );
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _locationController = TextEditingController(text: split.location ?? '');
    _countryController = TextEditingController(text: split.country ?? '');

    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLookupData());
  }

  void _ensureLookupData() {
    final currencies = ref.read(currenciesProvider);
    final users = ref.read(usersProvider);

    if (currencies.currencies.isEmpty && !currencies.isLoading) {
      ref.read(currenciesProvider.notifier).loadCurrencies();
    }
    if (users.users.isEmpty && !users.isLoading) {
      ref.read(usersProvider.notifier).loadUsers();
    }
  }

  void _applyDefaultsIfNeeded(
    CurrenciesState currenciesState,
    UsersState usersState,
  ) {
    if (_defaultsApplied) return;

    final authState = ref.read(authProvider);
    var changed = false;

    if (_selectedCurrencyId == null && currenciesState.currencies.isNotEmpty) {
      _selectedCurrencyId = currenciesState.currencies.first.id;
      changed = true;
    }

    if (_selectedKamUserId == null) {
      var kamId = authState.user?.id;
      if (kamId != null && !usersState.users.any((u) => u.id == kamId)) {
        kamId = usersState.users.isNotEmpty ? usersState.users.first.id : null;
      }
      kamId ??= usersState.users.isNotEmpty ? usersState.users.first.id : null;
      if (kamId != null) {
        _selectedKamUserId = kamId;
        changed = true;
      }
    }

    if (changed) {
      _defaultsApplied = true;
      setState(() {});
    } else if (currenciesState.currencies.isNotEmpty &&
        usersState.users.isNotEmpty) {
      _defaultsApplied = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String label, Color textSecondary, Color border) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: textSecondary),
      border: OutlineInputBorder(borderSide: BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: border)),
    );
  }

  void _closeDialog([String? companyId]) {
    Navigator.of(context, rootNavigator: true).pop(companyId);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final kamUserId = _selectedKamUserId;
    final currencyId = _selectedCurrencyId;
    if (kamUserId == null || currencyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please wait for currency and KAM to load, or pick them from the lists.',
          ),
        ),
      );
      return;
    }

    setState(() => _isCreating = true);
    try {
      final authState = ref.read(authProvider);
      final created = await ref.read(companiesProvider.notifier).createCompany(
            name: _nameController.text.trim(),
            location: _locationController.text.trim(),
            country: _countryController.text.trim(),
            kamUserId: kamUserId,
            currencyId: currencyId,
            createdByUserId: authState.user?.id,
          );

      if (!mounted) return;

      if (created != null && created.id.isNotEmpty) {
        _closeDialog(created.id);
        return;
      }

      final error = ref.read(companiesProvider).error;
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error ?? 'Failed to create company. Please try again.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create company: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersState = ref.watch(usersProvider);
    final currenciesState = ref.watch(currenciesProvider);

    _applyDefaultsIfNeeded(currenciesState, usersState);

    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final borderColor = AppThemeColors.borderColor(context);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final surfaceColor = AppThemeColors.surfaceColor(context);

    final currenciesLoading =
        currenciesState.isLoading && currenciesState.currencies.isEmpty;
    final usersLoading = usersState.isLoading && usersState.users.isEmpty;

    return AlertDialog(
      scrollable: true,
      title: Text('Create Company', style: TextStyle(color: textPrimary)),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nameController,
              style: TextStyle(color: textPrimary),
              decoration: _fieldDecoration('Company Name *', textSecondary, borderColor),
              validator: (value) =>
                  value == null || value.trim().isEmpty
                      ? 'Company name is required'
                      : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationController,
              style: TextStyle(color: textPrimary),
              decoration: _fieldDecoration('Location *', textSecondary, borderColor),
              validator: (value) =>
                  value == null || value.trim().isEmpty
                      ? 'Location is required'
                      : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _countryController,
              style: TextStyle(color: textPrimary),
              decoration: _fieldDecoration('Country *', textSecondary, borderColor),
              validator: (value) =>
                  value == null || value.trim().isEmpty
                      ? 'Country is required'
                      : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey('currency-${_selectedCurrencyId ?? 'none'}'),
              isExpanded: true,
              initialValue: _selectedCurrencyId,
              decoration: _fieldDecoration('Currency *', textSecondary, borderColor),
              items: currenciesState.currencies.map((currency) {
                return DropdownMenuItem(
                  value: currency.id,
                  child: Text('${currency.code} - ${currency.name}'),
                );
              }).toList(),
              onChanged: currenciesLoading
                  ? null
                  : (value) => setState(() => _selectedCurrencyId = value),
              validator: (value) {
                if (currenciesLoading) return 'Currencies are still loading';
                if (value == null || value.isEmpty) return 'Currency is required';
                return null;
              },
            ),
            if (currenciesLoading)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: LinearProgressIndicator(
                  color: primaryColor,
                  backgroundColor: primaryColor.withValues(alpha: 0.15),
                ),
              ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey('kam-${_selectedKamUserId ?? 'none'}'),
              isExpanded: true,
              initialValue: _selectedKamUserId,
              decoration: _fieldDecoration(
                'KAM (Key Account Manager) *',
                textSecondary,
                borderColor,
              ),
              dropdownColor: surfaceColor,
              items: usersState.users
                  .map(
                    (user) => DropdownMenuItem(
                      value: user.id,
                      child: Text(
                        user.name,
                        style: TextStyle(color: textPrimary),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: usersLoading
                  ? null
                  : (value) => setState(() => _selectedKamUserId = value),
              validator: (value) {
                if (usersLoading) return 'Users are still loading';
                if (value == null || value.isEmpty) return 'KAM is required';
                return null;
              },
            ),
            if (usersLoading)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: LinearProgressIndicator(
                  color: primaryColor,
                  backgroundColor: primaryColor.withValues(alpha: 0.15),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => _closeDialog(),
          child: Text('Cancel', style: TextStyle(color: primaryColor)),
        ),
        TextButton(
          onPressed: _isCreating ? null : _submit,
          child: _isCreating
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: primaryColor,
                  ),
                )
              : Text('Create', style: TextStyle(color: primaryColor)),
        ),
      ],
    );
  }
}

({String? location, String? country}) _splitLocationAndCountry(
  String? raw, {
  String? initialCountry,
}) {
  if (initialCountry != null && initialCountry.trim().isNotEmpty) {
    return (location: raw?.trim(), country: initialCountry.trim());
  }

  final text = raw?.trim();
  if (text == null || text.isEmpty) {
    return (location: null, country: null);
  }

  final comma = text.lastIndexOf(',');
  if (comma <= 0 || comma >= text.length - 1) {
    return (location: text, country: null);
  }

  return (
    location: text.substring(0, comma).trim(),
    country: text.substring(comma + 1).trim(),
  );
}
