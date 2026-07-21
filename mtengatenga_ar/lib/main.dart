import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_it/get_it.dart';
import 'core/services/auth_state.dart';
import 'core/services/service_locator.dart';
import 'core/ui/shell/app_shell.dart';
import 'features/auth/auth_gate.dart';
import 'theme/app_theme.dart';
import 'theme/app_tokens.dart';

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
    final authState = GetIt.instance<AuthStateNotifier>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: ListenableBuilder(
        listenable: authState,
        builder: (context, _) {
          if (authState.isLoading) {
            return const Scaffold(
              backgroundColor: AppColors.backgroundLight,
              body: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }
          if (authState.isAuthenticated) {
            return const AppShell();
          }
          return const AuthGate();
        },
      ),
    );
  }
}
