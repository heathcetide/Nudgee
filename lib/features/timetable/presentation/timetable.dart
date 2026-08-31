import 'dart:async';
import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:nudgee/core/extensions/context_extensions.dart';
import 'package:nudgee/features/common/utils/events.dart';
import 'package:nudgee/features/common/widgets/page_scaffold.dart';
import 'package:nudgee/features/timetable/utils/mock_timetable_data.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:scrollview_observer/scrollview_observer.dart';
import 'package:smooth_scroll_multiplatform/smooth_scroll_multiplatform.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

final eventBus = EventBus();

const textWhite = Color.fromARGB(244, 249, 249, 249);

List classColors = [
  Color(0xFF7986CB), // 淡蓝紫
  Color(0xFFE57373), // 淡珊瑚红
  Color(0xFF81C784), // 薄荷绿
  Color(0xFFBA68C8), // 淡紫
  Color(0xFFFFB74D), // 蜜桃橙
  Color(0xFFF06292), //花粉
  Color(0xFF4DD0E1), // 天青
  Color(0xFF9575CD), // 薰衣草紫
  Color(0xFF4DB6AC), // 蒂芙尼蓝
  Color(0xFFF06292), //花粉
  Color(0xFFFF8A65), // 暖橙
  Color(0xFF7986CB), // 淡蓝紫
  Color(0xFFFFB74D), // 蜜桃橙
  Color(0xFFE57373), // 淡珊瑚红
  Color(0xFF64B5F6), // 晴空蓝
  Color(0xFF9575CD), // 薰衣草紫
  Color(0xFFBA68C8), // 淡紫
  Color(0xFFEF5350), // 柔红
  Color(0xFFEC407A), // 玫红
  Color(0xFFAB47BC), // 兰花紫
  Color(0xFF7E57C2), // 紫罗兰
  Color(0xFF5C6BC0), // 雾蓝
  Color(0xFF42A5F5), // 天蓝
  Color(0xFF26C6DA), // 水蓝
  Color(0xFFFFCA28), // 暖黄
  Color(0xFFFFA726), // 杏橙
  Color(0xFFFFEE58), // 柠檬黄
  Color(0xFFAB47BC), // 兰花紫
  Color(0xFF66BB6A), // 苹果绿
];

Color hex2Color(String code) {
  return Color(int.parse(code.substring(1, 7), radix: 16) + 0xFF000000);
}

const weekdayString = {
  1: '一',
  2: '二',
  3: '三',
  4: '四',
  5: '五',
  6: '六',
  7: '日',
};

const weekString = {
  0: '零',
  1: '一',
  2: '二',
  3: '三',
  4: '四',
  5: '五',
  6: '六',
  7: '七',
  8: '八',
  9: '九',
  10: '十',
};

String getWeekString(int digital) {
  return (digital <= 10) ? weekString[digital]! : digital.toString();
}

const periodsStartTime = [
  '06:30',
  '07:20',
  '08:30',
  '09:20',
  '10:25',
  '14:00',
  '14:50',
  '15:55',
  '19:00',
  '19:50',
  '20:55',
];

const periodsEndTime = [
  '07:15',
  '08:05',
  '09:15',
  '10:05',
  '11:10',
  '14:45',
  '15:35',
  '16:40',
  '19:45',
  '20:35',
  '21:40',
];
const dividerLocation = [
  4,
  7,
];

class Timetable extends StatefulWidget {
  const Timetable({super.key});

  @override
  State<Timetable> createState() => _TimetableState();
}

class _TimetableState extends State<Timetable> {
  Map<dynamic, dynamic> dailyClass = {};
  List<dynamic> weekPeriodList = [];
  ScrollController scrollController = ScrollController();
  ListObserverController listObserverController = ListObserverController();
  Timer? listObserverTimer;
  int? currentWeekIndex = 0;

  @override
  void initState() {
    super.initState();
    listObserverController = ListObserverController(controller: scrollController);
    _initState();
  }

