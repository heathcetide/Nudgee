/// Agent session state — tracks the lifecycle of a single Agent run.
///
/// Used by [CheckpointManager] for crash recovery.
class AgentSession {
  /// Unique session ID.
  final String id;

  /// Which Agent ran.
  final String agentId;

  /// Which user initiated the run.
  final String userId;

  /// Associated chat conversation ID (for persistence).
  final String conversationId;

  /// Current lifecycle status.
  final AgentSessionStatus status;

  /// The user's original input that started this session.
  final String input;

  /// The final reply (set when status is completed).
  final String? finalReply;

  /// Total steps executed.
  final int totalSteps;

  /// Total tokens consumed.
  final int totalTokens;

  /// When the session started.
  final DateTime startedAt;

  /// When the session completed (null if still running).
  final DateTime? completedAt;

  /// ID of the last checkpoint saved.
  final String? lastCheckpointId;

  /// Creates an [AgentSession].
  const AgentSession({
    required this.id,
    required this.agentId,
    required this.userId,
    required this.conversationId,
    required this.status,
    required this.input,
    required this.startedAt,
    this.finalReply,
    this.totalSteps = 0,
    this.totalTokens = 0,
    this.completedAt,
    this.lastCheckpointId,
  });

  /// Creates a copy with updated fields.
  AgentSession copyWith({
    String? finalReply,
    AgentSessionStatus? status,
    int? totalSteps,
    int? totalTokens,
    DateTime? completedAt,
    String? lastCheckpointId,
  }) =>
      AgentSession(
        id: id,
        agentId: agentId,
        userId: userId,
        conversationId: conversationId,
        status: status ?? this.status,
        input: input,
        startedAt: startedAt,
        finalReply: finalReply ?? this.finalReply,
        totalSteps: totalSteps ?? this.totalSteps,
        totalTokens: totalTokens ?? this.totalTokens,
        completedAt: completedAt ?? this.completedAt,
        lastCheckpointId: lastCheckpointId ?? this.lastCheckpointId,
      );

  /// Whether this session is still in progress.
  bool get isRunning => status == AgentSessionStatus.running;

  /// Whether this session can be resumed.
  bool get canResume =>
      status == AgentSessionStatus.running ||
      status == AgentSessionStatus.paused ||
      status == AgentSessionStatus.crashed;

  @override
  String toString() => 'AgentSession($id, agent=$agentId, status=$status)';
}

/// Session lifecycle status.
enum AgentSessionStatus {
  /// Currently executing.
  running,

  /// Paused (e.g. app went to background).
  paused,

  /// Completed successfully.
  completed,

  /// Aborted by user.
  aborted,

  /// Crashed (app killed mid-run).
  crashed,
}
