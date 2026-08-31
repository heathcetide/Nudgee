import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:go_router/go_router.dart';
import 'package:nudgee/app/router/app_router.dart';
import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/extensions/context_extensions.dart';
import 'package:nudgee/core/services/schedule_service.dart';
import 'package:nudgee/features/common/utils/events.dart';
import 'package:nudgee/features/timetable/presentation/timetable.dart';
import 'package:flutter/material.dart';
import 'package:stroke_text/stroke_text.dart';
import 'package:timelines/timelines.dart';

Duration tmpOffset = Duration(days: 0);

Color upcomingColor = const Color.fromARGB(255, 254, 231, 133);
Color activeColor = const Color.fromARGB(255, 167, 189, 242);

const markedTimes = [
  {
    'align': 'start',
    'time': '06:00',
  },
  {
    'align': 'end',
    'time': '12:00',
  },
  {
    'align': 'start',
    'time': '14:00',
  },
  {
    'align': 'end',
    'time': '18:00',
  },
  {
    'align': 'start',
    'time': '19:00',
  },
  {
    'align': 'end',
    'time': '24:00',
  }
];

const wholeDayPeriod = {
  'start': '06:00',
  'end': '24:00',
};

final totalDailyMinutes =
    getMinutesFromTimeStr(wholeDayPeriod['end']!) - getMinutesFromTimeStr(wholeDayPeriod['start']!);

int getMinutesFromTimeStr(String timeStr) {
  return int.parse(timeStr.split(':')[0]) * 60 + int.parse(timeStr.split(':')[1]);
}

double getPercentOfDayFromTimeStr(String timeStr) {
  return (getMinutesFromTimeStr(timeStr) - getMinutesFromTimeStr(wholeDayPeriod['start']!)) /
      totalDailyMinutes;
}

double getPercentOfDayFromDuation(int minutes) {
  return minutes / totalDailyMinutes;
}

