import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../database/database_helper.dart';
import '../database/database_constants.dart';

/// Manages local push notifications for low stock and other alerts.
class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'kita_alerts';
  static const _channelName = 'Kita POS Alerts';
  static const _channelDesc =
      'Low stock warnings, expiration notices, and other store alerts.';

  /// Call once at app startup.
  static Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(settings);

    // Create the notification channel (Android 8+)
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Request permission on Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Check inventory for low-stock items and fire notifications.
  static Future<void> checkLowStockAndNotify() async {
    try {
      final db = await DatabaseHelper().database;
      final lowStock = await db.rawQuery('''
        SELECT ${DbConstants.colId}, ${DbConstants.colProductName},
               ${DbConstants.colCurrentStock}, ${DbConstants.colMinimumThreshold}
        FROM ${DbConstants.tableInventory}
        WHERE ${DbConstants.colIsArchived} = 0
          AND ${DbConstants.colCurrentStock} <= ${DbConstants.colMinimumThreshold}
        LIMIT 5
      ''');

      for (int i = 0; i < lowStock.length; i++) {
        final row = lowStock[i];
        final name = row[DbConstants.colProductName] as String;
        final stock = (row[DbConstants.colCurrentStock] as num).toInt();

        await _showNotification(
          id: (row[DbConstants.colId] as int),
          title: '⚠️ Low Stock: $name',
          body: 'Only $stock left. Tap to restock.',
        );
      }

      // Single summary if multiple
      if (lowStock.length > 1) {
        await _showNotification(
          id: 9999,
          title: '⚠️ ${lowStock.length} items are running low',
          body: 'Tap to view your inventory.',
        );
      }
    } catch (e) {
      debugPrint('[NotificationService] Error: $e');
    }
  }

  static Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );
    await _plugin.show(id, title, body, details);
  }
}
