import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:driver/domain/di/dependency_manager.dart';

/// Centralized FCM token management service.
/// Ensures the FCM token is always registered with the backend,
/// both on app start and when the token refreshes.
class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  bool _initialized = false;

  /// Initialize FCM: request permissions, get token, listen for refresh.
  /// Call this once after Firebase.initializeApp() and after user is logged in.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Request notification permission (critical for Android 13+ and iOS)
    await _requestPermission();

    // Register current token
    await _registerToken();

    // Listen for token refresh and re-register
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      debugPrint('===> FCM token refreshed: ${newToken.substring(0, 20)}...');
      _sendTokenToBackend(newToken);
    });
  }

  Future<void> _requestPermission() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      );
      debugPrint('===> FCM permission status: ${settings.authorizationStatus}');

      // For iOS foreground presentation
      if (Platform.isIOS) {
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } catch (e) {
      debugPrint('===> FCM permission error: $e');
    }
  }

  Future<void> _registerToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        debugPrint('===> FCM token obtained: ${token.substring(0, 20)}...');
        await _sendTokenToBackend(token);
      } else {
        debugPrint('===> FCM token is null');
      }
    } catch (e) {
      debugPrint('===> FCM getToken error: $e');
    }
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      final result = await userRepository.updateFirebaseToken(token);
      result.when(
        success: (_) {
          debugPrint('===> FCM token registered with backend successfully');
        },
        failure: (error, statusCode) {
          debugPrint('===> FCM token registration failed: $error (status: $statusCode)');
        },
      );
    } catch (e) {
      debugPrint('===> FCM token send error: $e');
    }
  }

  /// Force re-register the token (e.g., after login).
  Future<void> refreshToken() async {
    await _registerToken();
  }
}