  void _initState() async {
    final _td = generateMockTimetableData();
    setState(() {
      dailyClass = _td['dailyClass'];
      weekPeriodList = _td['weekPeriodList'];
    });
    // 等待 frame 渲染完成后再跳转到当前周
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) jumpToNowWeek();
    });
  }

  @override
  void dispose() {
    if (listObserverTimer != null) listObserverTimer!.cancel();
    super.dispose();
  }

  void jumpToNowWeek() {
    if (weekPeriodList.isEmpty) return;
    var now = DateTime.now();
    for (var weekPeriod in weekPeriodList) {
      if (DateTime.parse(weekPeriod['startDate']).isBefore(now) &&
          DateTime.parse(weekPeriod['endDate']).add(const Duration(days: 1)).isAfter(now)) {
        // 延迟一帧确保 ListView 已渲染
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && scrollController.hasClients) {
            listObserverController.jumpTo(index: weekPeriod['weekIndex'] * 8 + 1);
          }
        });
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: Text(context.l10n.timetableOverview),
      leading: IconButton(
          onPressed: () {
            PublicEventBus.eventBus.fire(ChangePageEvent('todaySchedule'));
          },
          icon: Text(
            context.l10n.timetableSingleDay,
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
          )),
      child: SizedBox.expand(
        child: Column(
          children: [
            Header(week: currentWeekIndex),
            Expanded(
              child: DynMouseScroll(builder: (context, controller, physics) {
                return ListViewObserver(
                  autoTriggerObserveTypes: const [ObserverAutoTriggerObserveType.scrollEnd],
                  controller: listObserverController,
                  onObserve: (resultModel) {
                    int firstIndex = resultModel.firstChild!.index ~/ 8;
                    if (firstIndex != currentWeekIndex) {
                      setState(() {
                        currentWeekIndex = firstIndex;
                      });
                    }
                  },
                  child: ListView(
                    controller: scrollController,
                    physics: physics,
                    children: (() {
                      List<Widget> children = [];
                      if (weekPeriodList.length > 0) {
                        var startDate = DateTime.parse(weekPeriodList[0]['startDate']);
                        var endDate =
                            DateTime.parse(weekPeriodList[weekPeriodList.length - 1]['endDate']);
                        for (var date = startDate;
                            date.isBefore(endDate);
                            date = date.add(const Duration(days: 1))) {
                          var _date = date.toString().split(' ')[0];
                          for (var weekPeriod in weekPeriodList) {
                            if (_date == weekPeriod['startDate']) {
                              int weekTotalClass = 0;
                              for (var date_inweek = date;
                                  date_inweek.isBefore(DateTime.parse(weekPeriod['endDate']));
                                  date_inweek = date_inweek.add(const Duration(days: 1))) {
                                var _date_inweek = date_inweek.toString().split(' ')[0];
                                if (dailyClass[_date_inweek] != null) {
                                  weekTotalClass += dailyClass[_date_inweek]['fixed'].length +
                                      dailyClass[_date_inweek]['extra'].length as int;
                                }
                              }
                              children.add(WeekDivider(
                                  week: weekPeriod['weekIndex'],
                                  fromDate: weekPeriod['startDate'],
                                  toDate: weekPeriod['endDate'],
                                  total: weekTotalClass));
                            }
                          }
                          children.add(DailyClass(
                              date: _date,
                              classes: dailyClass[_date] != null
                                  ? dailyClass[_date]
                                  : {'fixed': [], 'extra': []}));
                        }
                        return children;
                      }
                      return [Text(context.l10n.loading)];
                    })(),
                  ),
                );
              }),
            )
          ],
        ),
      ),
    );
  }
}

class Header extends StatefulWidget {
  final week;
  const Header({super.key, this.week});

  @override
  State<Header> createState() => _HeaderState();
}

