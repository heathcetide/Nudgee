import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nudgee/core/agent/agent_session.dart';
import 'package:nudgee/core/agent/providers/llm_client.dart';

/// Checkpoint manager — persists agent session state for crash recovery.
///
/// Saves [Checkpoint]s at regular intervals during an agent run. If the
/// app crashes or is killed mid-run, the checkpoint can be loaded on next
/// startup to resume the session (or at least inform the user what happened).
///
/// Storage: SharedPreferences (key-value, synchronous read).
/// For larger session transcripts, the messages are truncated to the last
/// N messages to keep the checkpoint lightweight.
class CheckpointManager {
  static const _prefix = 'agent_checkpoint_';
  static const _sessionIndexKey = 'agent_checkpoint_sessions';
  static const _maxCheckpointsPerSession = 5;
  static const _maxMessagesToStore = 20;

  /// Creates a new checkpoint for [session] with the current [messages]
  /// and [stepCount].
  ///
  /// Returns the created [Checkpoint].
  Future<Checkpoint> save({
    required AgentSession session,
    required List<LlmMessage> messages,
    required int stepCount,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final checkpointId =
        'ckpt_${session.id}_${DateTime.now().millisecondsSinceEpoch}';

    // Truncate messages to keep checkpoint lightweight
    final truncatedMessages = messages.length > _maxMessagesToStore
        ? messages.sublist(messages.length - _maxMessagesToStore)
        : messages;

    final checkpoint = Checkpoint(
      id: checkpointId,
      sessionId: session.id,
      agentId: session.agentId,
      stepCount: stepCount,
      messages: truncatedMessages,
      savedAt: DateTime.now(),
    );

    await prefs.setString(
      '$_prefix$checkpointId',
      jsonEncode(checkpoint.toJson()),
    );

    // Update session index
    final sessionCheckpoints =
        _decodeList(prefs.getString('$_prefix${session.id}_list'));
    sessionCheckpoints.add(checkpointId);
    // Keep only the latest N checkpoints
    while (sessionCheckpoints.length > _maxCheckpointsPerSession) {
      final oldId = sessionCheckpoints.removeAt(0);
      await prefs.remove('$_prefix$oldId');
    }
    await prefs.setString(
      '$_prefix${session.id}_list',
      jsonEncode(sessionCheckpoints),
    );

    // Update global session index
    final allSessions = _decodeList(prefs.getString(_sessionIndexKey));
    if (!allSessions.contains(session.id)) {
      allSessions.add(session.id);
      await prefs.setString(_sessionIndexKey, jsonEncode(allSessions));
    }

    debugPrint('[CheckpointManager] saved checkpoint $checkpointId '
        '(step=$stepCount, ${truncatedMessages.length} messages)');
    return checkpoint;
  }

  /// Loads the latest checkpoint for [sessionId].
  ///
  /// Returns null if no checkpoint exists.
  Future<Checkpoint?> loadLatest(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = _decodeList(prefs.getString('$_prefix${sessionId}_list'));
    if (list.isEmpty) return null;

    final latestId = list.last;
    final json = prefs.getString('$_prefix$latestId');
    if (json == null) return null;

    try {
      return Checkpoint.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[CheckpointManager] loadLatest error: $e');
      return null;
    }
  }

  /// Loads all checkpoints for [sessionId], ordered oldest to newest.
  Future<List<Checkpoint>> loadAll(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = _decodeList(prefs.getString('$_prefix${sessionId}_list'));
    final checkpoints = <Checkpoint>[];

    for (final id in list) {
      final json = prefs.getString('$_prefix$id');
      if (json == null) continue;
      try {
        checkpoints.add(Checkpoint.fromJson(jsonDecode(json) as Map<String, dynamic>));
      } catch (_) {}
    }

    return checkpoints;
  }

  /// Returns all session IDs that have checkpoints.
  Future<List<String>> allSessionIds() async {
    final prefs = await SharedPreferences.getInstance();
    return _decodeList(prefs.getString(_sessionIndexKey));
  }

  /// Returns all crashed/incomplete sessions (sessions that have checkpoints
  /// but were never marked as completed).
  ///
  /// Call this on app startup to find sessions that need recovery.
  Future<List<Checkpoint>> findCrashedSessions() async {
    final sessionIds = await allSessionIds();
    final crashed = <Checkpoint>[];

    for (final sessionId in sessionIds) {
      final latest = await loadLatest(sessionId);
      if (latest != null) {
        crashed.add(latest);
      }
    }

    return crashed;
  }

  /// Marks a session as completed, removing its checkpoints.
  Future<void> markCompleted(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = _decodeList(prefs.getString('$_prefix${sessionId}_list'));

    for (final id in list) {
      await prefs.remove('$_prefix$id');
    }
    await prefs.remove('$_prefix${sessionId}_list');

    final allSessions = _decodeList(prefs.getString(_sessionIndexKey));
    allSessions.remove(sessionId);
    await prefs.setString(_sessionIndexKey, jsonEncode(allSessions));

    debugPrint('[CheckpointManager] marked session $sessionId as completed');
  }

  /// Clears all checkpoints (for debugging/reset).
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionIds = _decodeList(prefs.getString(_sessionIndexKey));

    for (final sessionId in sessionIds) {
      final list = _decodeList(prefs.getString('$_prefix${sessionId}_list'));
      for (final id in list) {
        await prefs.remove('$_prefix$id');
      }
      await prefs.remove('$_prefix${sessionId}_list');
    }
    await prefs.remove(_sessionIndexKey);
  }

