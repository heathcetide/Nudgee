/// States the [CircuitBreaker] can be in.
enum CircuitState { closed, open, halfOpen }

/// Exception thrown when the breaker is [CircuitState.open].
class CircuitOpenException implements Exception {
  final DateTime? retryAfter;

  const CircuitOpenException(this.retryAfter);

  @override
  String toString() =>
      'CircuitOpenException(retryAfter: $retryAfter)';
}

/// A simple circuit breaker for guarding network-bound operations.
///
/// - [CircuitState.closed]: requests flow normally.
/// - [CircuitState.open]: after [failureThreshold] consecutive failures the
///   breaker trips and all subsequent calls fail fast with
///   [CircuitOpenException] until [resetDuration] has elapsed.
/// - [CircuitState.halfOpen]: once the cool-down expires the next call is
///   treated as a probe — success closes the breaker, failure re-opens it.
class CircuitBreaker {
  final int failureThreshold;
  final Duration resetDuration;

  int _failureCount = 0;
  CircuitState _state = CircuitState.closed;
  DateTime? _lastFailureTime;

  CircuitBreaker({
    this.failureThreshold = 5,
    this.resetDuration = const Duration(seconds: 30),
  });

  /// Current breaker state.
  CircuitState get state {
    if (_state == CircuitState.open) {
      final last = _lastFailureTime;
      if (last != null && DateTime.now().difference(last) >= resetDuration) {
        _state = CircuitState.halfOpen;
      }
    }
    return _state;
  }

  /// Number of consecutive failures recorded so far.
  int get failureCount => _failureCount;

  /// Executes [action] guarded by the breaker.
  ///
  /// Throws [CircuitOpenException] immediately when open. On success the
  /// breaker is reset; on failure the failure counter is incremented and the
  /// breaker may trip.
  Future<T> execute<T>(Future<T> Function() action) async {
    final s = state;
    if (s == CircuitState.open) {
      throw CircuitOpenException(
        _lastFailureTime?.add(resetDuration),
      );
    }

    try {
      final result = await action();
      reset();
      return result;
    } catch (e) {
      _recordFailure();
      rethrow;
    }
  }

  void _recordFailure() {
    _failureCount += 1;
    _lastFailureTime = DateTime.now();

    if (_state == CircuitState.halfOpen) {
      // Probe failed — re-open immediately.
      _state = CircuitState.open;
    } else if (_failureCount >= failureThreshold) {
      _state = CircuitState.open;
    }
  }

  /// Resets the breaker to [CircuitState.closed].
  void reset() {
    _failureCount = 0;
    _state = CircuitState.closed;
    _lastFailureTime = null;
  }
}
