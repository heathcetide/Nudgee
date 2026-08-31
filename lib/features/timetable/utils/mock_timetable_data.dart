/// Mock 日程数据生成器。
///
/// 生成一个为期 16 周的模拟日程，包含自律任务（晨跑、阅读、冥想等），
/// 分布在周一至周日的不同时段。用于替代原有的课程表数据。
library;

import 'dart:math';

/// 生成 mock 日程数据，格式与原 `timetable_data` 一致。
///
/// 返回 `{'dailyClass': Map, 'weekPeriodList': List}`。
Map<String, dynamic> generateMockTimetableData() {
  final now = DateTime.now();
  // 以本周周一为起点
  final semesterStart =
      now.subtract(Duration(days: now.weekday - 1));

  final weekPeriodList = <Map<String, dynamic>>[];
  final dailyClass = <String, Map<String, dynamic>>{};

  for (int week = 0; week < 16; week++) {
    final weekStart = semesterStart.add(Duration(days: week * 7));
    final weekEnd = weekStart.add(const Duration(days: 6));
    weekPeriodList.add({
      'weekIndex': week,
      'startDate': _dateStr(weekStart),
      'endDate': _dateStr(weekEnd),
    });

    // 每周生成日程（周一到周日）
    for (int day = 0; day < 7; day++) {
      final date = weekStart.add(Duration(days: day));
      final dateKey = _dateStr(date);
      final fixed = <Map<String, dynamic>>[];
      final extra = <Map<String, dynamic>>[];

      // 根据星期几安排不同任务
      final tasks = _tasksForDay(day, week);
      for (final t in tasks) {
        final entry = {
          'name': t['name'],
          'location': t['location'],
          'startIndex': t['startIndex'],
          'length': t['length'],
          'startTime': t['startTime'],
          'endTime': t['endTime'],
          'others': [
            {'key': '任务名称', 'value': t['name']},
            {'key': '地点', 'value': t['location']},
            {'key': '备注', 'value': t['note']},
            {'key': '时间', 'value': '${t['startTime']} - ${t['endTime']}'},
            {'key': '周次', 'value': '第${week + 1}周'},
          ],
        };
        if (t['extra'] == true) {
          extra.add(entry);
        } else {
          fixed.add(entry);
        }
      }

      if (fixed.isNotEmpty || extra.isNotEmpty) {
        dailyClass[dateKey] = {'fixed': fixed, 'extra': extra};
      }
    }
  }

  return {'dailyClass': dailyClass, 'weekPeriodList': weekPeriodList};
}

