import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:nudgee/app/router/app_router.dart';
import 'package:nudgee/core/extensions/context_extensions.dart';
import 'package:nudgee/features/common/widgets/page_scaffold.dart';

/// About page — single-screen layout (no scroll).
/// Shows app icon, name, version, and quick links to changelog,
/// open source licenses, contact, privacy policy, and user agreement.
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _version = '1.0.0';
  String _buildNumber = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              // ── App Icon + Name + Tagline (top section) ─────────────────
              Spacer(flex: 1),
              Container(
                width: 80,
                height: 80,
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
                  child: Icon(Icons.self_improvement, size: 44, color: Colors.white),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                l10n.aboutAppName,
                style: theme.textTheme.headlineSmall?.copyWith(
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
              const SizedBox(height: 6),
              Text(
                '${l10n.aboutVersion} $_version${_buildNumber.isNotEmpty ? ' ($_buildNumber)' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Spacer(flex: 1),

              // ── Quick Links Card ─────────────────────────────────────────
              Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: ListTile.divideTiles(
                    context: context,
                    tiles: [
                      ListTile(
                        leading: const Icon(Icons.history_outlined, size: 22),
                        title: Text(l10n.aboutChangelog, style: const TextStyle(fontSize: 15)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                        onTap: () => GoRouter.of(context).push(AppRouter.changelog),
                      ),
                      ListTile(
                        leading: const Icon(Icons.code_outlined, size: 22),
                        title: Text(l10n.aboutOpenSource, style: const TextStyle(fontSize: 15)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                        onTap: () {
                          showLicensePage(
                            context: context,
                            applicationName: l10n.aboutAppName,
                            applicationVersion: _version,
                            applicationLegalese: l10n.aboutCopyRight,
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.email_outlined, size: 22),
                        title: Text(l10n.aboutContact, style: const TextStyle(fontSize: 15)),
                        trailing: Text(
                          l10n.aboutContactEmailValue,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.privacy_tip_outlined, size: 22),
                        title: Text(l10n.aboutPrivacyPolicy, style: const TextStyle(fontSize: 15)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                        onTap: () => GoRouter.of(context).push(AppRouter.privacyPolicy),
                      ),
                      ListTile(
                        leading: const Icon(Icons.description_outlined, size: 22),
                        title: Text(l10n.aboutUserAgreement, style: const TextStyle(fontSize: 15)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                        onTap: () => GoRouter.of(context).push(AppRouter.userAgreement),
                      ),
                    ],
                  ).toList(),
                ),
              ),
              Spacer(flex: 1),

              // ── Copyright + Platform (bottom) ────────────────────────────
              Text(
                l10n.aboutCopyRight,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${Platform.isAndroid ? 'Android' : 'iOS'} · Build $_buildNumber',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
