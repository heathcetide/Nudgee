import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nudgee/features/campus_forum/presentation/campus_discover.dart';
import 'package:nudgee/features/chat/presentation/chat_page.dart';
import 'package:nudgee/features/common/utils/events.dart';
import 'package:nudgee/features/profile/presentation/profile_portal.dart';
import 'package:nudgee/features/timetable/presentation/timetable.dart';
import 'package:nudgee/features/timetable/presentation/today_schedule.dart';
import 'package:nudgee/features/home/presentation/components_tab.dart';

/// Main home page — merged tab structure.
///
/// Bottom nav tabs: 课程表 / 校园圈 / 聊天 / 组件 / 我的.
/// Internal page switching via [PublicEventBus] `ChangePageEvent`
/// (e.g. todaySchedule ↔ timetable).
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _currentIndex = 0;
  StreamSubscription? _pageChangeSub;

  /// Internal state for the 课程表 tab.
  String _schedulePage = 'todaySchedule';

  @override
  void initState() {
    super.initState();
    _pageChangeSub =
        PublicEventBus.eventBus.on<ChangePageEvent>().listen((event) {
      // todaySchedule ↔ timetable internal switching
      if (event.pageName == 'todaySchedule' ||
          event.pageName == 'timetable') {
        setState(() => _schedulePage = event.pageName);
      }
    });
  }

  @override
  void dispose() {
    _pageChangeSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _ScheduleTab(
        page: _schedulePage,
        onPageChanged: (p) => setState(() => _schedulePage = p),
      ),
      const CampusDiscover(),
      const ChatPage(),
      ComponentsTab(),
      const ProfilePortal(),
    ];
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.event_note_outlined),
            activeIcon: Icon(Icons.event_note),
            label: '课程表',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt_outlined),
            activeIcon: Icon(Icons.camera_alt),
            label: '校园圈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_outlined),
            activeIcon: Icon(Icons.chat),
            label: '聊天',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.widgets_outlined),
            activeIcon: Icon(Icons.widgets),
            label: '组件',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}

/// 课程表 tab — wraps todaySchedule / timetable with event-bus switching.
class _ScheduleTab extends StatefulWidget {
  final String page;
  final ValueChanged<String> onPageChanged;

  const _ScheduleTab({required this.page, required this.onPageChanged});

  @override
  State<_ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<_ScheduleTab> {
  late String _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.page;
  }

  @override
  void didUpdateWidget(covariant _ScheduleTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page != widget.page) {
      _currentPage = widget.page;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: _currentPage == 'timetable' ? 1 : 0,
      children: const [
        TodaySchedule(),
        Timetable(),
      ],
    );
  }
}