String getTimeStrFromDateTime(DateTime date) {
  return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class TodaySchedule extends StatefulWidget {
  const TodaySchedule({super.key});

  @override
  State<TodaySchedule> createState() => _TodayScheduleState();
}

class _TodayScheduleState extends State<TodaySchedule> {
  Map<dynamic, dynamic> dailyClass = {}; // 从手机存储中读取的本学期全部日程
  List<dynamic> todayClass = []; // 今天(当前页面显示的这一天)的课表
  Map<String, dynamic> todayClassState = {
    // 根据系统时间实时计算出的今天日程的状态
    "stateList": [
      'passed',
      'upcoming',
      'active',
      'future'
    ], // 与 todayClass 下标一一对应, upcoming & active 相互对立，不可能同时出现
    "nowState": 'active', // 当前的状态 active / upcoming / finished / hereafter
    "nowIndex": 0, // 当前 nowState 的下标 (finished 下标为-1， hereafter 为 2)
    "nowDate": DateTime.now().add(tmpOffset)
  };
  Timer? timer;

  @override
  void initState() {
    _initState();
    super.initState();
    timer = Timer.periodic(Duration(seconds: 1), (_timer) {
      updateTodayClassState();
    });
  }

  void _initState() async {
    final scheduleService = sl<ScheduleService>();

    // Listen for schedule changes first, so we catch init() notifyListeners().
    if (!_scheduleListenerAdded) {
      _scheduleListenerAdded = true;
      scheduleService.addListener(_onScheduleChanged);
    }

    // Load local data first (fast), then sync from cloud.
    await scheduleService.init();
    if (!mounted) return;
    _loadDailyClass();

    // Cloud sync is best-effort, don't block UI.
    scheduleService.syncFromCloud().then((_) {
      if (mounted) _loadDailyClass();
    });
  }

  bool _scheduleListenerAdded = false;

  void _onScheduleChanged() {
    _loadDailyClass();
  }

  void _loadDailyClass() {
    final scheduleService = sl<ScheduleService>();
    // Build dailyClass map from ScheduleService data.
    final allDates = scheduleService.scheduleData.dates;
    dailyClass = {};
    for (final date in allDates) {
      dailyClass[date] = scheduleService.getForDateAsMap(date);
    }

    String dateStr = DateTime.now().add(tmpOffset).toString().split(' ')[0];
    setState(() {
      if (dailyClass[dateStr] == null) {
        todayClass = [];
        updateTodayClassState();
      } else {
        todayClass = getTodayClassFromDateStr(dateStr);
        updateTodayClassState();
      }
    });
  }

  void updateTodayClassState() {
    setState(() {
      if (todayClassState['nowState'] == 'hereafter') {
        todayClassState['stateList'] = List.filled(todayClass.length, 'future');
        DateTime now = DateTime.now().add(tmpOffset);
        if (now.isAfter(todayClassState['nowDate'])) {
          todayClassState['nowState'] = 'finished';
          todayClassState['nowIndex'] = -1;
        }
        return;
      }
      DateTime now = DateTime.now().add(tmpOffset);
      int nowMinute = now.hour * 60 + now.minute;
      todayClassState['stateList'] = List.filled(todayClass.length, 'passed');
      bool hasNowState = false;
      todayClassState['nowIndex'] = -1;
      todayClassState['nowState'] = 'finished';
      for (int i = 0; i < todayClass.length; i++) {
        if (nowMinute >= getMinutesFromTimeStr(todayClass[i]['startTime']) &&
            nowMinute < getMinutesFromTimeStr(todayClass[i]['endTime'])) {
          // 任务进行中
          todayClassState['nowState'] = 'active';
          todayClassState['nowIndex'] = i;
          todayClassState['stateList'][i] = 'active';
          hasNowState = true;
        } else {
          // 未在任务中
          if (nowMinute > getMinutesFromTimeStr(todayClass[i]['startTime'])) {
            todayClassState['stateList'][i] = 'passed';
          } else {
            if (hasNowState) {
              todayClassState['stateList'][i] = 'future';
            } else {
              hasNowState = true;
              todayClassState['stateList'][i] = 'upcoming';
              todayClassState['nowState'] = 'upcoming';
              todayClassState['nowIndex'] = i;
            }
          }
        }
      }
      if (todayClassState['nowState'] == 'finished') {
        DateTime currentDate = DateTime.now().add(tmpOffset);
        for (int i = 1; i <= 14; i++) {
          // 向后找两周
          DateTime date = currentDate.add(Duration(days: i));
          date = DateTime(date.year, date.month, date.day, 0, 0, 0);
          if (dailyClass[date.toString().split(' ')[0]] != null) {
            todayClass = getTodayClassFromDateStr(date.toString().split(' ')[0]);
            todayClassState['nowState'] = 'hereafter';
            todayClassState["nowDate"] = date;
            updateTodayClassState();
            break;
          }
        }
      }
    });
  }

  List<dynamic> getTodayClassFromDateStr(String dateStr) {
    var classList = [];
    classList.addAll(dailyClass[dateStr]['fixed']);
    classList.addAll(dailyClass[dateStr]['extra']);
    // 确保 duration 字段存在
    for (var item in classList) {
      if (item['duration'] == null) {
        int startMin = getMinutesFromTimeStr(item['startTime']);
        int endMin = getMinutesFromTimeStr(item['endTime']);
        item['duration'] = endMin - startMin;
      }
    }
    classList.sort((a, b) => (a['startTime'] as String).compareTo(b['startTime'] as String));

    return classList;
  }

  @override
  void dispose() {
    if (timer != null) timer!.cancel();
    sl<ScheduleService>().removeListener(_onScheduleChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    String titleText;
    if (todayClassState['nowState'] == 'hereafter') {
      DateTime now = DateTime.now().add(tmpOffset);
      now = DateTime(now.year, now.month, now.day, 0, 0, 0);
      Duration diff = todayClassState['nowDate'].difference(now);
      if (diff.inDays == 1) {
        titleText = l10n.timetableTomorrow;
      } else if (diff.inDays <= 5 && todayClassState['nowDate'].weekday == 1) {
        titleText = l10n.timetableNextWeek;
      } else {
        titleText = l10n.timetableDateSchedule(todayClassState['nowDate'].toString().split(' ')[0]);
      }
    } else {
      titleText = l10n.timetableToday;
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: isDark
            ? theme.colorScheme.surface
            : theme.colorScheme.inversePrimary,
        elevation: 3,
        shadowColor: isDark ? Colors.black : Colors.black26,
        title: Text(titleText),
        leading: IconButton(
          onPressed: () {
            PublicEventBus.eventBus.fire(ChangePageEvent('timetable'));
          },
          icon: Text(
            l10n.timetableOverview,
            style: TextStyle(
                fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => GoRouter.of(context).push(AppRouter.addSchedule),
            icon: const Icon(Icons.add_circle_outline, size: 28),
            tooltip: l10n.scheduleAddTitle,
          ),
        ],
      ),
      body: Column(
        children: [
          HeaderIsland(todayClass: todayClass, todayClassState: todayClassState),
          Expanded(
              child: Padding(
            padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16, top: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TimelineOverview(todayClass: todayClass, todayClassState: todayClassState),
                Expanded(
                    flex: 5,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child:
                          TimelineDetails(todayClass: todayClass, todayClassState: todayClassState),
                    ))
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class HeaderIsland extends StatefulWidget {
  final todayClass;
  final todayClassState;
  const HeaderIsland({super.key, this.todayClass, this.todayClassState});

  @override
  State<HeaderIsland> createState() => _HeaderIslandState();
}

class _HeaderIslandState extends State<HeaderIsland> {
  Timer? timer;
  int currentMinute = getMinutesFromTimeStr(getTimeStrFromDateTime(DateTime.now()));
  double progress = 0;
  String rightCountdown = '加载中...';

  @override
  void initState() {
    timer = Timer.periodic(const Duration(milliseconds: 1000), (Timer _timer) {
      refresh();
    });
    refresh();
    super.initState();
  }

  void refresh({int retryCount = 10}) {
    if (widget.todayClass.length == 0 && retryCount > 0) {
      Timer.periodic(Duration(milliseconds: 6 * (10 - retryCount) * (10 - retryCount)),
          (Timer _timer) {
        refresh(retryCount: retryCount - 1);
        _timer.cancel();
      });
      return;
    }
    String state = widget.todayClassState['nowState'];
    if (state == 'finished' || state == "hereafter") {
      setState(() {
        progress = 0.0;
        rightCountdown = "";
        currentMinute = getMinutesFromTimeStr(getTimeStrFromDateTime(DateTime.now()));
      });
      return;
    }
    if (!mounted) return;
    double p = 0.0;
    String t = "";
    int nowMin = getMinutesFromTimeStr(getTimeStrFromDateTime(DateTime.now().add(tmpOffset)));
    int startMin =
        getMinutesFromTimeStr(widget.todayClass[widget.todayClassState['nowIndex']]['startTime']);
    int endMin =
        getMinutesFromTimeStr(widget.todayClass[widget.todayClassState['nowIndex']]['endTime']);
    if (state == 'active') {
      int remainMin = endMin - nowMin - 1;
      p = (nowMin * 60 + DateTime.now().add(tmpOffset).second - startMin * 60) /
          (endMin * 60 - startMin * 60);
      t = "${(remainMin ~/ 60).toString().padLeft(2, '0')}:${(remainMin % 60).toString().padLeft(2, '0')}:${(59 - DateTime.now().add(tmpOffset).second).toString().padLeft(2, '0')}";
    } else if (state == 'upcoming') {
      int remainMin = startMin - nowMin - 1;
      p = 1.0;
      t = "${(remainMin ~/ 60).toString().padLeft(2, '0')}:${(remainMin % 60).toString().padLeft(2, '0')}:${(59 - DateTime.now().add(tmpOffset).second).toString().padLeft(2, '0')}";
    }
    if (!mounted) return;
    setState(() {
      currentMinute = getMinutesFromTimeStr(getTimeStrFromDateTime(DateTime.now()));
      rightCountdown = t;
      progress = p;
    });
  }

  @override
  void dispose() {
    if (timer != null) timer!.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String state = widget.todayClassState['nowState'];
    String centerText = l10n.loading;
    String leftTime = l10n.loading;
    String rightTime = l10n.loading;
    String leftText = l10n.loading;
    Color progressbarColor = Colors.white;
    if (state == 'finished') {
      centerText = '今日日程已结束';
      leftTime = '--:--';
      rightTime = '--:--';
      leftText = 'Have a nice day!';
    } else if (state == 'hereafter') {
      centerText = '今日日程已结束';
      leftTime = '--:--';
      rightTime = '--:--';

      leftText =
          '以下为${widget.todayClassState['nowDate'].year}年${widget.todayClassState['nowDate'].month}月${widget.todayClassState['nowDate'].day}日的日程预览';
    } else if (widget.todayClass.length > 0) {
      if (state == 'active' || state == 'upcoming') {
        var nowClass = widget.todayClass[widget.todayClassState['nowIndex']];
        if (state == 'active') {
          centerText = nowClass['name'];
          leftText = "备注: ${nowClass['note'] ?? nowClass['teacher']} · 地点: ${nowClass['location']}";
          progressbarColor = activeColor;
          if (progress <= 0.001) {
            // 过渡动画
            progressbarColor = Colors.amber.withAlpha(0);
            progress = 1;
          }
        } else if (state == 'upcoming') {
          centerText = '前往 ${nowClass['location']}';
          leftText =
              "任务: ${nowClass['name'].length >= 12 ? nowClass['name'].substring(0, 11) + "..." : nowClass['name']} · 地点: ${nowClass['location']}";
          progressbarColor = upcomingColor;
        }
        leftTime = widget.todayClass[widget.todayClassState['nowIndex']]['startTime'];
        rightTime = widget.todayClass[widget.todayClassState['nowIndex']]['endTime'];
      }
    }

    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: MaterialButton(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: EdgeInsets.all(0),
          onPressed: () {},
          child: Stack(
            children: [
              Container(
                // 大背景
                height: 100,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Theme.of(context).colorScheme.surfaceContainerHighest?.withAlpha(250) ?? Color.fromARGB(250, 238, 242, 249),
                    boxShadow: [
                      BoxShadow(
                          color: Theme.of(context).colorScheme.shadow.withAlpha(88), offset: Offset(1, 1), blurRadius: 8)
                    ]),
                child: Column(
                  children: [
                    Expanded(child: SizedBox()),
                    SizedBox(
                      height: 30,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                                child: Text(
                              leftText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )),
                            Text(
                              rightCountdown,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            )
                          ],
                        ),
                      ),
                    )
                  ],
                ),
              ),
              Container(
                // 进度条背景
                height: 70,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Theme.of(context).colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                          color: Theme.of(context).colorScheme.shadow.withAlpha(44), offset: Offset(0, 1), blurRadius: 3)
                    ]),
              ),
              SizedBox(
                // 进度条
                height: 70,
                child: ClipRect(
                  clipper: ProgressBarCilpper.fromProgress(progress),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: progressbarColor,
                    ),
                  ),
                ),
              ),
              SizedBox(
                // 顶层文字
                height: 70,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 50),
                    child: StrokeText(
                      strokeWidth: .66,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: centerText,
                      textStyle: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          height: 1.3,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                                color: Theme.of(context).colorScheme.shadow.withAlpha(22),
                                offset: Offset(1, 1),
                                blurRadius: 22)
                          ]),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 70,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      SizedBox(
                        height: 70,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.play_circle_outline,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            Text(
                              leftTime,
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            )
                          ],
                        ),
                      ),
                      Expanded(child: SizedBox()),
                      SizedBox(
                          height: 70,
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(Icons.exit_to_app, color: Color.fromARGB(122, 88, 88, 88)),
                                Text(
                                  rightTime,
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                )
                              ]))
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class ProgressBarCilpper extends CustomClipper<Rect> {
  var progress;
  ProgressBarCilpper.fromProgress(this.progress);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width * progress, size.height);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) {
    return true;
  }
}

