import 'package:event_bus/event_bus.dart';

class PublicEventBus {
  static final eventBus = EventBus();
}

class ChangePageEvent {
  final String pageName;
  ChangePageEvent(this.pageName);
}

class TimetableChangePageEvent {
  final String pageName;
  TimetableChangePageEvent(this.pageName);
}

class AppbarActionMenuClickEvent {
  final String key;
  final Map<String, dynamic> menu;
  AppbarActionMenuClickEvent(this.key, this.menu);
}
