import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme_colors.dart';
import '../pages/settings/company_profile_edit_page.dart';
import '../pages/settings/edit_profile_page.dart';
import '../providers/auth_provider.dart';
import '../providers/company_profile_provider.dart';
import 'crm_card.dart';

/// User + company sections for the Profile screen.
class ProfileOverviewBody extends ConsumerStatefulWidget {
  const ProfileOverviewBody({super.key});

  @override
  ConsumerState<ProfileOverviewBody> createState() =>
      _ProfileOverviewBodyState();
}

class _ProfileOverviewBodyState extends ConsumerState<ProfileOverviewBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(companyProfileProvider.notifier).load();
    });
  }

  String _dash(String? s) {
    if (s == null || s.trim().isEmpty) return '—';
    return s.trim();
  }

  String _locationLine(String? city, String? country) {
    final parts = <String>[];
    if (city != null && city.trim().isNotEmpty) parts.add(city.trim());
    if (country != null && country.trim().isNotEmpty) parts.add(country.trim());
    return parts.isEmpty ? '—' : parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isAdmin = ref.watch(isAdminProvider);
    final companyState = ref.watch(companyProfileProvider);
    final company = companyState.profile;

    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    final profileName = user?.name ?? 'User';
    final email = _dash(user?.email);
    final role = (user?.role ?? 'user').toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _profileHeroHeader(
          context: context,
          profileName: profileName,
          email: email,
          role: role,
          companyName: company?.name?.isNotEmpty == true
              ? company!.name!
              : 'No company',
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          primaryColor: primaryColor,
        ),
        const SizedBox(height: 16),
        _sectionCard(
          context: context,
          title: 'Your Profile',
          subtitle: 'Personal account information',
          onEdit: () async {
            final ok = await Navigator.of(context).push<bool>(
              MaterialPageRoute(builder: (_) => const EditProfilePage()),
            );
            if (ok == true && mounted) setState(() {});
          },
          child: Column(
            children: [
              _kvRow('Name', profileName, textPrimary, textSecondary),
              _kvRow('Email', email, textPrimary, textSecondary),
              _kvRow('Phone', _dash(user?.phone), textPrimary, textSecondary),
              _kvRow('Role', user?.role ?? 'user', textPrimary, textSecondary),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          context: context,
          title: 'Company',
          subtitle: 'Organization information',
          onEdit: isAdmin && company != null
              ? () async {
                  final ok = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => CompanyProfileEditPage(initial: company),
                    ),
                  );
                  if (ok == true && mounted) {
                    await ref.read(companyProfileProvider.notifier).load();
                  }
                }
              : null,
          child: _buildCompanyBody(
            context,
            companyState: companyState,
            company: company,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _profileHeroHeader({
    required BuildContext context,
    required String profileName,
    required String email,
    required String role,
    required String companyName,
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryColor,
  }) {
    final surface = AppThemeColors.surfaceColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final initial =
        profileName.isNotEmpty ? profileName[0].toUpperCase() : '?';

    // Material You–style diagonal wash: primary → tertiary hint → surface.
    final washTop = Color.alphaBlend(
      cs.primary.withValues(alpha: isDark ? 0.34 : 0.22),
      surface,
    );
    final washMid = Color.alphaBlend(
      cs.tertiary.withValues(alpha: isDark ? 0.18 : 0.12),
      surface,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -32,
            top: -40,
            child: IgnorePointer(
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      cs.tertiary.withValues(alpha: isDark ? 0.14 : 0.10),
                      cs.tertiary.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: -36,
            bottom: -24,
            child: IgnorePointer(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      cs.primary.withValues(alpha: isDark ? 0.12 : 0.08),
                      cs.primary.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  washTop,
                  washMid,
                  surface,
                ],
                stops: const [0.0, 0.48, 1.0],
              ),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: isDark ? 0.55 : 0.65),
              ),
              boxShadow: [
                BoxShadow(
                  color: cs.shadow.withValues(alpha: isDark ? 0.35 : 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          cs.primary,
                          Color.lerp(cs.primary, cs.tertiary, 0.55)!,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withValues(alpha: 0.28),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: surface,
                      child: Text(
                        initial,
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 26,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Your account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    profileName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      letterSpacing: -0.3,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.alternate_email_rounded,
                        size: 16,
                        color: textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          email,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _heroChip(
                        icon: Icons.verified_user_outlined,
                        label: role,
                        foreground: textPrimary,
                        background: primaryColor.withValues(alpha: 0.14),
                        border: primaryColor.withValues(alpha: 0.28),
                      ),
                      _heroChip(
                        icon: Icons.apartment_rounded,
                        label: companyName,
                        foreground: textPrimary,
                        background: cs.secondary.withValues(alpha: 0.16),
                        border: cs.secondary.withValues(alpha: 0.38),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroChip({
    required IconData icon,
    required String label,
    required Color foreground,
    required Color background,
    required Color border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: foreground.withValues(alpha: 0.85)),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyBody(
    BuildContext context, {
    required CompanyProfileState companyState,
    required dynamic company,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    if (companyState.isLoading && company == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (companyState.error != null && company == null) {
      return Text(
        companyState.error!,
        style: TextStyle(color: Colors.red.shade700, fontSize: 14),
      );
    }

    if (company == null) {
      return Text(
        'No company data loaded.',
        style: TextStyle(color: textSecondary),
      );
    }

    return Column(
      children: [
        _kvRow('Name', _dash(company.name), textPrimary, textSecondary),
        _kvRow('Industry', _dash(company.industry), textPrimary, textSecondary),
        _kvRow(
          'Location',
          _locationLine(company.city, company.country),
          textPrimary,
          textSecondary,
        ),
        _kvRow('Address', _dash(company.address), textPrimary, textSecondary),
        _kvRow('Website', _dash(company.website), textPrimary, textSecondary),
        _kvRow('Email', _dash(company.email), textPrimary, textSecondary),
        _kvRow('Phone', _dash(company.phone), textPrimary, textSecondary),
        _kvRow('Tax ID', _dash(company.taxId), textPrimary, textSecondary),
        if ((company.description ?? '').trim().isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppThemeColors.backgroundColor(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              company.description!,
              style: TextStyle(
                fontSize: 14,
                color: textPrimary,
                height: 1.35,
              ),
            ),
          ),
      ],
    );
  }

  Widget _sectionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required Widget child,
    VoidCallback? onEdit,
  }) {
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);

    return CRMCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ),
              if (onEdit != null)
                TextButton(onPressed: onEdit, child: const Text('Edit')),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _kvRow(
    String label,
    String value,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(
                color: textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
