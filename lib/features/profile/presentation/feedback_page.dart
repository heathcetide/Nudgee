import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nudgee/core/extensions/context_extensions.dart';
import 'package:nudgee/features/common/widgets/page_scaffold.dart';

/// Feedback page — lets users submit bug reports, feature requests, etc.
///
/// Currently sends feedback via email (mailto:) to admin@lingecho.com.
/// In the future this could be replaced with a backend API submission.
class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  String _selectedType = '';
  final _contentController = TextEditingController();
  final _contactController = TextEditingController();

  @override
  void dispose() {
    _contentController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      SmartDialog.showNotify(msg: l10n.feedbackEmpty, notifyType: NotifyType.error);
      return;
    }

    SmartDialog.showLoading(msg: l10n.feedbackSubmitting);
    try {
      final subject = l10n.feedbackEmailSubject;
      final body = StringBuffer();
      body.writeln('${l10n.feedbackType}: $_selectedType');
      body.writeln('${l10n.feedbackContent}:');
      body.writeln(content);
      if (_contactController.text.isNotEmpty) {
        body.writeln('${l10n.feedbackContact}: ${_contactController.text}');
      }

      final uri = Uri(
        scheme: 'mailto',
        path: 'admin@lingecho.com',
        query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body.toString())}',
      );

      SmartDialog.dismiss();
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // Fallback: copy to clipboard
        SmartDialog.showNotify(
          msg: '${l10n.aboutContactEmailValue}: admin@lingecho.com',
          notifyType: NotifyType.alert,
        );
      }
      if (mounted) {
        SmartDialog.showNotify(msg: l10n.feedbackSuccess, notifyType: NotifyType.success);
        Navigator.maybePop(context);
      }
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showNotify(msg: '$e', notifyType: NotifyType.failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    final feedbackTypes = [
      l10n.feedbackTypeBug,
      l10n.feedbackTypeFeature,
      l10n.feedbackTypeOther,
    ];
    if (_selectedType.isEmpty) _selectedType = feedbackTypes.first;

    return PageScaffold(
      title: Text(l10n.feedbackTitle),
      leading: getPopLeading(context),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Feedback Type ─────────────────────────────────────────────
            Text(l10n.feedbackType, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: feedbackTypes.map((type) {
                final selected = type == _selectedType;
                return ChoiceChip(
                  label: Text(type),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedType = type),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ── Content ───────────────────────────────────────────────────
            Text(l10n.feedbackContent, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _contentController,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: l10n.feedbackContentHint,
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),

            // ── Contact ───────────────────────────────────────────────────
            Text(l10n.feedbackContact, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _contactController,
              decoration: InputDecoration(
                hintText: l10n.feedbackContactHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.alternate_email),
              ),
            ),
            const SizedBox(height: 32),

            // ── Submit ────────────────────────────────────────────────────
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.send),
              label: Text(l10n.feedbackSubmit),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
