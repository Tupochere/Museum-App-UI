import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'features/home/mtengatenga_home_screen.dart';

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
      home: const MtengatengaHomeScreen(),
    );
  }
}
