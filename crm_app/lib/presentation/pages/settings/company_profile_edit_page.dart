import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../data/models/company_profile_model.dart';
import '../../providers/company_profile_provider.dart';

/// `PUT /api/company-profile` — admin only (Postman).
class CompanyProfileEditPage extends ConsumerStatefulWidget {
  const CompanyProfileEditPage({super.key, required this.initial});

  final CompanyProfile initial;

  @override
  ConsumerState<CompanyProfileEditPage> createState() =>
      _CompanyProfileEditPageState();
}

class _CompanyProfileEditPageState extends ConsumerState<CompanyProfileEditPage> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _website;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _country;
  late final TextEditingController _industry;
  late final TextEditingController _taxId;
  late final TextEditingController _description;
  late final TextEditingController _logo;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _name = TextEditingController(text: p.name ?? '');
    _email = TextEditingController(text: p.email ?? '');
    _phone = TextEditingController(text: p.phone ?? '');
    _website = TextEditingController(text: p.website ?? '');
    _address = TextEditingController(text: p.address ?? '');
    _city = TextEditingController(text: p.city ?? '');
    _country = TextEditingController(text: p.country ?? '');
    _industry = TextEditingController(text: p.industry ?? '');
    _taxId = TextEditingController(text: p.taxId ?? '');
    _description = TextEditingController(text: p.description ?? '');
    _logo = TextEditingController(text: p.logo ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _website.dispose();
    _address.dispose();
    _city.dispose();
    _country.dispose();
    _industry.dispose();
    _taxId.dispose();
    _description.dispose();
    _logo.dispose();
    super.dispose();
  }

  CompanyProfile _draft() {
    final p = widget.initial;
    String? emptyToNull(String s) {
      final t = s.trim();
      return t.isEmpty ? null : t;
    }

    return CompanyProfile(
      id: p.id,
      name: emptyToNull(_name.text) ?? '',
      email: emptyToNull(_email.text),
      phone: emptyToNull(_phone.text),
      website: emptyToNull(_website.text),
      address: emptyToNull(_address.text),
      city: emptyToNull(_city.text),
      country: emptyToNull(_country.text),
      industry: emptyToNull(_industry.text),
      taxId: emptyToNull(_taxId.text),
      description: emptyToNull(_description.text),
      logo: emptyToNull(_logo.text),
      createdAt: p.createdAt,
      updatedAt: p.updatedAt,
    );
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Company name is required')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(companyProfileProvider.notifier).update(_draft());
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
    final surface = AppThemeColors.surfaceColor(context);

    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        );

    return Scaffold(
      backgroundColor: AppThemeColors.backgroundColor(context),
      appBar: AppBar(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        title: const Text('Company profile'),
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
            TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'All fields match the backend. Logo: base64 data URL or leave empty (Postman).',
            style: TextStyle(
              fontSize: 13,
              color: AppThemeColors.textSecondaryColor(context),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: deco('Company name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            decoration: deco('Email'),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            decoration: deco('Phone'),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _website,
            decoration: deco('Website'),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _address,
            decoration: deco('Address'),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _city,
            decoration: deco('City'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _country,
            decoration: deco('Country'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _industry,
            decoration: deco('Industry'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _taxId,
            decoration: deco('Tax ID'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            decoration: deco('Description'),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _logo,
            decoration: deco('Logo (data URL or empty)'),
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}
