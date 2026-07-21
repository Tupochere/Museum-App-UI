import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SpeechClip {
  final Uint8List wavBytes;
  final Duration duration;

  const SpeechClip({required this.wavBytes, required this.duration});
}

class OpenAiTtsService {
  static const String _defaultVoice = 'nova';
  static const String _model = 'tts-1-hd';
  static const int _maxRetries = 2;

  Future<SpeechClip> synthesizeSpeech(String text) async {
    final apiKey = dotenv.env['OPENAI_API_KEY']?.trim() ?? '';
    if (apiKey.isEmpty) {
      throw StateError('Missing OPENAI_API_KEY for OpenAI TTS.');
    }

    final voice = _resolveVoice();
    Object? lastError;
    StackTrace? lastStackTrace;

    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      final client = HttpClient();
      try {
        final request = await client.postUrl(
          Uri.parse('https://api.openai.com/v1/audio/speech'),
        );
        request.headers.contentType = ContentType.json;
        request.headers.set('Authorization', 'Bearer $apiKey');
        request.add(
          utf8.encode(
            jsonEncode({
              'model': _model,
              'input': text,
              'voice': voice,
              'response_format': 'wav',
            }),
          ),
        );

        final response = await request.close();

        if (response.statusCode == 429 ||
            (response.statusCode >= 500 && response.statusCode < 600)) {
          final body = await utf8.decoder.bind(response).join();
          lastError = HttpException(
            'OpenAI TTS rate limited (${response.statusCode}): '
            '${_extractErrorMessage(body)}',
          );
          lastStackTrace = StackTrace.current;
          if (attempt < _maxRetries) {
            final delay = _retryDelay(attempt);
            debugPrint(
              'OpenAiTtsService: rate limited, retrying in '
              '${delay.inSeconds}s (attempt ${attempt + 1}/$_maxRetries)',
            );
            await Future.delayed(delay);
            continue;
          }
          Error.throwWithStackTrace(lastError, lastStackTrace);
        }

        if (response.statusCode < 200 || response.statusCode >= 300) {
          final body = await utf8.decoder.bind(response).join();
          throw HttpException(
            'OpenAI TTS failed (${response.statusCode}): '
            '${_extractErrorMessage(body)}',
          );
        }

        // OpenAI returns complete WAV bytes directly.
        final wavBytes = await _collectBytes(response);
        final duration = _wavDuration(wavBytes);
        return SpeechClip(wavBytes: wavBytes, duration: duration);
      } catch (e, st) {
        lastError = e;
        lastStackTrace = st;

        if (attempt < _maxRetries && _isRetryable(e)) {
          final delay = _retryDelay(attempt);
          debugPrint(
            'OpenAiTtsService: retryable error, retrying in '
            '${delay.inSeconds}s (attempt ${attempt + 1}/$_maxRetries)',
          );
          await Future.delayed(delay);
          continue;
        }

        debugPrint('OpenAiTtsService.synthesizeSpeech ERROR: $e');
        debugPrintStack(stackTrace: st);
        break;
      } finally {
        client.close(force: true);
      }
    }

    if (lastError != null && lastStackTrace != null) {
      Error.throwWithStackTrace(lastError, lastStackTrace);
    }
    throw StateError('OpenAI TTS failed before any attempt completed.');
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _resolveVoice() {
    final configured = dotenv.env['OPENAI_TTS_VOICE']?.trim();
    if (configured == null || configured.isEmpty) return _defaultVoice;
    return configured;
  }

  static bool _isRetryable(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('429') ||
        msg.contains('rate limit') ||
        msg.contains('quota') ||
        msg.contains('server error') ||
        msg.contains('502') ||
        msg.contains('503');
  }

  static Duration _retryDelay(int attempt) {
    final baseMs = 2000 * pow(2, attempt).toInt();
    final jitterMs = Random().nextInt(800);
    return Duration(milliseconds: baseMs + jitterMs);
  }

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

  Future<Uint8List> _collectBytes(HttpClientResponse response) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      builder.add(chunk);
    }
    return builder.toBytes();
  }

  /// Parse duration from a standard WAV header.
  Duration _wavDuration(Uint8List wavBytes) {
    if (wavBytes.length < 44) return Duration.zero;
    final data = ByteData.sublistView(wavBytes);
    final byteRate = data.getUint32(28, Endian.little);
    if (byteRate == 0) return Duration.zero;

    // Walk chunks to find the 'data' chunk size.
    var offset = 12; // Skip RIFF header (12 bytes).
    while (offset + 8 <= wavBytes.length) {
      final chunkId = String.fromCharCodes(wavBytes.sublist(offset, offset + 4));
      final chunkSize = data.getUint32(offset + 4, Endian.little);
      if (chunkId == 'data') {
        final durationMicros =
            (chunkSize * Duration.microsecondsPerSecond) ~/ byteRate;
        return Duration(microseconds: durationMicros);
      }
      offset += 8 + chunkSize;
      // Chunks are word-aligned in RIFF.
      if (chunkSize.isOdd) offset++;
    }
    return Duration.zero;
  }
}
