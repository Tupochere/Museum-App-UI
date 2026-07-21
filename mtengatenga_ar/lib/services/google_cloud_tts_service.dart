import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GoogleCloudSpeechClip {
  final Uint8List wavBytes;
  final Duration duration;

  const GoogleCloudSpeechClip({
    required this.wavBytes,
    required this.duration,
  });
}

class GoogleCloudTtsService {
  static const String _defaultVoice = 'en-US-Journey-F';
  static const String _defaultLanguage = 'en-US';
  static const int _maxRetries = 2;
  static const int _sampleRate = 24000;

  // ── Cloud Function proxy ────────────────────────────────────────────────

  String get _cloudFunctionUrl =>
      dotenv.env['CLOUD_FUNCTION_URL']?.trim() ?? '';

  bool get _useCloudFunction => _cloudFunctionUrl.isNotEmpty;

  Future<GoogleCloudSpeechClip> synthesizeSpeech(String text) async {
    if (_useCloudFunction) {
      return _synthesizeViaCloudFunction(text);
    }

    final apiKey = _resolveApiKey();
    if (apiKey.isEmpty) {
      throw StateError('Missing API key for Google Cloud TTS.');
    }

    final voice = _resolveVoice();
    final language = _resolveLanguage();
    Object? lastError;
    StackTrace? lastStackTrace;

    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      final client = HttpClient();
      try {
        final request = await client.postUrl(
          Uri.parse(
            'https://texttospeech.googleapis.com/v1/text:synthesize'
            '?key=$apiKey',
          ),
        );
        request.headers.contentType = ContentType.json;
        request.add(
          utf8.encode(
            jsonEncode({
              'input': {'text': text},
              'voice': {
                'languageCode': language,
                'name': voice,
              },
              'audioConfig': {
                'audioEncoding': 'LINEAR16',
                'sampleRateHertz': _sampleRate,
              },
            }),
          ),
        );

        final response = await request.close();
        final body = await utf8.decoder.bind(response).join();

        if (response.statusCode == 429 ||
            (response.statusCode >= 500 && response.statusCode < 600)) {
          lastError = HttpException(
            'Google Cloud TTS (${response.statusCode}): '
            '${_extractErrorMessage(body)}',
          );
          lastStackTrace = StackTrace.current;
          if (attempt < _maxRetries) {
            final delay = _retryDelay(attempt);
            debugPrint(
              'GoogleCloudTtsService: rate limited, retrying in '
              '${delay.inSeconds}s (attempt ${attempt + 1}/$_maxRetries)',
            );
            await Future.delayed(delay);
            continue;
          }
          Error.throwWithStackTrace(lastError, lastStackTrace);
        }

        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw HttpException(
            'Google Cloud TTS failed (${response.statusCode}): '
            '${_extractErrorMessage(body)}',
          );
        }

        return _extractSpeechClip(body);
      } catch (e, st) {
        lastError = e;
        lastStackTrace = st;

        if (attempt < _maxRetries && _isRetryable(e)) {
          final delay = _retryDelay(attempt);
          debugPrint(
            'GoogleCloudTtsService: retryable error, retrying in '
            '${delay.inSeconds}s (attempt ${attempt + 1}/$_maxRetries)',
          );
          await Future.delayed(delay);
          continue;
        }

        debugPrint('GoogleCloudTtsService.synthesizeSpeech ERROR: $e');
        debugPrintStack(stackTrace: st);
        break;
      } finally {
        client.close(force: true);
      }
    }

    if (lastError != null && lastStackTrace != null) {
      Error.throwWithStackTrace(lastError, lastStackTrace);
    }
    throw StateError(
      'Google Cloud TTS failed before any attempt completed.',
    );
  }

  // ── Cloud Function helper ────────────────────────────────────────────────

  Future<GoogleCloudSpeechClip> _synthesizeViaCloudFunction(
    String text,
  ) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(
        Uri.parse('$_cloudFunctionUrl/tts'),
      );
      request.headers.contentType = ContentType.json;
      request.add(
        utf8.encode(
          jsonEncode({
            'text': text,
            'voice': _resolveVoice(),
            'languageCode': _resolveLanguage(),
          }),
        ),
      );

      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();

      if (response.statusCode != 200) {
        throw HttpException(
          'Cloud function /tts failed (${response.statusCode}): '
          '${_extractErrorMessage(body)}',
        );
      }

      return _extractSpeechClip(body);
    } finally {
      client.close(force: true);
    }
  }

  // ── Config ───────────────────────────────────────────────────────────────

  String _resolveApiKey() {
    // Prefer a dedicated TTS key; fall back to the Gemini key since both
    // are Google Cloud API keys and may share the same project.
    final ttsKey = dotenv.env['GOOGLE_CLOUD_TTS_KEY']?.trim() ?? '';
    if (ttsKey.isNotEmpty) return ttsKey;
    return dotenv.env['GEMINI_API_KEY']?.trim() ?? '';
  }

  String _resolveVoice() {
    final configured = dotenv.env['GOOGLE_CLOUD_TTS_VOICE']?.trim();
    if (configured == null || configured.isEmpty) return _defaultVoice;
    return configured;
  }

  String _resolveLanguage() {
    final configured = dotenv.env['GOOGLE_CLOUD_TTS_LANGUAGE']?.trim();
    if (configured == null || configured.isEmpty) return _defaultLanguage;
    return configured;
  }

  // ── Retry helpers ────────────────────────────────────────────────────────

  static bool _isRetryable(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('429') ||
        msg.contains('rate limit') ||
        msg.contains('quota') ||
        msg.contains('502') ||
        msg.contains('503');
  }

  static Duration _retryDelay(int attempt) {
    final baseMs = 2000 * pow(2, attempt).toInt();
    final jitterMs = Random().nextInt(800);
    return Duration(milliseconds: baseMs + jitterMs);
  }

  // ── Response parsing ─────────────────────────────────────────────────────

  String _extractErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic> && error['message'] is String) {
          return error['message'] as String;
        }
      }
    } catch (_) {
      // Fall through to raw body.
    }
    return body.length > 200 ? body.substring(0, 200) : body;
  }

  GoogleCloudSpeechClip _extractSpeechClip(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Google Cloud TTS returned invalid JSON.',
      );
    }

    final audioContent = decoded['audioContent'];
    if (audioContent is! String || audioContent.isEmpty) {
      throw const FormatException(
        'Google Cloud TTS returned no audioContent.',
      );
    }

    // audioContent is base64-encoded LINEAR16 PCM (no WAV header).
    final pcmBytes = base64Decode(audioContent);
    final wavBytes = _wrapPcmAsWav(pcmBytes);
    final durationMicros = pcmBytes.isEmpty
        ? 0
        : (pcmBytes.length * Duration.microsecondsPerSecond) ~/
            (_sampleRate * 2); // 16-bit mono = 2 bytes per sample
    return GoogleCloudSpeechClip(
      wavBytes: wavBytes,
      duration: Duration(microseconds: durationMicros),
    );
  }

  // ── WAV wrapper ──────────────────────────────────────────────────────────

  Uint8List _wrapPcmAsWav(Uint8List pcmData) {
    const channels = 1;
    const bitsPerSample = 16;
    const byteRate = _sampleRate * channels * bitsPerSample ~/ 8;
    const blockAlign = channels * bitsPerSample ~/ 8;
    final dataLength = pcmData.length;
    final header = BytesBuilder(copy: false);

    void writeAscii(String value) {
      header.add(ascii.encode(value));
    }

    void writeUint16(int value) {
      final d = ByteData(2)..setUint16(0, value, Endian.little);
      header.add(d.buffer.asUint8List());
    }

    void writeUint32(int value) {
      final d = ByteData(4)..setUint32(0, value, Endian.little);
      header.add(d.buffer.asUint8List());
    }

    writeAscii('RIFF');
    writeUint32(36 + dataLength);
    writeAscii('WAVE');
    writeAscii('fmt ');
    writeUint32(16);
    writeUint16(1); // PCM
    writeUint16(channels);
    writeUint32(_sampleRate);
    writeUint32(byteRate);
    writeUint16(blockAlign);
    writeUint16(bitsPerSample);
    writeAscii('data');
    writeUint32(dataLength);
    header.add(pcmData);

    return header.toBytes();
  }
}