class TimelineOverview extends StatefulWidget {
  final todayClass;
  final todayClassState;
  const TimelineOverview({super.key, this.todayClass, this.todayClassState});

  @override
  State<TimelineOverview> createState() => _TimelineState();
}

class _TimelineState extends State<TimelineOverview> {
  double arrowPosition = 0.0;
  Timer? timer;

  @override
  void initState() {
    timer = Timer.periodic(Duration(seconds: 1), (_timer) {
      updateArrowPosition();
    });
    updateArrowPosition();
    super.initState();
  }

  void updateArrowPosition() {
    setState(() {
      DateTime now = DateTime.now().add(tmpOffset);
      arrowPosition = ((now.hour * 3600 + now.minute * 60 + now.second) -
              (getMinutesFromTimeStr(wholeDayPeriod['start']!) * 60)) /
          (totalDailyMinutes * 60);
      if (arrowPosition < 0) {
        arrowPosition = 0;
      } else if (arrowPosition > 1) {
        arrowPosition = 1;
      }
    });
  }

  @override
  void dispose() {
    if (timer != null) timer!.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        width: 50,
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: LayoutBuilder(builder: (context, constraints) {
                final height = constraints.maxHeight;
                final width = constraints.maxWidth;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest ?? Color.fromARGB(255, 238, 241, 246),
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    for (var markedTime in markedTimes)
                      Positioned(
                          child: SizedBox(
                              width: width,
                              child: Center(
                                child: AutoSizeText(
                                  maxLines: 1,
                                  markedTime['time']!,
                                  minFontSize: 0,
                                  maxFontSize: 13,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).hintColor,
                                      fontWeight: FontWeight.bold,
                                      height: 1.4),
                                ),
                              )),
                          left: 0,
                          top: markedTime['align'] == 'end'
                              ? height * getPercentOfDayFromTimeStr(markedTime['time']!)
                              : null,
                          bottom: markedTime['align'] == 'start'
                              ? height * (1 - getPercentOfDayFromTimeStr(markedTime['time']!))
                              : null),
                    for (int i = 0; i < widget.todayClass.length; i++)
                      (() {
                        Map<String, dynamic> item = widget.todayClass[i];
                        return Positioned(
                            top: height * getPercentOfDayFromTimeStr(item['startTime']),
                            left: 0,
                            child: TimelineItem(
                              height: height * getPercentOfDayFromDuation(item['duration']),
                              index: i + 1,
                              state: widget.todayClassState['stateList'][i],
                            ));
                      })(),
                    if (widget.todayClassState['nowState'] != 'hereafter')
                      Positioned(
                        right: width,
                        top: height * arrowPosition,
                        child: Container(
                          margin: EdgeInsets.only(left: 31),
                          width: 0,
                          height: 0,
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 11,
                                  style: BorderStyle.solid),
                              bottom: BorderSide(
                                  color: Colors.transparent, width: 5, style: BorderStyle.solid),
                              left: BorderSide(
                                  color: Colors.transparent, width: 11, style: BorderStyle.solid),
                              top: BorderSide(
                                  color: Colors.transparent, width: 5, style: BorderStyle.solid),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              }),
            )
          ],
        ),
      ),
    );
  }
}

