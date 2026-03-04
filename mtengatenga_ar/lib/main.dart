import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/services/service_locator.dart';
import 'core/ui/shell/app_shell.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MtengatengaApp());
  unawaited(_bootstrapServices());
}

Future<void> _bootstrapServices() async {
  try {
    await dotenv.load(fileName: '.env');
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
