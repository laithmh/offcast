import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme/app_theme.dart';

class PermissionHelper {
  PermissionHelper._();

  /// Checks if all required permissions for screen capture & hotspot signaling are granted
  static Future<bool> hasRequiredPermissions() async {
    if (!Platform.isAndroid) return true;

    final notifStatus = await Permission.notification.status;
    return notifStatus.isGranted;
  }

  /// Checks if camera permission is granted
  static Future<bool> hasCameraPermission() async {
    if (!Platform.isAndroid) return true;
    return (await Permission.camera.status).isGranted;
  }

  /// Checks if microphone permission is granted
  static Future<bool> hasMicPermission() async {
    if (!Platform.isAndroid) return true;
    return (await Permission.microphone.status).isGranted;
  }

  /// Explicitly requests camera and microphone permissions for studio camera and VAD prompter
  static Future<bool> requestCameraAndMicPermissions(BuildContext context) async {
    if (!Platform.isAndroid) return true;

    final camStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();

    if (camStatus.isGranted) {
      return true;
    }

    if (camStatus.isPermanentlyDenied || micStatus.isPermanentlyDenied) {
      if (context.mounted) {
        showPermissionSettingsDialog(context, isCameraOrMic: true);
      }
      return false;
    }

    return camStatus.isGranted;
  }

  /// Explicitly requests notification and nearby Wi-Fi permissions needed for hotspot discovery
  static Future<bool> requestPermissions(BuildContext context) async {
    if (!Platform.isAndroid) return true;

    // 1. Request notification permission (Required for Android 13+ FGS)
    final notifStatus = await Permission.notification.request();

    // 2. Request nearby Wi-Fi devices permission for Android 13+
    try {
      await Permission.nearbyWifiDevices.request();
    } catch (_) {}

    if (notifStatus.isGranted) {
      return true;
    }

    if (notifStatus.isPermanentlyDenied) {
      if (context.mounted) {
        showPermissionSettingsDialog(context);
      }
      return false;
    }

    return notifStatus.isGranted;
  }

  /// Displays an explanation dialog directing the user to Android App Settings
  static void showPermissionSettingsDialog(
    BuildContext context, {
    bool isCameraOrMic = false,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.security_rounded, color: AppTheme.warning),
            SizedBox(width: 10),
            Text(
              'Permission Required',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(
          isCameraOrMic
              ? 'Camera and Microphone permissions are required for Direct Studio Camera streaming and voice-activated teleprompter scrolling.\n\nPlease enable Camera and Microphone in App Settings.'
              : 'Android requires Notification and Local Network permissions to capture and stream your screen over the Hotspot without being stopped in the background.\n\nPlease enable Notifications in App Settings.',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
