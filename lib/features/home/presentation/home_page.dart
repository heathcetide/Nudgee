import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nudgee/app/router/app_router.dart';
import 'package:nudgee/features/campus_forum/presentation/campus_discover.dart';
import 'package:nudgee/features/chat/presentation/chat_page.dart';
import 'package:nudgee/features/common/utils/events.dart';
import 'package:nudgee/features/profile/presentation/profile_portal.dart';
import 'package:nudgee/features/timetable/presentation/timetable.dart';
import 'package:nudgee/features/timetable/presentation/today_schedule.dart';
import 'package:nudgee/core/extensions/context_extensions.dart';

/// Main home page — merged tab structure.
///
/// Bottom nav tabs: 日程 / 个人圈 / [+发布] / 聊天 / 我的.
/// The center "+" button opens the post creation page.
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
    final theme = Theme.of(context);

    // 4 content pages; the "+" is a separate action button (not a tab).
    final pages = [
      _ScheduleTab(
        page: _schedulePage,
        onPageChanged: (p) => setState(() => _schedulePage = p),
      ),
      const CampusDiscover(),
      const ChatPage(),
      const ProfilePortal(),
    ];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: _buildBottomNav(theme),
    );
  }

  Widget _buildBottomNav(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withAlpha(80),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              _buildTabItem(
                icon: Icons.event_note_outlined,
                activeIcon: Icons.event_note,
                label: context.l10n.navTimetable,
                index: 0,
                theme: theme,
              ),
              _buildTabItem(
                icon: Icons.camera_alt_outlined,
                activeIcon: Icons.camera_alt,
                label: context.l10n.navCampus,
                index: 1,
                theme: theme,
              ),
              // Center "+" button
              _buildCenterButton(theme),
              _buildTabItem(
                icon: Icons.chat_outlined,
                activeIcon: Icons.chat,
                label: context.l10n.navChat,
                index: 2,
                theme: theme,
              ),
              _buildTabItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: context.l10n.navProfile,
                index: 3,
                theme: theme,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required ThemeData theme,
  }) {
    final isActive = _currentIndex == index;
    final color = isActive
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _currentIndex = index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isActive ? activeIcon : icon, size: 24, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: color, fontWeight: isActive ? FontWeight.w600 : FontWeight.normal),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterButton(ThemeData theme) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push(AppRouter.createPost),
        child: Transform.translate(
          offset: const Offset(0, -16),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withAlpha(100),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.add,
              size: 34,
              color: theme.colorScheme.onPrimary,
            ),
          ),
        ),
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
