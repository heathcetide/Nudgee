/// Mock 课表数据生成器。
///
/// 生成一个为期 16 周的模拟课表，包含若干门课程，
/// 分布在周一至周五的不同节次。用于替代原有的教务系统登录导入。
library;

import 'dart:math';

/// 生成 mock 课表数据，格式与原 `timetable_data` 一致。
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

    // 每周生成课程
    for (int day = 0; day < 5; day++) {
      // 周一到周五
      final date = weekStart.add(Duration(days: day));
      final dateKey = _dateStr(date);
      final fixed = <Map<String, dynamic>>[];
      final extra = <Map<String, dynamic>>[];

      // 根据星期几安排不同课程
      final courses = _coursesForDay(day, week);
      for (final c in courses) {
        final entry = {
          'name': c['name'],
          'location': c['location'],
          'startIndex': c['startIndex'],
          'length': c['length'],
          'startTime': c['startTime'],
          'endTime': c['endTime'],
          'others': [
            {'key': '课程名称', 'value': c['name']},
            {'key': '上课地点', 'value': c['location']},
            {'key': '授课教师', 'value': c['teacher']},
            {'key': '上课时间', 'value': '${c['startTime']} - ${c['endTime']}'},
            {'key': '周次', 'value': '第${week + 1}周'},
          ],
        };
        if (c['extra'] == true) {
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

/// 节次时间映射（与 timetable.dart 中 periodsStartTime/EndTime 对应）
const _periodTimes = [
  {'start': '08:30', 'end': '09:15'},
  {'start': '09:20', 'end': '10:05'},
  {'start': '10:25', 'end': '11:10'},
  {'start': '11:15', 'end': '12:00'},
  {'start': '14:00', 'end': '14:45'},
  {'start': '14:50', 'end': '15:35'},
  {'start': '15:55', 'end': '16:40'},
  {'start': '16:45', 'end': '17:30'},
];

/// 课程模板池
const _coursePool = [
  {'name': '高等数学', 'teacher': '张教授', 'location': 'A101'},
  {'name': '线性代数', 'teacher': '李教授', 'location': 'A203'},
  {'name': '大学英语', 'teacher': '王老师', 'location': 'B105'},
  {'name': '数据结构', 'teacher': '陈教授', 'location': 'C301'},
  {'name': '操作系统', 'teacher': '刘教授', 'location': 'C402'},
  {'name': '计算机网络', 'teacher': '赵教授', 'location': 'D201'},
  {'name': '软件工程', 'teacher': '孙老师', 'location': 'D305'},
  {'name': '数据库原理', 'teacher': '周教授', 'location': 'E102'},
  {'name': '人工智能导论', 'teacher': '吴教授', 'location': 'E205'},
  {'name': '概率论与数理统计', 'teacher': '郑教授', 'location': 'A305'},
];

/// 根据星期几和周次返回当天课程列表
List<Map<String, dynamic>> _coursesForDay(int day, int week) {
  final rng = Random(day * 100 + week);
  final courses = <Map<String, dynamic>>[];
  final pool = List.from(_coursePool);

  // 周一：上午两节大课
  if (day == 0) {
    courses.add(_makeCourse(pool[0], 0, 2, false));
    courses.add(_makeCourse(pool[3], 4, 2, false));
  }
  // 周二：上午一节 + 下午一节
  else if (day == 1) {
    courses.add(_makeCourse(pool[1], 2, 2, false));
    courses.add(_makeCourse(pool[4], 4, 2, false));
  }
  // 周三：全天三节
  else if (day == 2) {
    courses.add(_makeCourse(pool[2], 0, 2, false));
    courses.add(_makeCourse(pool[5], 2, 2, false));
    courses.add(_makeCourse(pool[8], 4, 2, false));
  }
  // 周四：上午一节 + 晚上一节(extra)
  else if (day == 3) {
    courses.add(_makeCourse(pool[6], 0, 2, false));
    courses.add(_makeCourse(pool[9], 6, 2, false));
    // 晚上课作为 extra
    courses.add({
      'name': '学术讲座',
      'teacher': '外聘专家',
      'location': '报告厅',
      'startIndex': 0,
      'length': 2,
      'startTime': '19:00',
      'endTime': '20:30',
      'duration': 90,
      'extra': true,
    });
  }
  // 周五：上午两节
  else if (day == 4) {
    courses.add(_makeCourse(pool[7], 0, 2, false));
    courses.add(_makeCourse(pool[5], 2, 1, false));
  }

  // 随机偶尔加一节 extra 课
  if (rng.nextInt(10) == 0 && courses.length < 5) {
    final c = pool[rng.nextInt(pool.length)];
    courses.add({
      'name': c['name'],
      'teacher': c['teacher'],
      'location': c['location'],
      'startIndex': 0,
      'length': 1,
      'startTime': '18:30',
      'endTime': '19:15',
      'duration': 45,
      'extra': true,
    });
  }

  return courses;
}

Map<String, dynamic> _makeCourse(
    Map course, int startIndex, int length, bool extra) {
  final times = _periodTimes[startIndex];
  final endTimes = _periodTimes[startIndex + length - 1];
  final startMin = _timeToMinutes(times['start']!);
  final endMin = _timeToMinutes(endTimes['end']!);
  return {
    'name': course['name'],
    'teacher': course['teacher'],
    'location': course['location'],
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
