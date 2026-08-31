import 'package:flutter/material.dart';

import 'package:nudgee/core/extensions/context_extensions.dart';
import 'package:nudgee/features/common/widgets/page_scaffold.dart';

/// Privacy policy page — displays the full privacy policy text.
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return PageScaffold(
      title: Text(l10n.privacyPolicyTitle),
      leading: getPopLeading(context),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(
          l10n.privacyPolicyContent,
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.8),
        ),
      ),
    );
  }
}
