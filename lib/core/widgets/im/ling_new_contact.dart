import 'package:flutter/material.dart';

import 'package:nudgee/core/constants/app_constants.dart';
import 'package:nudgee/core/models/im/im.dart';
import 'package:nudgee/core/widgets/feedback/ling_avatar.dart';
import 'package:nudgee/core/widgets/feedback/ling_empty_state.dart';
import 'package:nudgee/core/widgets/buttons/ling_button.dart';

/// Status of a contact application (friend request).
enum LingContactApplicationStatus {
  pending,
  accepted,
  rejected,
}

/// A friend request / contact application.
class LingContactApplication {
  /// The user who sent the request.
  final LingChatUser applicant;

  /// The message attached to the request.
  final String message;

  /// When the request was created.
  final DateTime createdAt;

  /// Current status of the request.
  final LingContactApplicationStatus status;

  const LingContactApplication({
    required this.applicant,
    required this.message,
    required this.createdAt,
    this.status = LingContactApplicationStatus.pending,
  });

  LingContactApplication copyWith({
    LingChatUser? applicant,
    String? message,
    DateTime? createdAt,
    LingContactApplicationStatus? status,
  }) {
    return LingContactApplication(
      applicant: applicant ?? this.applicant,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }

  bool get isPending => status == LingContactApplicationStatus.pending;
  bool get isAccepted => status == LingContactApplicationStatus.accepted;
  bool get isRejected => status == LingContactApplicationStatus.rejected;
}

/// New contact / friend request list.
///
/// Shows a header with the unread (pending) count, followed by a list of
/// applications. Each row displays the applicant's avatar, name, request
/// message, timestamp, and accept/reject buttons (when pending).
class LingNewContact extends StatelessWidget {
  final List<LingContactApplication> applications;
  final ValueChanged<LingContactApplication> onAccept;
  final ValueChanged<LingContactApplication> onReject;

  const LingNewContact({
    super.key,
    required this.applications,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pendingCount =
        applications.where((a) => a.isPending).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header with unread count ──
        if (applications.isNotEmpty)
          Container(
            color: theme.colorScheme.surface,
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingMd,
              vertical: AppConstants.spacingSm + 2,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_active_outlined,
                  size: 18,
                  color: pendingCount > 0
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppConstants.spacingSm),
                Expanded(
                  child: Text(
                    pendingCount > 0
                        ? '$pendingCount 条新的好友申请'
                        : '暂无新的好友申请',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: pendingCount > 0
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight:
                          pendingCount > 0 ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                if (pendingCount > 0)
                  Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      pendingCount > 99 ? '99+' : '$pendingCount',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onError,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        // ── Application list ──
        if (applications.isEmpty)
          const Expanded(
            child: LingEmptyState(
              icon: Icons.person_add_alt_outlined,
              title: '暂无好友申请',
              message: '新的好友申请会显示在这里',
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: AppConstants.spacingLg),
              itemCount: applications.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: AppConstants.spacingMd + LingAvatarSize.lg.value,
                color: theme.colorScheme.outlineVariant,
              ),
              itemBuilder: (context, index) {
                final app = applications[index];
                return _ApplicationItem(
                  application: app,
                  onAccept: () => onAccept(app),
                  onReject: () => onReject(app),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// A single application row for [LingNewContact].
class _ApplicationItem extends StatelessWidget {
  final LingContactApplication application;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _ApplicationItem({
    required this.application,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = application;

    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingSm + 2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LingAvatar(
            imageUrl: app.applicant.avatarUrl,
            name: app.applicant.name,
            size: LingAvatarSize.lg,
          ),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + time
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        app.applicant.name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _formatTime(app.createdAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Request message
                Text(
                  app.message.isNotEmpty ? app.message : '请求添加你为好友',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppConstants.spacingSm),
                // Actions / status
                if (app.isPending)
                  Row(
                    children: [
                      LingButton(
                        label: '同意',
                        size: LingButtonSize.small,
                        onPressed: onAccept,
                      ),
                      const SizedBox(width: AppConstants.spacingSm),
                      LingButton(
                        label: '拒绝',
                        variant: LingButtonVariant.outlined,
                        size: LingButtonSize.small,
                        onPressed: onReject,
                      ),
                    ],
                  )
                else
                  _StatusChip(status: app.status),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    if (time.year == now.year &&
        time.month == now.month &&
        time.day == now.day) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
    if (time.year == now.year && time.month == now.month && time.day == now.day - 1) {
      return '昨天';
    }
    if (time.year == now.year) {
      return '${time.month}/${time.day}';
    }
    return '${time.year}/${time.month}/${time.day}';
  }
}

/// A small status indicator chip for processed applications.
class _StatusChip extends StatelessWidget {
  final LingContactApplicationStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = switch (status) {
      LingContactApplicationStatus.accepted => ('已同意', theme.colorScheme.primary),
      LingContactApplicationStatus.rejected => ('已拒绝', theme.colorScheme.outline),
      LingContactApplicationStatus.pending => ('待处理', theme.colorScheme.tertiary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
