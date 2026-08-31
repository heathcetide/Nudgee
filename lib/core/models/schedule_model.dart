/// 日程数据模型。
///
/// 一个 [ScheduleItem] 代表一个自律任务（如晨跑、阅读、冥想等），
/// 包含任务名称、地点、备注、起止时间等信息。
///
/// [ScheduleData] 是按日期组织的日程集合，包含固定时段任务和额外任务。
library;

/// 单个日程任务。
class ScheduleItem {
  final String id;
  final String name;
  final String location;
  final String note;
  final String date; // YYYY-MM-DD
  final String startTime; // HH:mm
  final String endTime; // HH:mm
  final int startIndex; // 用于 timetable 网格定位
  final int length; // 占用的时段数
  final bool isExtra; // 是否为额外任务（不在标准时段内）

  const ScheduleItem({
    required this.id,
    required this.name,
    required this.location,
    required this.note,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.startIndex,
    required this.length,
    this.isExtra = false,
  });

  int get durationMinutes {
    final startMin = _timeToMinutes(startTime);
    final endMin = _timeToMinutes(endTime);
    return endMin - startMin;
  }

  /// 转换为 timetable UI 所需的 Map 格式（兼容现有代码）。
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'startIndex': startIndex,
      'length': length,
      'startTime': startTime,
      'endTime': endTime,
      'duration': durationMinutes,
      'others': [
        {'key': '任务名称', 'value': name},
        {'key': '地点', 'value': location},
        {'key': '备注', 'value': note},
        {'key': '时间', 'value': '$startTime - $endTime'},
      ],
    };
  }

  /// 从 timetable UI 的 Map 格式创建（兼容现有代码）。
  factory ScheduleItem.fromMap(Map<dynamic, dynamic> map, String date) {
    final others = (map['others'] as List?) ?? [];
    String note = '无';
    for (final o in others) {
      if (o['key'] == '备注') {
        note = o['value'] ?? '无';
        break;
      }
    }
    return ScheduleItem(
      id: '${date}_${map['startTime']}_${map['name']}',
      name: map['name'] ?? '',
      location: map['location'] ?? '未指定',
      note: note,
      date: date,
      startTime: map['startTime'] ?? '',
      endTime: map['endTime'] ?? '',
      startIndex: (map['startIndex'] ?? 0) as int,
      length: (map['length'] ?? 1) as int,
      isExtra: false,
    );
  }

  /// JSON 序列化。
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'location': location,
        'note': note,
        'date': date,
        'startTime': startTime,
        'endTime': endTime,
        'startIndex': startIndex,
        'length': length,
        'isExtra': isExtra,
      };

  /// JSON 反序列化。
  factory ScheduleItem.fromJson(Map<String, dynamic> json) => ScheduleItem(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        location: json['location'] ?? '未指定',
        note: json['note'] ?? '无',
        date: json['date'] ?? '',
        startTime: json['startTime'] ?? '',
        endTime: json['endTime'] ?? '',
        startIndex: (json['startIndex'] ?? 0) as int,
        length: (json['length'] ?? 1) as int,
        isExtra: json['isExtra'] ?? false,
      );

  ScheduleItem copyWith({
    String? id,
    String? name,
    String? location,
    String? note,
    String? date,
    String? startTime,
    String? endTime,
    int? startIndex,
    int? length,
    bool? isExtra,
  }) =>
      ScheduleItem(
        id: id ?? this.id,
        name: name ?? this.name,
        location: location ?? this.location,
        note: note ?? this.note,
        date: date ?? this.date,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        startIndex: startIndex ?? this.startIndex,
        length: length ?? this.length,
        isExtra: isExtra ?? this.isExtra,
      );

  static int _timeToMinutes(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length != 2) return 0;
    return int.tryParse(parts[0])! * 60 + int.tryParse(parts[1])!;
  }
}

/// 按日期组织的日程集合。
///
/// 对应 timetable UI 的 `{'fixed': [], 'extra': []}` 结构。
class ScheduleData {
  /// 所有日程项，按日期分组。
  final Map<String, List<ScheduleItem>> byDate;

  const ScheduleData({this.byDate = const {}});

  /// 获取某天的日程（fixed + extra 合并，按开始时间排序）。
  List<ScheduleItem> getForDate(String date) {
    final items = byDate[date];
    if (items == null || items.isEmpty) return [];
    final sorted = List<ScheduleItem>.from(items);
    sorted.sort((a, b) => a.startTime.compareTo(b.startTime));
    return sorted;
  }

  /// 获取某天的日程，按 timetable UI 的 Map 格式返回。
  /// 返回 `{'fixed': List<Map>, 'extra': List<Map>}`。
  Map<String, dynamic> getForDateAsMap(String date) {
    final items = byDate[date];
    if (items == null || items.isEmpty) {
      return {'fixed': [], 'extra': []};
    }
    final fixed = <Map<String, dynamic>>[];
    final extra = <Map<String, dynamic>>[];
    for (final item in items) {
      if (item.isExtra) {
        extra.add(item.toMap());
      } else {
        fixed.add(item.toMap());
      }
    }
    return {'fixed': fixed, 'extra': extra};
  }

  /// 获取所有有日程的日期。
  List<String> get dates => byDate.keys.toList()..sort();

  /// JSON 序列化。
  Map<String, dynamic> toJson() => {
        'byDate': byDate.map(
          (date, items) => MapEntry(
            date,
            items.map((e) => e.toJson()).toList(),
          ),
        ),
      };

  /// JSON 反序列化。
  factory ScheduleData.fromJson(Map<String, dynamic> json) {
    final byDate = <String, List<ScheduleItem>>{};
    final raw = json['byDate'] as Map<String, dynamic>? ?? {};
    for (final entry in raw.entries) {
      byDate[entry.key] = (entry.value as List)
          .map((e) => ScheduleItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return ScheduleData(byDate: byDate);
  }

  ScheduleData copyWith({Map<String, List<ScheduleItem>>? byDate}) =>
      ScheduleData(byDate: byDate ?? this.byDate);
}
