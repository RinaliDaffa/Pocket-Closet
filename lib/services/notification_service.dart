import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  NotificationService._init();

  // ========================
  // INIT
  // ========================
  Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

    const androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings);

    // Request permission notifikasi (Android 13+)
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // ========================
  // CHANNEL DETAILS
  // ========================
  AndroidNotificationDetails get _highPriorityChannel =>
      const AndroidNotificationDetails(
        'pocket_closet_main',
        'Pocket Closet',
        channelDescription: 'Notifikasi utama Pocket Closet',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFFD4AF37),
        playSound: true,
      );

  AndroidNotificationDetails get _reminderChannel =>
      const AndroidNotificationDetails(
        'pocket_closet_reminder',
        'Daily Reminder',
        channelDescription: 'Pengingat harian outfit',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFFD4AF37),
      );

  // ========================
  // NOTIF LANGSUNG — setelah tambah pakaian
  // ========================
  Future<void> showClothingAdded(String clothingName) async {
    await _plugin.show(
      0,
      '✓ Pakaian Ditambahkan',
      '$clothingName berhasil masuk ke lemari digitalmu',
      NotificationDetails(android: _highPriorityChannel),
    );
  }

  // ========================
  // NOTIF LANGSUNG — setelah set OOTD
  // ========================
  Future<void> showOotdSet(String outfitName) async {
    await _plugin.show(
      1,
      '👗 OOTD Hari Ini',
      '$outfitName dipilih sebagai outfit of the day!',
      NotificationDetails(android: _highPriorityChannel),
    );
  }

  // ========================
  // NOTIF LANGSUNG — pengingat cuci baju
  // ========================
  Future<void> showLaundryReminder(int dirtyCount) async {
    await _plugin.show(
      2,
      '🧺 Waktunya Cuci Baju!',
      '$dirtyCount pakaian menunggu untuk dicuci',
      NotificationDetails(android: _highPriorityChannel),
    );
  }

  // ========================
  // NOTIF TERJADWAL — harian jam 07.30
  // ========================
  Future<void> scheduleDailyOotdReminder() async {
    await _plugin.zonedSchedule(
      3,
      '☀️ Selamat Pagi!',
      'Sudah pilih outfit hari ini? Buka Pocket Closet sekarang',
      _nextInstanceOf(7, 30),
      NotificationDetails(android: _reminderChannel),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
    tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  // ========================
  // CANCEL
  // ========================
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}