  List<String> _decodeList(String? json) {
    if (json == null) return [];
    try {
      final decoded = jsonDecode(json) as List;
      return decoded.map((e) => e as String).toList();
    } catch (_) {
      return [];
    }
  }
}

/// A checkpoint — a snapshot of an agent run at a point in time.
class Checkpoint {
  /// Unique checkpoint ID.
  final String id;

  /// Session ID this checkpoint belongs to.
  final String sessionId;

  /// Agent ID that was running.
  final String agentId;

  /// Step count at the time of checkpoint.
  final int stepCount;

  /// Conversation messages (truncated to last N).
  final List<LlmMessage> messages;

  /// When the checkpoint was saved.
  final DateTime savedAt;

  const Checkpoint({
    required this.id,
    required this.sessionId,
    required this.agentId,
    required this.stepCount,
    required this.messages,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'sessionId': sessionId,
        'agentId': agentId,
        'stepCount': stepCount,
        'messages': messages.map(_messageToJson).toList(),
        'savedAt': savedAt.toIso8601String(),
      };

  factory Checkpoint.fromJson(Map<String, dynamic> json) => Checkpoint(
        id: json['id'] as String,
        sessionId: json['sessionId'] as String,
        agentId: json['agentId'] as String,
        stepCount: json['stepCount'] as int? ?? 0,
        messages: (json['messages'] as List<dynamic>?)
                ?.map((m) => _messageFromJson(m as Map<String, dynamic>))
                .toList() ??
            const [],
        savedAt: DateTime.parse(json['savedAt'] as String),
      );

  @override
  String toString() =>
      'Checkpoint($id, session=$sessionId, step=$stepCount, msgs=${messages.length})';
}

Map<String, dynamic> _messageToJson(LlmMessage msg) => {
      'role': msg.role,
      if (msg.content != null) 'content': msg.content,
      if (msg.toolCallId != null) 'toolCallId': msg.toolCallId,
      if (msg.name != null) 'name': msg.name,
      if (msg.isError != null) 'isError': msg.isError,
      if (msg.toolCalls != null)
        'toolCalls': msg.toolCalls!
            .map((tc) => {
                  'id': tc.id,
                  'name': tc.name,
                  'arguments': tc.arguments,
                })
            .toList(),
    };

LlmMessage _messageFromJson(Map<String, dynamic> json) {
  final toolCallsRaw = json['toolCalls'] as List<dynamic>?;
  final toolCalls = toolCallsRaw
      ?.map((tc) => ToolCall(
            id: tc['id'] as String,
            name: tc['name'] as String,
            arguments: Map<String, dynamic>.from(tc['arguments'] as Map),
          ))
      .toList();

  return LlmMessage(
    role: json['role'] as String,
    content: json['content'] as String?,
    toolCalls: toolCalls,
    toolCallId: json['toolCallId'] as String?,
    name: json['name'] as String?,
    isError: json['isError'] as bool?,
  );
}
