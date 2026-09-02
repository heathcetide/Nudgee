import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:nudgee/app/router/app_router.dart';
import 'package:nudgee/core/extensions/context_extensions.dart';
import 'package:nudgee/features/common/widgets/avatar.dart';
import 'package:nudgee/features/common/widgets/page_scaffold.dart';

/// 点赞列表页面。
///
/// 显示一条帖子的所有点赞用户，点击用户可跳转到其个人主页。
class LikeListPage extends StatefulWidget {
  /// 帖子 ID，用于从 PostService 获取点赞列表。
  final String postId;

  /// 点赞总数（标题展示用）。
  final int likeCount;

  /// 当前用户 ID（用于标记"我"）。
  final String? currentUserId;

  /// 点赞用户列表，每项包含 uid / name / avatar。
  final List<Map<String, dynamic>> likeList;

  const LikeListPage({
    super.key,
    required this.postId,
    required this.likeCount,
    this.currentUserId,
    required this.likeList,
  });

  @override
  State<LikeListPage> createState() => _LikeListPageState();
}

class _LikeListPageState extends State<LikeListPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return PageScaffold(
      title: Text('${widget.likeCount} 人点赞'),
      leading: getPopLeading(context),
      child: widget.likeList.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_border,
                      size: 48, color: theme.hintColor),
                  const SizedBox(height: 12),
                  Text(
                    '还没有人点赞',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              itemCount: widget.likeList.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 64,
                color: theme.dividerColor,
              ),
              itemBuilder: (context, index) {
                final user = widget.likeList[index];
                final name = user['name']?.toString() ?? '未知用户';
                final uid = user['uid']?.toString();
                final avatar = user['avatar']?.toString();
                final isMe =
                    uid != null && uid == widget.currentUserId;

                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: SizedBox(
                    width: 44,
                    height: 44,
                    child: Avatar(avatar,
                        name: name,
                        heroTag: 'like_${widget.postId}_$index'),
                  ),
                  title: Text(name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      )),
                  trailing: isMe
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '我',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : const Icon(Icons.chevron_right,
                          size: 20, color: Colors.grey),
                  onTap: () {
                    if (uid != null && uid.isNotEmpty && !isMe) {
                      GoRouter.of(context).pushNamed(
                        'personalHome',
                        queryParameters: {'userId': uid},
                      );
                    }
                  },
                );
              },
            ),
    );
  }
}