class TimelineItem extends StatefulWidget {
  final double? height;
  final int? index;
  final String? state;
  const TimelineItem({super.key, this.height, this.index, this.state});

  @override
  State<TimelineItem> createState() => _TimelineItemState();
}

class _TimelineItemState extends State<TimelineItem> {
  @override
  Widget build(BuildContext context) {
    final stateStyleMap = <String, Map<String, dynamic>>{
      'passed': {
        'backgroundColor': Color.fromARGB(0, 0, 0, 0),
        'borderColor': Theme.of(context).colorScheme.outlineVariant,
        'borederWidth': 3.0,
        'fontColor': Theme.of(context).colorScheme.onSurfaceVariant
      },
      'upcoming': {
        'backgroundColor': Theme.of(context).colorScheme.primaryContainer.withAlpha(199),
        'borderColor': Theme.of(context).colorScheme.outline,
        'borederWidth': 3.0,
        'fontColor': Theme.of(context).colorScheme.onPrimaryContainer
      },
      'active': {
        'backgroundColor': Theme.of(context).colorScheme.primaryContainer,
        'borderColor': Theme.of(context).colorScheme.primary,
        'borederWidth': 3.0,
        'fontColor': Theme.of(context).colorScheme.onPrimaryContainer
      },
      'future': {
        'backgroundColor': Theme.of(context).colorScheme.primaryContainer.withAlpha(199),
        'borderColor': Theme.of(context).colorScheme.outlineVariant,
        'borederWidth': 3.0,
        'fontColor': Theme.of(context).colorScheme.onSurfaceVariant
      }
    };
    return Container(
      width: 50,
      height: widget.height,
      decoration: BoxDecoration(
          color: stateStyleMap[widget.state]?['backgroundColor'],
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: stateStyleMap[widget.state]?['borderColor'],
            width: stateStyleMap[widget.state]?['borederWidth'],
          )),
      child: Center(
          child: AutoSizeText(
        widget.index.toString(),
        minFontSize: 0,
        style: TextStyle(
            color: stateStyleMap[widget.state]?['fontColor'],
            fontWeight: FontWeight.bold,
            height: 1,
            fontSize: widget.height! > 53 ? 22 : 17),
      )),
    );
  }
}

