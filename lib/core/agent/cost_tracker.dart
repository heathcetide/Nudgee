import 'package:flutter/foundation.dart';

import 'package:nudgee/core/agent/agent_stats.dart';

/// Cost tracker — monitors token usage and estimates costs for agent runs.
///
/// Maintains:
/// - Per-run cost: updated as the agent consumes tokens
/// - Cumulative cost: total across all runs in a session
/// - Budget enforcement: blocks further runs if the budget is exceeded
///
/// Pricing is configurable per model via [ModelPricing].
class CostTracker {
  /// Pricing table keyed by model name.
  final Map<String, ModelPricing> pricingTable;

  /// Maximum cumulative cost in CNY before runs are blocked.
  final double budgetCny;

  /// Cumulative cost across all runs.
  double _cumulativeCost = 0.0;

  /// Total tokens consumed across all runs.
  int _cumulativeTokens = 0;

  /// Number of runs tracked.
  int _runCount = 0;

  /// Creates a [CostTracker].
  CostTracker({
    Map<String, ModelPricing>? pricingTable,
    this.budgetCny = 10.0,
  }) : pricingTable = pricingTable ?? _defaultPricing;

  /// Default pricing for common models (CNY per 1K tokens).
  static final Map<String, ModelPricing> _defaultPricing = {
    'deepseek-chat': ModelPricing(
      inputPer1k: 0.001,
      outputPer1k: 0.002,
      thinkingPer1k: 0.002,
    ),
    'deepseek-reasoner': ModelPricing(
      inputPer1k: 0.004,
      outputPer1k: 0.016,
      thinkingPer1k: 0.016,
    ),
    'gpt-4o': ModelPricing(
      inputPer1k: 0.018,
      outputPer1k: 0.072,
    ),
    'gpt-4o-mini': ModelPricing(
      inputPer1k: 0.001,
      outputPer1k: 0.004,
    ),
    'claude-3-5-sonnet': ModelPricing(
      inputPer1k: 0.021,
      outputPer1k: 0.105,
    ),
    'claude-3-haiku': ModelPricing(
      inputPer1k: 0.0015,
      outputPer1k: 0.0075,
    ),
    'gemini-1.5-pro': ModelPricing(
      inputPer1k: 0.005,
      outputPer1k: 0.015,
    ),
    'gemini-1.5-flash': ModelPricing(
      inputPer1k: 0.0005,
      outputPer1k: 0.0015,
    ),
  };

  /// Cumulative cost in CNY.
  double get cumulativeCost => _cumulativeCost;

  /// Cumulative tokens consumed.
  int get cumulativeTokens => _cumulativeTokens;

  /// Number of runs tracked.
  int get runCount => _runCount;

  /// Whether the budget has been exceeded.
  bool get isBudgetExceeded => _cumulativeCost >= budgetCny;

  /// Remaining budget in CNY.
  double get remainingBudget => budgetCny - _cumulativeCost;

  /// Calculates the cost for a given [stats] and [model].
  ///
  /// Returns the estimated cost in CNY.
  double calculateCost(AgentRunStats stats, String model) {
    final pricing = pricingTable[model] ?? pricingTable['deepseek-chat']!;
    final inputCost = (stats.inputTokens / 1000) * pricing.inputPer1k;
    final outputCost = (stats.outputTokens / 1000) * pricing.outputPer1k;
    final thinkingCost =
        (stats.thinkingTokens / 1000) * pricing.thinkingPer1k;
    return inputCost + outputCost + thinkingCost;
  }

  /// Records a completed run and updates cumulative tracking.
  ///
  /// Returns the calculated cost for this run.
  double recordRun(AgentRunStats stats, String model) {
    final cost = calculateCost(stats, model);
    _cumulativeCost += cost;
    _cumulativeTokens += stats.totalTokens;
    _runCount++;

    debugPrint('[CostTracker] run #$_runCount: ¥$cost '
        '(total: ¥$_cumulativeCost, budget: ¥$budgetCny)');

    return cost;
  }

  /// Checks whether a new run should be allowed.
  ///
  /// Returns `true` if the run is within budget, `false` if exceeded.
  bool canRun() => !isBudgetExceeded;

  /// Returns a budget warning if the cost is approaching the limit.
  String? budgetWarning() {
    if (isBudgetExceeded) {
      return 'Budget exceeded: ¥$_cumulativeCost / ¥$budgetCny. '
          'Further agent runs are blocked.';
    }
    final ratio = _cumulativeCost / budgetCny;
    if (ratio > 0.8) {
      return 'Budget warning: ¥$_cumulativeCost / ¥$budgetCny '
          '(${(ratio * 100).round()}% used).';
    }
    return null;
  }

  /// Resets the tracker (e.g. on new billing period).
  void reset() {
    _cumulativeCost = 0.0;
    _cumulativeTokens = 0;
    _runCount = 0;
  }

  /// Returns a summary of the cost tracking.
  Map<String, dynamic> summary() => {
        'cumulativeCostCny': _cumulativeCost,
        'cumulativeTokens': _cumulativeTokens,
        'runCount': _runCount,
        'budgetCny': budgetCny,
        'remainingBudgetCny': remainingBudget,
        'isBudgetExceeded': isBudgetExceeded,
      };
}

/// Pricing for a single model (CNY per 1K tokens).
class ModelPricing {
  final double inputPer1k;
  final double outputPer1k;
  final double thinkingPer1k;

  const ModelPricing({
    required this.inputPer1k,
    required this.outputPer1k,
    this.thinkingPer1k = 0.0,
  });
}
