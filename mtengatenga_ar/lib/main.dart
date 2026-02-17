import 'package:flutter/material.dart';
import 'core/ui/shell/app_shell.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MtengatengaApp());
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
