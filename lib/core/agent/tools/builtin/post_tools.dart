import 'package:nudgee/core/agent/tools/agent_tool.dart';
import 'package:nudgee/core/agent/tools/tool_result.dart';
import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/services/post_service.dart';
import 'package:nudgee/core/services/user_storage_service.dart';

/// Tool: post.create
///
/// Creates a new social post. The LLM should provide the content text.
/// Images are not supported via this tool (text-only posts).
///
/// Mutation tool — requires confirmation.
class PostCreateTool extends AgentTool {
  @override
  String get name => 'post.create';

  @override
  String get description =>
      'Create a new social post (text only). The post will be published '
      'to the user\'s feed with their name and avatar. '
      'Use this when the user asks to share something, post an update, '
      'or publish content.';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'content': {
            'type': 'string',
            'description': 'The text content of the post',
          },
        },
        'required': ['content'],
      };

  @override
  bool get isMutation => true;

  @override
  bool get requiresConfirmation => true;

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final content = args['content'] as String?;
    if (content == null || content.isEmpty) {
      return const ToolResult.error('Missing required field: content');
    }

    try {
      final userStorage = sl<UserStorageService>();
      final profile = userStorage.getProfile();
      final userId = await userStorage.getUserId() ?? 'agent';
      final userName = profile?['name'] as String? ?? 'User';
      final avatar = profile?['avatar'] as String? ?? '';

      final post = PostItem(
        id: 'post_${DateTime.now().millisecondsSinceEpoch}',
        posterUid: userId,
        posterName: userName,
        posterAvatar: avatar,
        content: content,
        images: const [],
        time: DateTime.now(),
      );

      final service = sl<PostService>();
      await service.addPost(post);

      return ToolResult.success(
          'Post created successfully. Content: "${_truncate(content, 80)}"');
    } catch (e) {
      return ToolResult.error('Failed to create post: $e');
    }
  }

  String _truncate(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}...';
}

/// Tool: post.query
///
/// Queries recent posts from the user's feed.
/// Read-only tool.
class PostQueryTool extends AgentTool {
  @override
  String get name => 'post.query';

  @override
  String get description =>
      'Query recent posts from the user\'s social feed. '
      'Returns a list of posts with author, content, likes, and comments. '
      'Use this to check what\'s new or to find specific posts.';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'limit': {
            'type': 'integer',
            'description': 'Maximum number of posts to return (default 5, max 20)',
          },
        },
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    try {
      final service = sl<PostService>();
      final posts = service.posts;
      final limit = (args['limit'] as int?)?.clamp(1, 20) ?? 5;

      if (posts.isEmpty) {
        return const ToolResult.success('No posts found in the feed.');
      }

      final recent = posts.take(limit).toList();
      final lines = recent.asMap().entries.map((entry) {
        final i = entry.key;
        final p = entry.value;
        return '${i + 1}. [${p.id}] ${p.posterName}: '
            '"${_truncate(p.content, 60)}" '
            '(${p.likeCount} likes, ${p.commentCount} comments)';
      }).join('\n');

      return ToolResult.success(
          'Recent ${recent.length} post${recent.length > 1 ? "s" : ""}:\n$lines');
    } catch (e) {
      return ToolResult.error('Failed to query posts: $e');
    }
  }

  String _truncate(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}...';
}

/// Tool: post.like
///
/// Likes or unlikes a post by ID.
/// Mutation tool — requires confirmation.
class PostLikeTool extends AgentTool {
  @override
  String get name => 'post.like';

  @override
  String get description =>
      'Like or unlike a social post. Provide the post ID. '
      'If the post is already liked, it will be unliked.';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'postId': {
            'type': 'string',
            'description': 'The ID of the post to like/unlike',
          },
        },
        'required': ['postId'],
      };

  @override
  bool get isMutation => true;

  @override
  bool get requiresConfirmation => true;

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final postId = args['postId'] as String?;
    if (postId == null || postId.isEmpty) {
      return const ToolResult.error('Missing required field: postId');
    }

    try {
      final service = sl<PostService>();
      final post = service.posts.where((p) => p.id == postId).firstOrNull;

      if (post == null) {
        return ToolResult.error('Post not found: $postId');
      }

      final wasLiked = post.isLiked;
      final userStorage = sl<UserStorageService>();
      final userId = await userStorage.getUserId() ?? 'agent';
      final userName = userStorage.getProfile()?['name'] as String? ?? 'User';

      await service.toggleLike(postId, userId, userName);

      return ToolResult.success(
          wasLiked
              ? 'Unliked post: "${_truncate(post.content, 60)}"'
              : 'Liked post: "${_truncate(post.content, 60)}"');
    } catch (e) {
      return ToolResult.error('Failed to toggle like: $e');
    }
  }

  String _truncate(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}...';
}
