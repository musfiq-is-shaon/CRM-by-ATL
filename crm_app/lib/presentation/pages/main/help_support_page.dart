import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../core/theme/design_tokens.dart';
import '../../widgets/app_section_header.dart';
import '../../widgets/themed_panel.dart';

/// Help & Support — contact options and quick answers.
class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key});

  static const List<({String title, String body})> _faqs = [
    (
      title: "I can't sign in",
      body:
          'Check your email and password. Use Forgot Password on the login screen if needed. If your organization uses SSO or invited accounts, ask your admin to confirm your access.',
    ),
    (
      title: 'How do I change my password?',
      body:
          'Go to More → Account → Change Password. Enter your current password and your new password twice, then tap Save.',
    ),
    (
      title: 'How do I update my profile?',
      body:
          'Open More → Profile to view your details. To edit name or phone, use More → Settings → Edit profile (or the edit action from Profile, depending on your build).',
    ),
    (
      title: 'How do I apply for leave?',
      body:
          'Open More → Leave. Review your balances, then tap the action to apply. Choose leave type, dates, and duration. Your manager or HR will approve based on your company process.',
    ),
    (
      title: 'Notifications not working',
      body:
          'On Android and iOS, enable notifications for this app in system Settings. In the app, open More → Notification Settings and ensure reminders are turned on.',
    ),
    (
      title: 'Leave balances or attendance look wrong',
      body:
          "Balances and attendance depend on your company's HR settings and shift rules. Contact HR or your administrator if numbers don't match your records.",
    ),
    (
      title: 'Data feels slow or out of date',
      body:
          'Check your internet connection. Pull down on list screens to refresh. If a screen stays empty or errors, try again in a moment or sign out and sign back in.',
    ),
    (
      title: 'Where are tasks, contacts, and deals?',
      body:
          'Use the bottom navigation or the dashboard (home) shortcuts to open Tasks, Contacts, Companies, Sales, and Expenses. Your role may limit which areas you see.',
    ),
    (
      title: 'Who can see my data?',
      body:
          'Access follows your account role (for example user vs admin). Your organization sets policies; ask your administrator if you need access to a specific area.',
    ),
  ];

  Future<void> _openUri(BuildContext context, Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final mailto = Uri.parse(
      'mailto:${AppConstants.supportEmail}'
      '?subject=${Uri.encodeComponent('CRM mobile app - support')}',
    );
    final helpUrl = AppConstants.helpCenterUrl.trim();
    final hasHelpUrl = helpUrl.isNotEmpty;

    return Scaffold(
      backgroundColor: AppThemeColors.backgroundColor(context),
      appBar: AppThemeColors.appBarTitle(context, 'Help & Support'),
      body: ListView(
        padding: AppThemeColors.pagePaddingAll,
        children: [
          AppSectionHeader(
            title: "We're here to help",
            subtitle:
                'Contact your administrator or use the options below for common issues.',
          ),
          const SizedBox(height: AppSpacing.md),
          ThemedPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Contact',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.email_outlined, color: cs.primary),
                  title: const Text('Email support'),
                  subtitle: Text(
                    AppConstants.supportEmail,
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                  trailing: Icon(Icons.open_in_new, size: 18, color: textSecondary),
                  onTap: () => _openUri(context, mailto),
                ),
                if (hasHelpUrl) ...[
                  Divider(height: 1, color: AppThemeColors.dividerColor(context)),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.menu_book_outlined, color: cs.primary),
                    title: const Text('Help center'),
                    subtitle: Text(
                      helpUrl,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textSecondary, fontSize: 13),
                    ),
                    trailing:
                        Icon(Icons.open_in_new, size: 18, color: textSecondary),
                    onTap: () => _openUri(context, Uri.parse(helpUrl)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppSectionHeader(
            title: 'Common questions',
            subtitle: 'Tips for using the app.',
          ),
          const SizedBox(height: AppSpacing.sm),
          ThemedPanel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < _faqs.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: AppThemeColors.dividerColor(context),
                    ),
                  ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    title: Text(_faqs[i].title),
                    children: [
                      Text(
                        _faqs[i].body,
                        style: TextStyle(
                          color: textSecondary,
                          height: 1.4,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Text(
              'CRM mobile · v1.0.0',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: textSecondary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
