import 'package:flutter/material.dart';

/// Timeline item data.
class LingTimelineItem {
  final String title;
  final String? subtitle;
  final DateTime? time;
  final IconData? icon;
  final Color? color;
  final Widget? trailing;
  final bool isHighlighted;

  const LingTimelineItem({
    required this.title,
    this.subtitle,
    this.time,
    this.icon,
    this.color,
    this.trailing,
    this.isHighlighted = false,
  });
}

/// A vertical timeline component.
///
/// Displays a sequence of events with connecting lines and markers.
/// Useful for activity logs, history, and step progress.
class LingTimeline extends StatelessWidget {
  final List<LingTimelineItem> items;
  final double iconSize;
  final double lineWidth;
  final double spacing;
  final Color? lineColor;
  final Color? defaultIconColor;
  final String Function(DateTime)? timeFormatter;

  const LingTimeline({
    super.key,
    required this.items,
    this.iconSize = 28,
    this.lineWidth = 2,
    this.spacing = 16,
    this.lineColor,
    this.defaultIconColor,
    this.timeFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final line = lineColor ?? theme.colorScheme.outlineVariant;
    final defaultIcon = defaultIconColor ?? theme.colorScheme.primary;

    return Column(
      children: List.generate(items.length, (index) {
        final item = items[index];
        final isLast = index == items.length - 1;
        final itemColor = item.color ?? (item.isHighlighted ? theme.colorScheme.primary : defaultIcon);

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Marker + line
              SizedBox(
                width: iconSize + 8,
                child: Column(
                  children: [
                    Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        color: item.isHighlighted ? itemColor : itemColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: itemColor, width: 2),
                      ),
                      child: Icon(
                        item.icon ?? Icons.circle,
                        size: iconSize * 0.5,
                        color: item.isHighlighted ? theme.colorScheme.onPrimary : itemColor,
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: lineWidth,
                          color: line,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                        ),
                      ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : spacing, top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: item.isHighlighted ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                            if (item.subtitle != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  item.subtitle!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            if (item.time != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  timeFormatter?.call(item.time!) ??
                                      _defaultTimeFormat(item.time!),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (item.trailing != null) item.trailing!,
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  String _defaultTimeFormat(DateTime time) {
    return '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