String _dateStr(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 时段映射（与 timetable.dart 中 periodsStartTime/EndTime 对应）
const _periodTimes = [
  {'start': '06:00', 'end': '07:00'},
  {'start': '07:00', 'end': '08:00'},
  {'start': '08:00', 'end': '09:00'},
  {'start': '09:00', 'end': '10:00'},
  {'start': '10:00', 'end': '11:00'},
  {'start': '11:00', 'end': '12:00'},
  {'start': '12:00', 'end': '13:00'},
  {'start': '13:00', 'end': '14:00'},
  {'start': '14:00', 'end': '15:00'},
  {'start': '15:00', 'end': '16:00'},
  {'start': '16:00', 'end': '17:00'},
  {'start': '17:00', 'end': '18:00'},
  {'start': '18:00', 'end': '19:00'},
  {'start': '19:00', 'end': '20:00'},
  {'start': '20:00', 'end': '21:00'},
  {'start': '21:00', 'end': '22:00'},
  {'start': '22:00', 'end': '23:00'},
  {'start': '23:00', 'end': '24:00'},
];

/// 自律任务模板池
const _taskPool = [
  {'name': '晨跑', 'location': '操场', 'note': '5公里慢跑'},
  {'name': '英语阅读', 'location': '图书馆', 'note': '精读一篇外刊'},
  {'name': '冥想', 'location': '宿舍', 'note': '正念冥想15分钟'},
  {'name': '编程练习', 'location': '自习室', 'note': 'LeetCode 刷题'},
  {'name': '健身', 'location': '健身房', 'note': '力量训练'},
  {'name': '日记复盘', 'location': '宿舍', 'note': '记录今日反思'},
  {'name': '专业学习', 'location': '图书馆', 'note': '深度学习2小时'},
  {'name': '阅读', 'location': '咖啡馆', 'note': '读书30页'},
  {'name': '单词背诵', 'location': '宿舍', 'note': '背50个单词'},
  {'name': '瑜伽', 'location': '活动室', 'note': '拉伸放松'},
];

/// 根据星期几和周次返回当天任务列表
List<Map<String, dynamic>> _tasksForDay(int day, int week) {
  final rng = Random(day * 100 + week);
  final tasks = <Map<String, dynamic>>[];
  final pool = List.from(_taskPool);

  // 周一：晨跑 + 编程 + 复盘
  if (day == 0) {
    tasks.add(_makeTask(pool[0], 0, 1, false));   // 06:00 晨跑
    tasks.add(_makeTask(pool[3], 4, 2, false));   // 10:00 编程
    tasks.add(_makeTask(pool[5], 15, 1, false));  // 21:00 复盘
  }
  // 周二：英语 + 健身
  else if (day == 1) {
    tasks.add(_makeTask(pool[1], 2, 2, false));   // 08:00 英语
    tasks.add(_makeTask(pool[4], 8, 2, false));   // 14:00 健身
  }
  // 周三：晨跑 + 专业学习 + 阅读
  else if (day == 2) {
    tasks.add(_makeTask(pool[0], 0, 1, false));   // 06:00 晨跑
    tasks.add(_makeTask(pool[6], 2, 2, false));   // 08:00 专业学习
    tasks.add(_makeTask(pool[7], 13, 2, false));  // 19:00 阅读
  }
  // 周四：冥想 + 编程 + 单词(extra)
  else if (day == 3) {
    tasks.add(_makeTask(pool[2], 2, 1, false));   // 08:00 冥想
    tasks.add(_makeTask(pool[3], 4, 2, false));   // 10:00 编程
    tasks.add({
      'name': '单词背诵',
      'location': '宿舍',
      'note': '睡前背50个单词',
      'startIndex': 16,
      'length': 1,
      'startTime': '22:00',
      'endTime': '22:30',
      'duration': 30,
      'extra': true,
    });
  }
  // 周五：晨跑 + 专业学习
  else if (day == 4) {
    tasks.add(_makeTask(pool[0], 0, 1, false));   // 06:00 晨跑
    tasks.add(_makeTask(pool[6], 2, 2, false));   // 08:00 专业学习
  }
  // 周六：瑜伽 + 阅读 + 日记复盘
  else if (day == 5) {
    tasks.add(_makeTask(pool[9], 2, 1, false));   // 08:00 瑜伽
    tasks.add(_makeTask(pool[7], 4, 2, false));   // 10:00 阅读
    tasks.add(_makeTask(pool[5], 15, 1, false));  // 21:00 复盘
  }
  // 周日：冥想 + 编程 + 复盘
  else if (day == 6) {
    tasks.add(_makeTask(pool[2], 2, 1, false));   // 08:00 冥想
    tasks.add(_makeTask(pool[3], 4, 2, false));   // 10:00 编程
    tasks.add(_makeTask(pool[5], 15, 1, false));  // 21:00 复盘
  }

  // 随机偶尔加一个额外任务
  if (rng.nextInt(10) == 0 && tasks.length < 5) {
    final t = pool[rng.nextInt(pool.length)];
    tasks.add({
      'name': t['name'],
      'location': t['location'],
      'note': t['note'],
      'startIndex': 14,
      'length': 1,
      'startTime': '20:00',
      'endTime': '20:45',
      'duration': 45,
      'extra': true,
    });
  }

  return tasks;
}

Map<String, dynamic> _makeTask(
    Map task, int startIndex, int length, bool extra) {
  final times = _periodTimes[startIndex];
  final endTimes = _periodTimes[startIndex + length - 1];
  final startMin = _timeToMinutes(times['start']!);
  final endMin = _timeToMinutes(endTimes['end']!);
  return {
    'name': task['name'],
    'location': task['location'],
    'note': task['note'],
    'startIndex': startIndex,
    'length': length,
    'startTime': times['start'],
    'endTime': endTimes['end'],
    'duration': endMin - startMin,
    'extra': extra,
  };
}

int _timeToMinutes(String timeStr) {
  final parts = timeStr.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}
