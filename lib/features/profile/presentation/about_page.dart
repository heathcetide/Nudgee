import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:nudgee/app/router/app_router.dart';
import 'package:nudgee/core/extensions/context_extensions.dart';
import 'package:nudgee/features/common/widgets/page_scaffold.dart';

/// About page — shows app info, version, changelog, licenses, contact.
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _version = '1.0.0';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = info.version;
          _buildNumber = info.buildNumber;
        });
      }
    } catch (e) {
      debugPrint('[About] load package info error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return PageScaffold(
      title: Text(l10n.aboutTitle),
      leading: getPopLeading(context),
      child: ListView(
        children: [
          const SizedBox(height: 32),

          // ── App Icon + Name + Tagline ──────────────────────────────────
          Center(
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.tertiary,
                      ],
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.self_improvement, size: 48, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.aboutAppName,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.aboutAppDesc,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${l10n.aboutVersion} $_version${_buildNumber.isNotEmpty ? ' ($_buildNumber)' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ── Changelog ──────────────────────────────────────────────────
          _SectionCard(
            title: l10n.aboutChangelog,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.aboutChangelogContent,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Open Source ────────────────────────────────────────────────
          _SectionCard(
            title: l10n.aboutOpenSource,
            children: [
              ListTile(
                leading: const Icon(Icons.code_outlined),
                title: Text(l10n.aboutOpenSourceDesc),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  showLicensePage(
                    context: context,
                    applicationName: l10n.aboutAppName,
                    applicationVersion: _version,
                    applicationLegalese: l10n.aboutCopyRight,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Contact ────────────────────────────────────────────────────
          _SectionCard(
            title: l10n.aboutContact,
            children: [
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: Text(l10n.aboutContactEmail),
                trailing: Text(
                  l10n.aboutContactEmailValue,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                onTap: () {
                  SmartDialog.showNotify(
                    msg: l10n.aboutContactEmailValue,
                    notifyType: NotifyType.alert,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Legal ──────────────────────────────────────────────────────
          _SectionCard(
            title: '',
            children: [
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: Text(l10n.aboutPrivacyPolicy),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  GoRouter.of(context).push(AppRouter.privacyPolicy);
                },
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(l10n.aboutUserAgreement),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  GoRouter.of(context).push(AppRouter.userAgreement);
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Copyright ──────────────────────────────────────────────────
          Center(
            child: Text(
              l10n.aboutCopyRight,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Platform info ──────────────────────────────────────────────
          Center(
            child: Text(
              '${Platform.isAndroid ? 'Android' : 'iOS'} · Build $_buildNumber',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

/// A card with an optional section header.
class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 24, bottom: 6),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.hintColor,
              ),
            ),
          ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }
}