class _HeaderState extends State<Header> {
  var periodTextGroup1 = AutoSizeGroup();
  var periodTextGroup2 = AutoSizeGroup();
  @override
  Widget build(BuildContext context) {
    List periods = [];
    for (int i = 0; i < periodsStartTime.length; i++) {
      periods.add({
        'startTime': periodsStartTime[i],
        'endTime': periodsEndTime[i],
        'type': 'normal',
      });
      if (dividerLocation.contains(i)) {
        periods.add({
          'type': 'divider',
        });
      }
    }
    return Container(
      height: 24,
      decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
        color: Theme.of(context).colorScheme.outline,
      ))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: (() {
          List<Widget> children = [
            Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      border: Border(
                          right:
                              BorderSide(color: Theme.of(context).colorScheme.outline, width: 1))),
                  child: Center(
                    child: AutoSizeText(
                      context.l10n.timetableWeekN(getWeekString(widget.week)),
                      minFontSize: 0,
                      maxLines: 1,
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                                color: Theme.of(context).colorScheme.shadow.withAlpha(88),
                                offset: Offset(1, 1),
                                blurRadius: 3)
                          ]),
                    ),
                  ),
                ))
          ];
          for (int i = 0; i < periods.length; i++) {
            var period = periods[i];
            if (period['type'] == 'divider') continue;
            children.add(Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryFixed,
                    border: Border(
                        right: BorderSide(
                            color: i < periods.length - 1 && periods[i + 1]['type'] == 'divider'
                                ? Theme.of(context).colorScheme.outline
                                : Theme.of(context).dividerColor,
                            width: .5))),
                child: Center(
                  child: Column(
                    children: [
                      Expanded(
                        flex: 3,
                        child: AutoSizeText(
                          '${period['startTime']}    ',
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                          group: periodTextGroup1,
                          style: const TextStyle(height: 1, fontWeight: FontWeight.bold),
                          minFontSize: 0,
                          maxFontSize: 16,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: AutoSizeText(
                          '${period['endTime']}└    ',
                          maxLines: 1,
                          style: TextStyle(height: 1, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          textDirection: TextDirection.rtl,
                          maxFontSize: 12,
                          overflow: TextOverflow.visible,
                          group: periodTextGroup2,
                          minFontSize: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ));
          }
          return children;
        })(),
      ),
    );
  }
}

class DailyClass extends StatefulWidget {
  final classes;
  final date;
  const DailyClass({super.key, this.classes, this.date});

  @override
  State<DailyClass> createState() => _DailyClassState();
}

