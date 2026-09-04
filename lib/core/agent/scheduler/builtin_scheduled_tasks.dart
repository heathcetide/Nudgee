/// Built-in scheduled tasks loader — registers tasks from agent JSON configs.
///
/// Tasks are defined in each agent's JSON file under the `scheduled_task` key.
/// This function loads all agent configs and registers any that have
/// scheduled tasks enabled.

import 'package:flutter/foundation.dart';

import 'package:nudgee/core/agent/agent_config_loader.dart';
import 'package:nudgee/core/agent/scheduler/agent_task_scheduler.dart';

/// Loads all agent configs and registers scheduled tasks with the scheduler.
///
/// Called during DI initialization after [AgentService] is ready.
Future<void> registerBuiltinScheduledTasks(AgentTaskScheduler scheduler) async {
  try {
    final loader = AgentConfigLoader();
    final configs = await loader.loadAll();

    for (final config in configs) {
      if (config.scheduledTask != null && config.scheduledTask!.enabled) {
        scheduler.registerFromAgent(config);
      }
    }

    debugPrint('[ScheduledTasks] Registered ${scheduler.tasks.length} '
        'scheduled task(s) from agent configs');
  } catch (e) {
    debugPrint('[ScheduledTasks] Failed to load: $e');
  }
}
