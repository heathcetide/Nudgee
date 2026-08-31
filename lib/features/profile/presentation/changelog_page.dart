import 'package:flutter/material.dart';

import 'package:nudgee/core/extensions/context_extensions.dart';
import 'package:nudgee/features/common/widgets/page_scaffold.dart';

/// Changelog page — displays version history in a scrollable list.
class ChangelogPage extends StatelessWidget {
  const ChangelogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return PageScaffold(
      title: Text(l10n.aboutChangelogTitle),
      leading: getPopLeading(context),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // v1.0.0
          _VersionCard(
            version: 'v1.0.0',
            date: '2024',
            items: l10n.aboutChangelogContent.split('\n').skip(1).toList(),
            theme: theme,
          ),
        ],
      ),
    );
  }
}

class _VersionCard extends StatelessWidget {
  final String version;
  final String date;
  final List<String> items;
  final ThemeData theme;

  const _VersionCard({
    required this.version,
    required this.date,
    required this.items,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  version,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  date,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.replaceAll('• ', ''),
                          style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