class _DailyClassState extends State<DailyClass> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(width: .5, color: Theme.of(context).dividerColor)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: (() {
            List<Widget> children = [
              Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryFixed,
                      border: Border(
                        right: BorderSide(width: 1, color: Theme.of(context).colorScheme.outline),
                      ),
                    ),
                    child: Stack(children: [
                      Center(
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Text(
                                "${weekdayString[DateTime.parse(widget.date).weekday]}",
                                style: const TextStyle(
                                    height: 1, fontSize: 18, fontWeight: FontWeight.w900),
                              ),
                            ),
                            AutoSizeText(
                              "${DateTime.parse(widget.date).month.toString().padLeft(2, '0')}.${DateTime.parse(widget.date).day.toString().padLeft(2, '0')}",
                              maxLines: 1,
                              minFontSize: 0,
                              maxFontSize: 12,
                              style:
                                  TextStyle(height: 1, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      if (widget.classes['extra'].length > 0)
                        Positioned(
                          right: 2,
                          top: 2,
                          child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 1.6, vertical: 1),
                              decoration: BoxDecoration(
                                  color: Colors.orange, borderRadius: BorderRadius.circular(2)),
                              child: Text(
                                widget.classes['extra'].length.toString(),
                                style: TextStyle(
                                    height: 1,
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(
                                          color: Theme.of(context).colorScheme.shadow.withAlpha(66),
                                          offset: Offset(.6, .6),
                                          blurRadius: 2)
                                    ]),
                              )),
                        ),
                      SizedBox.expand(
                        child: MaterialButton(onPressed: () {
                          if (widget.classes['extra'].length == 0) return;
                          // 覆盖于星期整个单元格之上的按钮，查看额外(不在8:30-16:45)的课
                          widget.classes['extra'].sort((a, b) =>
                              (a['startTime'] as String).compareTo(b['startTime'] as String));
                          showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 14),
                                  title: Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text("其他任务 "),
                                      Text(
                                        widget.date,
                                        style: TextStyle(fontSize: 16, color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey[600]!),
                                      )
                                    ],
                                  ),
                                  content: SizedBox(
                                    width: 666,
                                    height: 160,
                                    child: ListView.builder(
                                        itemCount: widget.classes['extra'].length,
                                        itemBuilder: (context, index) {
                                          var item = widget.classes['extra'][index];
                                          return ListTile(
                                            trailing: Icon(Icons.keyboard_arrow_right),
                                            title: Text(
                                                '[${item['startTime']}-${item['endTime']}] ${item['name']}'),
                                            subtitle: Text('${item['location']}'),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            onTap: () {
                                              showDialog(
                                                context: context,
                                                builder: (BuildContext context) {
                                                  return AlertDialog(
                                                    contentPadding:
                                                        EdgeInsets.symmetric(horizontal: 14),
                                                    title: Row(
                                                      crossAxisAlignment: CrossAxisAlignment.end,
                                                      children: [
                                                        Text("任务详情 "),
                                                        Text(
                                                          widget.date,
                                                          style: TextStyle(
                                                              fontSize: 16,
                                                              color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey[600]!),
                                                        )
                                                      ],
                                                    ),
                                                    content: ClassInfoDetail(
                                                      detail: item['others'],
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () {
                                                          Navigator.of(context).pop();
                                                        },
                                                        child: const Text("关闭"),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              );
                                            },
                                          );
                                        }),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                      child: const Text("关闭"),
                                    ),
                                  ],
                                );
                              });
                        }),
                      ),
                    ]),
                  )),
              for (int i = 0; i < periodsStartTime.length; i++)
                Expanded(
                    flex: 1,
                    child: Container(
                      decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerLow ?? Colors.grey[100]!,
                          border: Border(
                              right: BorderSide(
                                  color: dividerLocation.contains(i)
                                      ? Theme.of(context).colorScheme.outline
                                      : Theme.of(context).dividerColor,
                                  width: .5))),
                      child: Center(
                          child: Text(
                        '${i + 1}',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(63)),
                      )),
                    ))
            ];
            widget.classes['fixed']
                .sort((a, b) => (b['startIndex'] as int).compareTo(a['startIndex'] as int));
            for (int i = 0; i < widget.classes['fixed'].length; i++) {
              var name = widget.classes['fixed'][i]['name'];
              var location = widget.classes['fixed'][i]['location'];
              var startIndex = widget.classes['fixed'][i]['startIndex'];
              var length = widget.classes['fixed'][i]['length'];
              var others = widget.classes['fixed'][i]['others'];
              children.insert(
                  startIndex + 1,
                  Expanded(
                    flex: length,
                    child: Container(
                      decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerLow ?? Colors.grey[100]!,
                          border: Border(
                              right: BorderSide(
                                  color: dividerLocation.contains(startIndex + length - 1)
                                      ? Theme.of(context).colorScheme.outline
                                      : Theme.of(context).dividerColor,
                                  width: .5))),
                      child: ClassRectItem(
                        date: widget.date,
                        detail: others,
                        name: name,
                        location: location,
                        length: length,
                      ),
                    ),
                  ));
              for (int j = 0; j < length; j++) {
                children.removeAt(startIndex + 2);
              }
            }
            return children;
          })(),
        ),
      ),
    );
  }
}

class ClassRectItem extends StatefulWidget {
  final name;
  final location;
  final length;
  final detail;
  final date;
  const ClassRectItem({super.key, this.name, this.location, this.length, this.detail, this.date});

  @override
  State<ClassRectItem> createState() => _ClassRectItemState();
}

