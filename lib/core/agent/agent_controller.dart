import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:nudgee/core/agent/agent.dart';

/// Controller for an agent run — supports start, pause, resume, cancel.
///
/// Wraps [AgentCore.run] and provides:
/// - **Cancel**: abort the current run (kills the stream subscription)
/// - **Pause/Resume**: temporarily stop processing events
/// - **Replay**: re-run with the same input
/// - **State**: observable running state (idle/running/paused/done/error)
///
/// Usage:
/// ```dart
/// final controller = AgentController(agent: agentCore);
/// controller.start(userInput: 'Hello');
///
/// // Later:
/// controller.cancel();
///
/// // Observe state:
/// controller.state.addListener(() => print(controller.state.value));
/// ```
class AgentController extends ChangeNotifier {
  /// The agent core to run.
  final AgentCore agent;

  /// The current run state.
  final ValueNotifier<AgentRunState> state =
      ValueNotifier<AgentRunState>(AgentRunState.idle);

  /// The current run's events (accumulated).
  final List<AgentEvent> events = [];

  /// The current run's stats (set on done).
  AgentRunStats? stats;

  /// The final reply (set on done).
  String? finalReply;

  /// The last error message (set on error).
  String? error;

  StreamSubscription<AgentEvent>? _sub;
  bool _paused = false;
  final _pendingEvents = <AgentEvent>[];

  /// Creates an [AgentController].
  AgentController({required this.agent});

  /// Whether the controller is currently running.
  bool get isRunning => state.value == AgentRunState.running;

  /// Whether the controller is paused.
  bool get isPaused => state.value == AgentRunState.paused;

  /// Whether the run completed successfully.
  bool get isDone => state.value == AgentRunState.done;

  /// Whether the run ended with an error.
  bool get isError => state.value == AgentRunState.error;

  /// Starts a new agent run with [userInput].
  ///
  /// If a run is already in progress, it will be cancelled first.
  void start({
    required String userInput,
    String? extraSystemContext,
  }) {
    cancel();
    _reset();

    state.value = AgentRunState.running;
    notifyListeners();

    _sub = agent
        .run(
          userInput: userInput,
          extraSystemContext: extraSystemContext,
        )
        .listen(
          _handleEvent,
          onError: (e) {
            state.value = AgentRunState.error;
            error = e.toString();
            notifyListeners();
          },
          onDone: () {
            if (state.value == AgentRunState.running) {
              // Stream ended without DoneEvent — treat as done
              state.value = AgentRunState.done;
              notifyListeners();
            }
          },
          cancelOnError: true,
        );
  }

  /// Pauses event processing. Events are buffered and flushed on resume.
  void pause() {
    if (state.value != AgentRunState.running) return;
    _paused = true;
    state.value = AgentRunState.paused;
    notifyListeners();
  }

  /// Resumes event processing and flushes buffered events.
  void resume() {
    if (state.value != AgentRunState.paused) return;
    _paused = false;
    state.value = AgentRunState.running;
    // Flush pending events
    for (final event in _pendingEvents) {
      _processEvent(event);
    }
    _pendingEvents.clear();
    notifyListeners();
  }

  /// Cancels the current run.
  void cancel() {
    _sub?.cancel();
    _sub = null;
    _pendingEvents.clear();
    if (state.value == AgentRunState.running ||
        state.value == AgentRunState.paused) {
      state.value = AgentRunState.cancelled;
      notifyListeners();
    }
  }

  /// Resets the controller to idle state.
  void reset() {
    cancel();
    _reset();
    state.value = AgentRunState.idle;
    notifyListeners();
  }

  void _reset() {
    events.clear();
    stats = null;
    finalReply = null;
    error = null;
    _paused = false;
    _pendingEvents.clear();
  }

  void _handleEvent(AgentEvent event) {
    if (_paused) {
      _pendingEvents.add(event);
      return;
    }
    _processEvent(event);
  }

  void _processEvent(AgentEvent event) {
    events.add(event);

    switch (event) {
      case DoneEvent():
        stats = event.stats;
        finalReply = event.finalReply;
        state.value = AgentRunState.done;
        notifyListeners();

      case ErrorEvent():
        error = event.message;
        state.value = AgentRunState.error;
        notifyListeners();

      case LoopWarningEvent():
        // Could surface as a warning to the user
        debugPrint('[AgentController] Loop warning at step ${event.stepCount}');

      default:
        // Other events (thinking, content, tool calls) — just notify listeners
        notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    state.dispose();
    super.dispose();
  }
}

/// The state of an agent run.
enum AgentRunState {
  /// Not started.
  idle,

  /// Currently running.
  running,

  /// Paused (events buffered).
  paused,

  /// Completed successfully.
  done,

  /// Ended with an error.
  error,

  /// Cancelled by the user.
  cancelled,
}
