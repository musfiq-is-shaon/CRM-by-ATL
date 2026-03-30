import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../providers/auth_provider.dart';

/// `PATCH /api/users/me` — name & phone (Postman: Update me).
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  bool _saving = false;
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _phone = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    final u = ref.read(authProvider).user;
    _name.text = u?.name ?? '';
    _phone.text = u?.phone ?? '';
    _seeded = true;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(authProvider.notifier).updateProfile(
            name: name,
            phone: _phone.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      final err = ref.read(authProvider).error;
      if (mounted && err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err)),
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

    return Scaffold(
      backgroundColor: AppThemeColors.backgroundColor(context),
      appBar: AppBar(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        title: const Text('Edit profile'),
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
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phone,
            decoration: const InputDecoration(
              labelText: 'Phone',
              border: OutlineInputBorder(),
              hintText: 'Optional',
            ),
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
    );
  }
}