class TimelineDetails extends StatefulWidget {
  final todayClass;
  final todayClassState;
  const TimelineDetails({super.key, this.todayClass, this.todayClassState});

  @override
  State<TimelineDetails> createState() => _TimelineDetailsState();
}

class _TimelineDetailsState extends State<TimelineDetails> {
  @override
  Widget build(BuildContext context) {
    return Container(
        child: Timeline.tileBuilder(
      theme: TimelineThemeData(
        nodePosition: 0,
        color: Theme.of(context).colorScheme.outline,
        indicatorTheme: IndicatorThemeData(
          position: 0.11,
          size: 28.0,
        ),
        connectorTheme: ConnectorThemeData(
          thickness: 4.5,
        ),
      ),
      builder: TimelineTileBuilder.connected(
          connectionDirection: ConnectionDirection.before,
          itemCount: widget.todayClass.length,
          contentsBuilder: (_, index) {
            return Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: ElevatedButton(
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
                                    DateTime.now().add(tmpOffset).toString().split(' ')[0],
                                    style: TextStyle(fontSize: 16, color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey[600]!),
                                  )
                                ],
                              ),
                              content: ClassInfoDetail(
                                detail: widget.todayClass[index]['others'],
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
                      style: ButtonStyle(
                          padding: WidgetStateProperty.all(EdgeInsets.all(0)),
                          shape: WidgetStateProperty.all(
                              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))),
                      child: Container(
                        margin: EdgeInsets.all(14),
                        width: double.infinity,
                        // height: 88,
                        child: Stack(
                          children: [
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Text(
                                (index + 1).toString(),
                                style: TextStyle(
                                    fontSize: 90,
                                    height: 1,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onSurface.withAlpha(28)),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Text(
                                  widget.todayClass[index]['name'],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontSize: 22,
                                      height: 1,
                                      fontWeight: FontWeight.bold),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 6.0),
                                  child: Text(
                                    "地点: ${widget.todayClass[index]['location']}\n备注: ${widget.todayClass[index]['note'] ?? widget.todayClass[index]['teacher']}\n时间: ${widget.todayClass[index]['startTime']}-${widget.todayClass[index]['endTime']}",
                                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  ),
                                )
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                ],
              ),
            );
          },
          indicatorBuilder: (_, index) {
            if (widget.todayClassState['stateList'][index] == 'passed') {
              return DotIndicator(
                border: Border.all(color: Colors.green, width: 2.5),
                color: Color(0xff66c97f),
                child: Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 20.0,
                ),
              );
            }
            if (widget.todayClassState['stateList'][index] == 'upcoming') {
              return DotIndicator(
                  border: Border.all(color: Color.fromARGB(255, 69, 145, 252), width: 2.5),
                  color: Color.fromARGB(255, 90, 156, 248),
                  child: Icon(
                    Icons.next_plan_rounded,
                    color: Colors.white,
                    size: 20.0,
                  ));
            }
            if (widget.todayClassState['stateList'][index] == 'active') {
              return DotIndicator(
                  border: Border.all(color: Color.fromARGB(255, 69, 145, 252), width: 2.5),
                  color: Color.fromARGB(255, 90, 156, 248),
                  child: Padding(
                    padding: const EdgeInsets.all(.4),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ));
            }
            return OutlinedDotIndicator(
              borderWidth: 2.5,
            );
          },
          connectorBuilder: (_, index, ___) {
            String? state = widget.todayClassState['stateList'][index];
            if (state == 'passed' || state == 'active') {
              return SolidLineConnector(
                color: Color.fromARGB(255, 127, 213, 157),
              );
            }
            if (state == 'upcoming') {
              return SolidLineConnector(
                color: Color.fromARGB(255, 68, 211, 192),
              );
            }

            return SolidLineConnector();
          }),
    ));
  }
}
