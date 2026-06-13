// services/notification_service.dart

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(initSettings);
  }

  Future<void> requestPermissions() async {
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();
  }

  // 1. FERMENTATION COMPLETE (7 DAYS)
  Future<void> scheduleFermentationComplete() async {
    final scheduledTime = tz.TZDateTime.now(tz.local).add(const Duration(days: 7));

    await _notificationsPlugin.zonedSchedule(
      0, 
      'Fermentation Complete! 🍌',
      'Your BioNana batch has finished its 7-day cycle. It is ready!',
      scheduledTime,
      _getPlatformDetails(color: const Color(0xFF266533)),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // 2. INGREDIENT REMINDER (30 MINUTES)
  Future<void> scheduleIngredientReminder() async {
    // Schedules a reminder 30 minutes from when Awaiting Molasses starts
    final scheduledTime = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 30));

    await _notificationsPlugin.zonedSchedule(
      1, 
      'Action Required: Molasses Needed ⚠️',
      'The sap is ready! Please add molasses to prevent spoilage.',
      scheduledTime,
      _getPlatformDetails(color: const Color(0xFFDCC115)),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelIngredientReminder() async {
    await _notificationsPlugin.cancel(1); // Cancels the specific 30-min timer
  }

  // 3. IMMEDIATE URGENT ALERTS (TEMP / FAILSAFE)
  Future<void> showUrgentAlert({required int id, required String title, required String body}) async {
    await _notificationsPlugin.show(
      id,
      title,
      body,
      _getPlatformDetails(color: const Color(0xFFFF3B30), importance: Importance.max, priority: Priority.max),
    );
  }

  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  // Helper for notification styling
  NotificationDetails _getPlatformDetails({required Color color, Importance importance = Importance.high, Priority priority = Priority.high}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'bionana_channel_id',
        'BioNana Notifications',
        channelDescription: 'Important alerts for BioNana operations',
        importance: importance,
        priority: priority,
        icon: '@mipmap/launcher_icon',
        color: color, 
      ),
      iOS: const DarwinNotificationDetails(),
    );
  }
}