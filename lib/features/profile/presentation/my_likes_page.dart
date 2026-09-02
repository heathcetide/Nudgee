import 'package:flutter/material.dart';

import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/extensions/context_extensions.dart';
import 'package:nudgee/core/services/auth_service.dart';
import 'package:nudgee/core/services/post_service.dart';
import 'package:nudgee/features/campus_forum/presentation/campus_discover.dart';
import 'package:nudgee/features/common/widgets/page_scaffold.dart';

/// 我的点赞页面。
///
/// 显示当前用户点赞过的所有帖子。
class MyLikesPage extends StatefulWidget {
  const MyLikesPage({super.key});

  @override
  State<MyLikesPage> createState() => _MyLikesPageState();
}

class _MyLikesPageState extends State<MyLikesPage> {
  List<Map<String, dynamic>> _posts = [];
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() async {
    final postService = sl<PostService>();
    if (!_isListening) {
      _isListening = true;
      postService.addListener(_onPostsChanged);
    }
    await postService.init();
    if (mounted) _loadPosts();
    postService.syncFromCloud().then((_) {
      if (mounted) _loadPosts();
    });
  }

  void _onPostsChanged() => _loadPosts();

  void _loadPosts() {
    final postService = sl<PostService>();
    final auth = sl<AuthService>();
    final currentUser = auth.currentUser.value;
    setState(() {
      _posts = postService.getLikedPostsAsUIMap();
      if (currentUser != null) {
        for (final post in _posts) {
          if (post['posterUid'] == currentUser.id) {
            post['posterName'] = currentUser.name;
            if (currentUser.avatar != null &&
                currentUser.avatar!.isNotEmpty) {
              post['posterAvatar'] = currentUser.avatar;
            }
          }
        }
      }
    });
  }

  @override
  void dispose() {
    sl<PostService>().removeListener(_onPostsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final auth = sl<AuthService>();
    final currentUser = auth.currentUser.value;

    return PageScaffold(
      title: Text(l10n.profileLikes),
      leading: getPopLeading(context),
      child: _posts.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_border,
                      size: 48, color: theme.hintColor),
                  const SizedBox(height: 12),
                  Text(
                    '还没有点赞过帖子',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _posts.length,
              itemBuilder: (context, index) {
                final p = _posts[index];
                return SinglePosts(
                  key: ValueKey("liked_post_${p['id']}_${p['time']}"),
                  postId: p["id"],
                  posterUid: p["posterUid"],
                  posterName: p["posterName"],
                  posterAvatar: p["posterAvatar"],
                  content: p["content"],
                  time: p["time"],
                  isLiked: p["isLiked"],
                  likeCount: p["likeCount"],
                  commentCount: p["commentCount"],
                  displayLikeUserList: p["displayLikeUserList"],
                  displayCommentList: p["displayCommentList"],
                  imageList: p["imageList"],
                  currentUserId: currentUser?.id,
                );
              },
            ),
    );
  }
}
