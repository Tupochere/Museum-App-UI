import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/artifact.dart';

class ScanHistoryService {
  static const String _storageKey = 'scan_history_entries';
  static const int _maxEntries = 200;

  Future<List<Map<String, dynamic>>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storageKey) ?? <String>[];

    return raw
        .map((item) => jsonDecode(item) as Map<String, dynamic>)
        .toList();
  }

  Future<void> addScan(Artifact artifact) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();

    history.removeWhere((entry) => entry['artifact_id'] == artifact.id);

    history.insert(0, {
      'artifact_id': artifact.id,
      'artifact_name': artifact.name,
      'scanned_at': DateTime.now().toIso8601String(),
    });

    if (history.length > _maxEntries) {
      history.removeRange(_maxEntries, history.length);
    }

    final encoded = history.map(jsonEncode).toList();
    await prefs.setStringList(_storageKey, encoded);
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
