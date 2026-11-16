import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../../features/subscriptions/domain/subscription_model.dart';

abstract final class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool _exactAlarmsAllowed = false;
  static bool _supportsScheduledNotifications = false;

  static Future<void> initialize() async {
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      return;
    }
    tzdata.initializeTimeZones();
    final localTimeZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTimeZone.identifier));
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
      linux: LinuxInitializationSettings(
        defaultActionName: 'Open notification',
      ),
    );
    await _plugin.initialize(settings);
    _initialized = true;
    _supportsScheduledNotifications = true;
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    _exactAlarmsAllowed =
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestExactAlarmsPermission() ??
        false;
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    await _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static Future<void> schedule(
    Subscription item,
    String paymentMethodName,
  ) async {
    if (!_initialized ||
        !_supportsScheduledNotifications ||
        item.reminderDaysBefore == 0) {
      return;
    }
    final scheduleDate = item.nextBillingDate.subtract(
      Duration(days: item.reminderDaysBefore),
    );
    final now = DateTime.now();
    final localDate = DateTime(
      scheduleDate.year,
      scheduleDate.month,
      scheduleDate.day,
      9,
    );
    if (!localDate.isAfter(now)) return;
    await _plugin.zonedSchedule(
      item.id.hashCode,
      'Upcoming Renewal: ${item.name}',
      '${item.currencyCode} ${item.amount.toStringAsFixed(2)} bills on '
          '${item.nextBillingDate.toLocal().toString().split(' ').first}'
          '${paymentMethodName.isEmpty ? '' : ' via $paymentMethodName'}.',
      tz.TZDateTime.from(localDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'renewals',
          'Subscription renewals',
          channelDescription: 'Upcoming subscription payment reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: _exactAlarmsAllowed
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: item.id,
    );
  }

  static Future<void> cancel(Subscription item) async {
    if (_initialized) await _plugin.cancel(item.id.hashCode);
  }
}
