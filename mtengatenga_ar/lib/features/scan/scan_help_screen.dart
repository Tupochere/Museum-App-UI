import 'package:flutter/material.dart';
import '../../theme/app_tokens.dart';

class ScanHelpScreen extends StatelessWidget {
  const ScanHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Scan Help'),
      ),
      body: const Center(
        child: Text('Point camera at an artifact to scan'),
      ),
    );
  }
}
