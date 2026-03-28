import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Global language state ──────────────────────────────────────────────────

class LanguageState extends ValueNotifier<String> {
  static const String _prefsKey = 'app_language';
  static const String defaultLanguage = 'en';

  LanguageState() : super(defaultLanguage);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    value = prefs.getString(_prefsKey) ?? defaultLanguage;
  }

  Future<void> setLanguage(String code) async {
    if (value == code) return;
    value = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, code);
  }

  bool get isEnglish => value == 'en';
}

// ── Translation service ────────────────────────────────────────────────────

class TranslationService {
  TranslationService(this._languageState);

  final LanguageState _languageState;

  String get _cloudFunctionUrl =>
      dotenv.env['CLOUD_FUNCTION_URL']?.trim() ?? '';

  final Map<String, String> _cache = {};

  String get currentLanguage => _languageState.value;

  /// Translate [text] into the current app language.
  /// Returns original text if language is English or on error.
  Future<String> translate(String text) async {
    final target = _languageState.value;
    if (target == 'en' || text.trim().isEmpty) return text;
    return translateTo(text, target);
  }

  /// Translate [text] to a specific [targetLanguage].
  Future<String> translateTo(String text, String targetLanguage) async {
    if (targetLanguage == 'en' || text.trim().isEmpty) return text;

    final cacheKey = '${text.hashCode}|$targetLanguage';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    if (_cloudFunctionUrl.isEmpty) return text;

    final client = HttpClient();
    try {
      final request = await client.postUrl(
        Uri.parse('$_cloudFunctionUrl/translate'),
      );
      request.headers.contentType = ContentType.json;
      request.add(utf8.encode(jsonEncode({
        'text': text,
        'targetLanguage': targetLanguage,
      })));

      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();

      if (response.statusCode != 200) {
        debugPrint('Translation failed (${response.statusCode}): $body');
        return text;
      }

      final json = jsonDecode(body) as Map<String, dynamic>;
      final translated = json['translatedText'] as String? ?? text;
      _cache[cacheKey] = translated;
      return translated;
    } catch (e) {
      debugPrint('TranslationService error: $e');
      return text;
    } finally {
      client.close(force: true);
    }
  }
}
