import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/task.dart';

/// What the planner needs from reminders. Kept small so tests can fake it.
abstract class Reminders {
  Future<void> init();
  Future<bool> requestPermission();
  Future<void> syncTask(PlannerTask task);
  Future<void> cancelTask(String taskId);
  Future<void> scheduleFocusEnd(DateTime at, String taskTitle);
  Future<void> cancelFocusEnd();
}

class NoopReminders implements Reminders {
  @override
  Future<void> init() async {}
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> syncTask(PlannerTask task) async {}
  @override
  Future<void> cancelTask(String taskId) async {}
  @override
  Future<void> scheduleFocusEnd(DateTime at, String taskTitle) async {}
  @override
  Future<void> cancelFocusEnd() async {}
}

/// Gentle, local-only reminders. Nothing leaves the device.
class LocalReminders implements Reminders {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _focusEndId = 1;

  static const _reminderChannel = AndroidNotificationDetails(
    'gentle_reminders',
    'Gentle reminders',
    channelDescription: 'A soft heads-up before a task starts',
    importance: Importance.high,
    priority: Priority.high,
    category: AndroidNotificationCategory.reminder,
  );

  static const _focusChannel = AndroidNotificationDetails(
    'focus_timer',
    'Focus timer',
    channelDescription: 'Lets you know when a focus session ends',
    importance: Importance.high,
    priority: Priority.high,
    category: AndroidNotificationCategory.alarm,
  );

  @override
  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('Falling back to UTC for reminders: $e');
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_stat_brightday'),
      ),
    );
    _ready = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> requestPermission() async {
    await init();
    return await _android?.requestNotificationsPermission() ?? true;
  }

  /// Stable 31-bit id per task so rescheduling replaces the old reminder.
  static int idFor(String taskId) => (taskId.hashCode & 0x3fffffff) | 0x100;

  @override
  Future<void> syncTask(PlannerTask task) async {
    await init();
    final id = idFor(task.id);
    await _plugin.cancel(id: id);
    final startsAt = task.startsAt;
    final lead = task.reminderLeadMinutes;
    if (task.done || startsAt == null || lead == null) return;
    final fireAt = startsAt.subtract(Duration(minutes: lead));
    if (!fireAt.isAfter(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.from(fireAt, tz.local),
      notificationDetails: const NotificationDetails(android: _reminderChannel),
      // Inexact on purpose: no exact-alarm permission needed, and a minute
      // of drift is fine for a heads-up.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: '${task.emoji} ${task.title}',
      body: lead == 0
          ? 'Starting now. You\'ve got this.'
          : 'Starts in $lead min. A good moment to wrap up what you\'re doing.',
      payload: task.id,
    );
  }

  @override
  Future<void> cancelTask(String taskId) async {
    await init();
    await _plugin.cancel(id: idFor(taskId));
  }

  @override
  Future<void> scheduleFocusEnd(DateTime at, String taskTitle) async {
    await init();
    await _plugin.cancel(id: _focusEndId);
    if (!at.isAfter(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id: _focusEndId,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: const NotificationDetails(android: _focusChannel),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: 'Focus session done',
      body: 'Nice work on "$taskTitle". Take a breath.',
    );
  }

  @override
  Future<void> cancelFocusEnd() async {
    await init();
    await _plugin.cancel(id: _focusEndId);
  }
}
