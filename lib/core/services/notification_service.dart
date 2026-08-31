import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../app/constants/app_constants.dart';
import '../api/supabase_client.dart';
import 'auth_service.dart';

class AppNotification {
  final String id;
  final String residentId;
  final String type; // maintenance, payment, insurance, general
  final String title;
  final String message;
  final bool isRead;
  final String? relatedEntityType;
  final String? relatedEntityId;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.residentId,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    this.relatedEntityType,
    this.relatedEntityId,
    required this.createdAt,
  });

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      residentId: residentId,
      type: type,
      title: title,
      message: message,
      isRead: isRead ?? this.isRead,
      relatedEntityType: relatedEntityType,
      relatedEntityId: relatedEntityId,
      createdAt: createdAt,
    );
  }
}

class NotificationService {
  final AuthService _authService;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  List<AppNotification> _mockNotifications = [];
  final _notificationsStreamController =
      StreamController<List<AppNotification>>.broadcast();

  NotificationService(this._authService) {
    _initializeLocalNotifications();
    _initMockData();
  }

  Stream<List<AppNotification>> get notificationsStream =>
      _notificationsStreamController.stream;

  void _initMockData() {
    final now = DateTime.now();
    _mockNotifications = [
      AppNotification(
        id: 'notify-1',
        residentId: 'mock-user-123',
        type: 'general',
        title: 'Fire Alarm Testing',
        message:
            'Annual fire alarm testing will take place tomorrow between 10 AM and 2 PM. Please expect loud noises.',
        isRead: true,
        createdAt: now.subtract(const Duration(hours: 2, minutes: 15)),
      ),
      AppNotification(
        id: 'notify-2',
        residentId: 'mock-user-456',
        type: 'payment',
        title: 'Rent Claim Bill: September 2026',
        message:
            'A rent bill of \$1900.00 has been issued. Due date: 09/01/2026.',
        isRead: false,
        createdAt: now.subtract(const Duration(hours: 5, minutes: 40)),
      ),
      AppNotification(
        id: 'notify-3',
        residentId: 'mock-user-789',
        type: 'maintenance',
        title: 'Maintenance Schedule Confirmation',
        message:
            'Technician visit has been scheduled for tomorrow at 11:00 AM.',
        isRead: false,
        createdAt: now.subtract(const Duration(days: 1, hours: 3)),
      ),
      AppNotification(
        id: 'notify-4',
        residentId: 'mock-user-123',
        type: 'general',
        title: 'Water Shutoff Notice',
        message:
            'Water will be temporarily shut off in building B for emergency pipe repairs from 1 PM to 3 PM.',
        isRead: true,
        createdAt: now.subtract(const Duration(days: 3, hours: 6)),
      ),
      AppNotification(
        id: 'notify-5',
        residentId: 'mock-user-456',
        type: 'general',
        title: 'Building Pest Control',
        message:
            'Quarterly pest control services will be conducted on Friday morning. Please keep pets inside.',
        isRead: true,
        createdAt: now.subtract(const Duration(days: 5)),
      ),
    ];
    _notificationsStreamController.add(_mockNotifications);
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _localNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        if (kDebugMode) {
          print('Notification clicked with payload: ${details.payload}');
        }
      },
    );

    // Create high-importance notification channel with sound & vibration on Android
    final androidImplementation = _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          AppConstants.notificationChannelId,
          AppConstants.notificationChannelName,
          description: AppConstants.notificationChannelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );
      await androidImplementation.requestNotificationsPermission();
    }
  }

  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      AppConstants.notificationChannelId,
      AppConstants.notificationChannelName,
      channelDescription: AppConstants.notificationChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      channelShowBadge: true,
      ticker: 'ticker',
    );

    const DarwinNotificationDetails iosPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iosPlatformChannelSpecifics,
    );

    await _localNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  Future<List<AppNotification>> getNotifications() async {
    if (SupabaseClientHelper.isMockMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      return _mockNotifications;
    } else {
      try {
        final client = SupabaseClientHelper.client;
        final res = await client
            .from('notifications')
            .select()
            .eq('resident_id', _authService.currentUser?.id ?? '')
            .order('created_at', ascending: false);

        final list = (res as List).map((n) {
          return AppNotification(
            id: n['id'],
            residentId: n['resident_id'],
            type: n['type'],
            title: n['title'],
            message: n['message'],
            isRead: n['is_read'],
            relatedEntityType: n['related_entity_type'],
            relatedEntityId: n['related_entity_id'],
            createdAt: DateTime.parse(n['created_at']),
          );
        }).toList();

        _notificationsStreamController.add(list);
        return list;
      } catch (e) {
        throw Exception(e.toString());
      }
    }
  }

  Future<List<AppNotification>> getAllSentNotifications() async {
    if (SupabaseClientHelper.isMockMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      return List<AppNotification>.from(_mockNotifications);
    } else {
      try {
        final client = SupabaseClientHelper.client;
        final res = await client
            .from('notifications')
            .select()
            .order('created_at', ascending: false);

        final list = (res as List).map((n) {
          return AppNotification(
            id: n['id'],
            residentId: n['resident_id'],
            type: n['type'],
            title: n['title'],
            message: n['message'],
            isRead: n['is_read'],
            relatedEntityType: n['related_entity_type'],
            relatedEntityId: n['related_entity_id'],
            createdAt: DateTime.parse(n['created_at']),
          );
        }).toList();

        return list;
      } catch (e) {
        throw Exception(e.toString());
      }
    }
  }

  Future<void> markAllAsRead() async {
    if (SupabaseClientHelper.isMockMode) {
      _mockNotifications = _mockNotifications
          .map((n) => n.copyWith(isRead: true))
          .toList();
      _notificationsStreamController.add(_mockNotifications);
    } else {
      try {
        final client = SupabaseClientHelper.client;
        await client
            .from('notifications')
            .update({'is_read': true})
            .eq('resident_id', _authService.currentUser?.id ?? '');
        await getNotifications();
      } catch (e) {
        throw Exception(e.toString());
      }
    }
  }

  Future<void> markAsRead(String notificationId) async {
    if (SupabaseClientHelper.isMockMode) {
      _mockNotifications = _mockNotifications.map((n) {
        if (n.id == notificationId) {
          return n.copyWith(isRead: true);
        }
        return n;
      }).toList();
      _notificationsStreamController.add(_mockNotifications);
    } else {
      try {
        final client = SupabaseClientHelper.client;
        await client
            .from('notifications')
            .update({'is_read': true})
            .eq('id', notificationId);
        await getNotifications();
      } catch (e) {
        throw Exception(e.toString());
      }
    }
  }

  Future<void> sendNotification({
    required String residentId,
    required String title,
    required String message,
    required String type,
  }) async {
    try {
      await showLocalNotification(
        id: (DateTime.now().millisecondsSinceEpoch ~/ 1000) % 100000,
        title: title,
        body: message,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error showing local notification: $e');
      }
    }

    if (SupabaseClientHelper.isMockMode) {
      await Future.delayed(const Duration(milliseconds: 600));
      final newNotif = AppNotification(
        id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
        residentId: residentId,
        type: type,
        title: title,
        message: message,
        isRead: false,
        createdAt: DateTime.now(),
      );
      _mockNotifications.insert(0, newNotif);
      _notificationsStreamController.add(_mockNotifications);
    } else {
      try {
        final client = SupabaseClientHelper.client;
        await client.from('notifications').insert({
          'resident_id': residentId,
          'title': title,
          'message': message,
          'type': type,
          'is_read': false,
        });
      } catch (e) {
        throw Exception(e.toString());
      }
    }
  }
}
