import 'dart:math';

import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/extensions/context_extensions.dart';
import 'package:nudgee/core/services/auth_service.dart';
import 'package:nudgee/core/services/post_service.dart';
import 'package:nudgee/features/common/utils/functions.dart';
import 'package:nudgee/features/common/widgets/avatar.dart';
import 'package:nudgee/features/common/widgets/image_box.dart';
import 'package:nudgee/features/common/widgets/nine_slice_layout.dart';
import 'package:nudgee/features/common/widgets/page_scaffold.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:like_button/like_button.dart';

class CampusDiscover extends StatefulWidget {
  const CampusDiscover({super.key});

  @override
  State<CampusDiscover> createState() => _CampusDiscoverState();
}

class _CampusDiscoverState extends State<CampusDiscover> {
  List<Map<String, dynamic>> _posts = [];
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _initState();
  }

  void _initState() async {
    final postService = sl<PostService>();
    if (!_isListening) {
      _isListening = true;
      postService.addListener(_onPostsChanged);
    }
    await postService.init();
    if (mounted) _loadPosts();
    // Cloud sync is best-effort.
    postService.syncFromCloud().then((_) {
      if (mounted) _loadPosts();
    });
  }

  void _onPostsChanged() {
    _loadPosts();
  }

  void _loadPosts() {
    final postService = sl<PostService>();
    setState(() {
      _posts = postService.getPostsAsUIMap();
    });
  }

  @override
  void dispose() {
    sl<PostService>().removeListener(_onPostsChanged);
    super.dispose();
  }

  // ── Mock data fallback (used when no real posts) ──────────────────────
  List<Map<String, dynamic>> _generateMockPosts() {
    final images = [
      "https://cdn.lingecho.com/canvas/1/2026/08/e199bcb4-6419-40f2-9eea-46a56668fba1.png",
      "https://cdn.lingecho.com/canvas/1/2026/08/f464e4a1-d511-4607-93c3-bd7e4fbfcc3b.png",
    ];
    final avatar = "https://cdn.lingecho.com/avatars/1_1787150270.jpg";

    return List.generate(20, (index) {
      final rng = Random(index);
      final imgCount = rng.nextInt(3); // 0~2 张图
      return {
        "posterUid": 1000 + index,
        "posterName": _names[index % _names.length],
        "posterAvatar": avatar,
        "content": _contents[index % _contents.length],
        "time": DateTime.now().subtract(Duration(hours: index * 3 + 1)),
        "isLiked": rng.nextBool(),
        "likeCount": 10 + rng.nextInt(90),
        "commentCount": 3 + rng.nextInt(10),
        "displayLikeUserList": [
          for (int i = 0; i < 3 + rng.nextInt(4); i++)
            {"uid": 2000 + i, "name": "${_names[(index + i) % _names.length]}"},
        ],
        "imageList": [
          for (int i = 0; i < imgCount; i++) images[i % images.length],
        ],
        "displayCommentList": _generateComments(index),
      };
    });
  }

  List<Map<String, dynamic>> _generateComments(int seed) {
    final rng = Random(seed * 7 + 1);
    final count = 2 + rng.nextInt(3);
    return List.generate(count, (i) {
      final hasReply = i > 0 && rng.nextBool();
      return {
        "uid": 3000 + seed * 10 + i,
        "name": _names[(seed + i) % _names.length],
        "replyName": hasReply ? _names[(seed + i + 1) % _names.length] : null,
        "replyUid": hasReply ? 3000 + seed * 10 + i - 1 : null,
        "content": _comments[(seed + i) % _comments.length],
      };
    });
  }

  static const _names = [
    "小明同学", "阿强", "LingEcho", "校园达人", "课表君",
    "夜猫子", "图书馆常客", "食堂美食家", "运动健将", "文艺青年",
  ];

  static const _contents = [
    "今天的校园日落真的好美，分享给大家！夕阳洒在操场上，金灿灿的一片，太治愈了～",
    "图书馆新到的几本书推荐给大家，尤其是那本《深入理解计算机系统》，写得非常透彻。",
    "食堂二楼新出的麻辣香锅真的绝了，性价比超高，强烈推荐同学们去试试！",
    "期中考试复习进度如何？大家一起加油吧！感觉数据结构还是要多刷题才行。",
    "周末校园歌手大赛报名开始啦，有想一起组队的小伙伴吗？",
  ];

  static const _comments = [
    "说得太好了！",
    "我也想去试试",
    "求详细攻略",
    "哈哈哈哈太真实了",
    "同感同感",
    "这个真的不错",
    "已点赞已收藏",
    "下次一起去",
  ];

  /// 添加评论到指定帖子
  void _addComment(int postIndex, String name, String? replyName, dynamic replyUid, String content) {
    setState(() {
      final comments = _posts[postIndex]["displayCommentList"] as List;
      comments.add({
        "uid": '${DateTime.now().millisecondsSinceEpoch}',
        "name": name,
        "replyName": replyName,
        "replyUid": replyUid,
        "content": content,
      });
      _posts[postIndex]["commentCount"] = (_posts[postIndex]["commentCount"] as int) + 1;
    });
  }

  /// 弹出评论输入框
  Future<void> _showCommentInput(
    BuildContext context,
    int postIndex, {
    String? replyName,
    dynamic replyUid,
  }) async {
    final controller = TextEditingController();
    final hint = replyName != null ? "回复 $replyName" : "写评论...";

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            top: 16,
            left: 16,
            right: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(replyName != null ? "回复 $replyName" : "发表评论",
                      style: Theme.of(ctx).textTheme.titleMedium),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("取消"),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: () {
                      final text = controller.text.trim();
                      if (text.isNotEmpty) Navigator.pop(ctx, text);
                    },
                    child: const Text("发送"),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: hint,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      _addComment(postIndex, "我", replyName, replyUid, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PageScaffold(
      title: const Text("信息圈"),
      leading: const SizedBox(),
      child: _posts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.article_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant.withAlpha(80)),
                  const SizedBox(height: 16),
                  Text(
                    '还没有帖子，点击 + 发布第一条吧',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _posts.length,
              itemBuilder: (context, index) {
                final p = _posts[index];
                return SinglePosts(
                  key: ValueKey("post_${p['posterUid']}_${p['time']}"),
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
                  onCommentTap: () => _showCommentInput(context, index),
                  onReplyComment: (commentItem) => _showCommentInput(
                    context, index,
                    replyName: commentItem["name"],
                    replyUid: commentItem["uid"],
                  ),
                );
              },
            ),
    );
  }
}

