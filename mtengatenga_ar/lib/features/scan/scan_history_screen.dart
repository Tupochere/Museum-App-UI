import 'package:flutter/material.dart';
import '../../theme/app_tokens.dart';

class ScanHistoryScreen extends StatelessWidget {
  const ScanHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Scan History'),
      ),
      body: const Center(
        child: Text('No scan history yet'),
      ),
    );
  }
}