class _ClassRectItemState extends State<ClassRectItem> {
  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      MaterialButton(
        padding: EdgeInsets.all(0),
        onPressed: () {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                contentPadding: EdgeInsets.symmetric(horizontal: 14),
                title: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("任务详情 "),
                    Text(
                      widget.date,
                      style: TextStyle(fontSize: 16, color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey[600]!),
                    )
                  ],
                ),
                content: ClassInfoDetail(
                  detail: widget.detail,
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text("关闭"),
                  ),
                ],
              );
            },
          );
          // Navigator.of(context).push(TDSlidePopupRoute(
          //     modalBarrierColor: TDTheme.of(context).fontGyColor2,
          //     slideTransitionFrom: SlideTransitionFrom.center,
          //     builder: (context) {
          //       return ClassInfoDetail(
          //         detail: widget.detail,
          //         date: widget.date,
          //       );
          //     }));
        },
        child: Container(
            margin: const EdgeInsets.all(3),
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4.5),
            decoration: BoxDecoration(
              // boxShadow: const [
              //   BoxShadow(
              //     color: Color.fromARGB(144, 0, 0, 0),
              //     offset: Offset(1, 1),
              //     blurRadius: 5,
              //   )
              // ],
              // border: Border.all(width: .5, color: Colors.grey[100]!, strokeAlign: -2.0),
              color: classColors[Random(widget.name.hashCode * 3).nextInt(classColors.length)],
              borderRadius: BorderRadius.circular(6),
            ),
            child: SizedBox.expand(
              child: Column(children: [
                Expanded(
                  child: AutoSizeText(
                    widget.name,
                    maxLines: widget.length == 2
                        ? (widget.name.length <= 6 ? 1 : 2)
                        : (widget.length == 1 ? (widget.name.length <= 4 ? 1 : 3) : 3),
                    minFontSize: 9,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(height: 1.1, color: Colors.white, fontWeight: FontWeight.w600, shadows: [
                      Shadow(
                          color: Colors.black.withAlpha(80), offset: Offset(.5, .5), blurRadius: 2)
                    ]),
                  ),
                )
              ]),
            )),
      ),
      widget.length >= 2
          ? Positioned(
              bottom: 3,
              right: 3,
              child: IgnorePointer(
                child: Container(
                    decoration: const BoxDecoration(
                        color: Color.fromARGB(88, 0, 0, 0),
                        borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(3),
                            bottomLeft: Radius.circular(1),
                            topRight: Radius.circular(1),
                            bottomRight: Radius.circular(6))),
                    padding: const EdgeInsets.only(left: 2, right: 2, top: 1.8, bottom: 2),
                    child: AutoSizeText(
                      widget.location,
                      maxFontSize: 8,
                      minFontSize: 0,
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      style: const TextStyle(
                        color: Colors.white,
                        height: 1,
                      ),
                    )),
              ),
            )
          : Positioned(
              child: IgnorePointer(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      margin: EdgeInsets.only(left: 3, bottom: 3, right: 3),
                      decoration: BoxDecoration(
                          color: Color.fromARGB(88, 0, 0, 0),
                          borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(1),
                              bottomLeft: Radius.circular(6),
                              topRight: Radius.circular(1),
                              bottomRight: Radius.circular(6))),
                      padding: const EdgeInsets.only(left: 2, right: 2, top: 1.8, bottom: 2),
                      child: Center(
                        child: AutoSizeText(
                          widget.location,
                          maxFontSize: 8,
                          minFontSize: 0,
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                          style: const TextStyle(
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
    ]);
  }
}

class WeekDivider extends StatefulWidget {
  final week;
  final fromDate;
  final toDate;
  final total;
  const WeekDivider({super.key, this.week, this.fromDate, this.toDate, this.total});

  @override
  State<WeekDivider> createState() => _WeekDividerState();
}

class _WeekDividerState extends State<WeekDivider> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
      ),
      padding: const EdgeInsets.all(1),
      height: 12,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AutoSizeText(
            '${context.l10n.timetableWeekN(getWeekString(widget.week))}  /  ${DateTime.parse(widget.fromDate).month.toString().padLeft(2, '0')}.${DateTime.parse(widget.fromDate).day.toString().padLeft(2, '0')} - ${DateTime.parse(widget.toDate).month.toString().padLeft(2, '0')}.${DateTime.parse(widget.toDate).day.toString().padLeft(2, '0')}  /  ${context.l10n.timetableTotalSessions(widget.total)}',
            style: const TextStyle(color: Colors.white, height: 1),
            minFontSize: 0,
          )
        ],
      ),
    );
  }
}

class ClassInfoDetail extends StatefulWidget {
  final detail;
  const ClassInfoDetail({super.key, this.detail});

  @override
  State<ClassInfoDetail> createState() => _ClassInfoDetailState();
}

class _ClassInfoDetailState extends State<ClassInfoDetail> {
  @override
  Widget build(BuildContext context) {
    List<DataRow> rows = [];
    return SizedBox(
      width: 666,
      height: 400,
      child: Scrollbar(
        radius: Radius.circular(1),
        thumbVisibility: true,
        child: ListView.builder(
          itemBuilder: (context, index) {
            return ListTile(
              title: Text(widget.detail[index]['key']),
              subtitle: Text(widget.detail[index]['value']),
            );
          },
          itemCount: widget.detail.length,
        ),
      ),
    );
  }
}