class SinglePosts extends StatefulWidget {
  final dynamic posterUid;
  final String? posterName;
  final String? posterAvatar;
  final String? content;
  final DateTime? time;
  final bool? isLiked;
  final int? likeCount;
  final int? commentCount;
  final List<dynamic>? displayLikeUserList;
  final List<dynamic>? displayCommentList;
  final List<String>? imageList;
  final VoidCallback? onCommentTap;
  final void Function(Map<String, dynamic> commentItem)? onReplyComment;

  const SinglePosts({
    super.key,
    this.posterUid,
    this.posterName,
    this.posterAvatar,
    this.content,
    this.time,
    this.isLiked,
    this.likeCount,
    this.commentCount,
    this.displayLikeUserList,
    this.displayCommentList,
    this.imageList,
    this.onCommentTap,
    this.onReplyComment,
  });

  @override
  State<SinglePosts> createState() => _SinglePostsState();
}

class _SinglePostsState extends State<SinglePosts> {
  bool isLiked = false;
  int likeCount = 0;

  @override
  void initState() {
    isLiked = widget.isLiked ?? false;
    likeCount = widget.likeCount ?? 0;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      padding: const EdgeInsets.all(12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 39,
            height: 39,
            margin: const EdgeInsets.only(right: 12.0),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
            child: Avatar(widget.posterAvatar, name: widget.posterName),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.posterName!,
                    style: TextStyle(
                        fontSize: 17,
                        height: 1.35,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary)),
                Text(widget.content!,
                    style: const TextStyle(fontSize: 16, height: 1.28), maxLines: 30),
                widget.imageList == null || widget.imageList!.isEmpty
                    ? const SizedBox()
                    : Padding(
                        padding: const EdgeInsets.only(right: 6, top: 4, bottom: 0),
                        child: NineSliceLayout(urls: widget.imageList),
                      ),
                Padding(
                  padding: const EdgeInsets.only(top: 1, bottom: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        getChineseStringByDatetime(widget.time!),
                        style: TextStyle(fontSize: 14, color: Theme.of(context).hintColor),
                      ),
                      const Expanded(child: SizedBox()),
                      const SizedBox(width: 16),
                      LikeButton(
                        likeCount: likeCount,
                        isLiked: isLiked,
                        onTap: (liked) async {
                          setState(() => isLiked = !liked);
                          return !liked;
                        },
                        likeBuilder: (liked) {
                          return Icon(
                            AntDesign.heart_fill,
                            color: liked ? Colors.red : Theme.of(context).colorScheme.primary,
                          );
                        },
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: widget.onCommentTap,
                        child: Icon(EvaIcons.message_circle_outline,
                            color: Theme.of(context).colorScheme.primary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsetsDirectional.symmetric(vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: Theme.of(context).colorScheme.surfaceContainerHighest?.withAlpha(100) ??
                        Colors.grey[200]!,
                  ),
                  child: Column(
                    children: [
                      // 点赞列表
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(1.0),
                              child: Icon(AntDesign.heart_outline, size: 17),
                            ),
                            Expanded(
                              child: Text.rich(TextSpan(children: [
                                for (int i = 0; i < widget.displayLikeUserList!.length; i++)
                                  TextSpan(
                                    text:
                                        "${widget.displayLikeUserList![i]['name']}${i == widget.displayLikeUserList!.length - 1 ? '' : '，'}",
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        // 点击点赞用户
                                      },
                                    style: TextStyle(
                                        fontSize: 15,
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                        height: 1.3),
                                  ),
                                if (widget.displayLikeUserList!.length < widget.likeCount!)
                                  TextSpan(
                                      text: " 等${widget.likeCount}人点赞",
                                      style: const TextStyle(fontSize: 15, height: 1.3)),
                              ])),
                            ),
                          ],
                        ),
                      ),
                      // 评论列表
                      Container(
                        padding: const EdgeInsets.only(left: 6, right: 6, top: 4),
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: (() {
                            List<Widget> commentList = [];
                            for (var commentItem in widget.displayCommentList!) {
                              commentItem as Map<String, dynamic>;
                              if (commentItem['replyUid'] == null) {
                                commentList.add(
                                  GestureDetector(
                                    onTap: () => widget.onReplyComment?.call(commentItem),
                                    child: Text.rich(TextSpan(children: [
                                      TextSpan(
                                          text: commentItem['name'],
                                          style: TextStyle(
                                              fontSize: 15,
                                              color: Theme.of(context).colorScheme.primary,
                                              fontWeight: FontWeight.bold,
                                              height: 1.3)),
                                      TextSpan(
                                          text: ": ${commentItem['content']}",
                                          style: const TextStyle(fontSize: 15, height: 1.3)),
                                    ])),
                                  ),
                                );
                              } else {
                                commentList.add(
                                  GestureDetector(
                                    onTap: () => widget.onReplyComment?.call(commentItem),
                                    child: Text.rich(TextSpan(children: [
                                      TextSpan(
                                          text: commentItem['name'],
                                          style: TextStyle(
                                              fontSize: 15,
                                              color: Theme.of(context).colorScheme.primary,
                                              fontWeight: FontWeight.bold,
                                              height: 1.3)),
                                      const TextSpan(text: "@", style: TextStyle(fontSize: 15, height: 1.3)),
                                      TextSpan(
                                          text: commentItem['replyName'],
                                          style: TextStyle(
                                              fontSize: 15,
                                              color: Theme.of(context).colorScheme.primary,
                                              fontWeight: FontWeight.bold,
                                              height: 1.3)),
                                      TextSpan(
                                          text: "：${commentItem['content']}",
                                          style: const TextStyle(fontSize: 15, height: 1.3)),
                                    ])),
                                  ),
                                );
                              }
                            }
                            return commentList;
                          })(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
