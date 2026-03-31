import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/services/service_locator.dart';
import 'core/ui/shell/app_shell.dart';
import 'theme/app_theme.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _bootstrapServices();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const MtengatengaApp());
}

Future<void> _bootstrapServices() async {
  try {
    await dotenv.load(fileName: '.env');
    await Firebase.initializeApp();
    await ServiceLocator.setup().timeout(const Duration(seconds: 20));
  } catch (error, stackTrace) {
    debugPrint('Service bootstrap failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class MtengatengaApp extends StatelessWidget {
  const MtengatengaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AppShell(),
    );
  }
}
