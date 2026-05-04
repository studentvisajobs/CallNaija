import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'call_service.dart';
import 'incoming_call_screen.dart';

class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static late GlobalKey<NavigatorState> navigatorKey;

  static Future<void> init(GlobalKey<NavigatorState> navKey) async {
    navigatorKey = navKey;

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final token = await _messaging.getToken();

    if (token != null && CallService.currentUserPhone != null) {
      await CallService.savePushToken(token);
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleIncomingCall(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleIncomingCall(message);
    });
  }

  static Future<void> _handleIncomingCall(RemoteMessage message) async {
    final data = message.data;

    if (data['type'] != 'incoming_call') return;

    final pending = await CallService.getPendingCall();

    if (pending == null) return;

    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => IncomingCallScreen(
          fromPhone: pending['fromPhone']?.toString() ?? '',
          fromName: pending['fromName']?.toString() ?? 'Incoming call',
          offer: pending['offer'],
        ),
      ),
    );
  }
}