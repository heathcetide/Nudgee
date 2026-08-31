import 'package:flutter/material.dart';

import 'package:nudgee/app/theme/app_colors.dart';
import 'package:nudgee/core/constants/app_constants.dart';

/// A message report dialog.
///
/// Shows a list of report reasons, an optional supplementary description
/// input, and a submit button. Use [LingMessageReport.show] to display
/// it as a dialog.
class LingMessageReport extends StatefulWidget {
  /// Called with the selected reason and optional description.
  final void Function(String reason, String? description) onSubmit;

  /// Title shown in the dialog. Defaults to "举报消息".
  final String title;

  const LingMessageReport({
    super.key,
    required this.onSubmit,
    this.title = '举报消息',
  });

  /// Convenience method to show the report dialog.
  static Future<void> show(
    BuildContext context, {
    required void Function(String reason, String? description) onSubmit,
    String title = '举报消息',
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => LingMessageReport(
        onSubmit: onSubmit,
        title: title,
      ),
    );
  }

  @override
  State<LingMessageReport> createState() => _LingMessageReportState();
}

class _LingMessageReportState extends State<LingMessageReport> {
  static const List<String> _reasons = [
    '垃圾广告',
    '骚扰辱骂',
    '色情低俗',
    '欺诈',
    '违法',
    '其他',
  ];

  int _selectedReason = -1;
  final TextEditingController _descController = TextEditingController();

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_selectedReason == -1) return;
    final reason = _reasons[_selectedReason];
    final desc = _descController.text.trim();
    widget.onSubmit(reason, desc.isEmpty ? null : desc);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(widget.title),
      titlePadding: const EdgeInsets.fromLTRB(
        AppConstants.spacingLg,
        AppConstants.spacingMd,
        AppConstants.spacingLg,
        AppConstants.spacingSm,
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        AppConstants.spacingLg,
        AppConstants.spacingXs,
        AppConstants.spacingLg,
        0,
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Reason list
              ...List.generate(_reasons.length, (index) {
                return RadioListTile<int>(
                  value: index,
                  groupValue: _selectedReason,
                  title: Text(_reasons[index]),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() => _selectedReason = v ?? -1),
                );
              }),
              const SizedBox(height: AppConstants.spacingSm),
              // Description input
              Text(
                '补充说明（可选）',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppConstants.spacingXs),
              TextField(
                controller: _descController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: '请输入补充说明...',
                  hintStyle: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConstants.radiusMd,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingSm + 2,
                    vertical: AppConstants.spacingSm,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            '取消',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        TextButton(
          onPressed: _selectedReason == -1 ? null : _submit,
          child: const Text(
            '提交',
            style: TextStyle(color: AppColors.primary),
          ),
        ),
      ],
    );
  }
}
