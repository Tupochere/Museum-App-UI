import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiTtsService {
  static const String _defaultModel = 'gemini-2.5-flash-preview-tts';
  static const String _defaultVoice = 'Sulafat';
  static const int _sampleRate = 24000;
  static const int _channels = 1;
  static const int _bitsPerSample = 16;

  Future<Uint8List> synthesizeSpeech(String text, {String? stylePrompt}) async {
    final apiKey = dotenv.env['GEMINI_API_KEY']?.trim() ?? '';
    if (apiKey.isEmpty) {
      throw StateError('Missing GEMINI_API_KEY for Gemini TTS.');
    }

    final model = _resolveModel();
    final prompt = _buildSpeechPrompt(text, stylePrompt: stylePrompt);
    final client = HttpClient();

    try {
      final request = await client.postUrl(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/'
          '$model:generateContent',
        ),
      );
      request.headers.contentType = ContentType.json;
      request.headers.set('x-goog-api-key', apiKey);
      request.add(
        utf8.encode(
          jsonEncode({
            'model': model,
            'contents': [
              {
                'parts': [
                  {'text': prompt},
                ],
              },
            ],
            'generationConfig': {
              'responseModalities': ['AUDIO'],
              'speechConfig': {
                'voiceConfig': {
                  'prebuiltVoiceConfig': {'voiceName': _resolveVoice()},
                },
              },
            },
          }),
        ),
      );

      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Gemini TTS failed (${response.statusCode}): '
          '${_extractErrorMessage(body)}',
        );
      }

      return _extractWaveBytes(body);
    } catch (e, st) {
      debugPrint('GeminiTtsService.synthesizeSpeech ERROR: $e');
      debugPrintStack(stackTrace: st);
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  String _resolveModel() {
    final configured = dotenv.env['GEMINI_TTS_MODEL']?.trim();
    if (configured == null || configured.isEmpty) {
      return _defaultModel;
    }
    return configured.replaceFirst(RegExp(r'^models/'), '');
  }

  String _resolveVoice() {
    final configured = dotenv.env['GEMINI_TTS_VOICE']?.trim();
    if (configured == null || configured.isEmpty) {
      return _defaultVoice;
    }
    return configured;
  }

  String _buildSpeechPrompt(String text, {String? stylePrompt}) {
    final transcript = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final direction = stylePrompt?.trim().isNotEmpty == true
        ? stylePrompt!.trim()
        : 'Audio profile: a warm, smooth, natural museum guide with a '
              'grounded human tone. '
              'Scene: a calm cultural museum with intimate, welcoming '
              'energy. '
              'Director notes: speak conversationally with subtle pauses, '
              'gentle emphasis, and natural pacing. Avoid sounding robotic, '
              'over-enunciated, or theatrical.';
    return '$direction\n\nTranscript: $transcript';
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
    return body;
  }

  Uint8List _extractWaveBytes(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Gemini TTS returned an invalid JSON body.');
    }

    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw const FormatException('Gemini TTS returned no candidates.');
    }

    final candidate = candidates.first;
    if (candidate is! Map<String, dynamic>) {
      throw const FormatException('Gemini TTS candidate format was invalid.');
    }

    final content = candidate['content'];
    if (content is! Map<String, dynamic>) {
      throw const FormatException('Gemini TTS returned no content.');
    }

    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) {
      throw const FormatException('Gemini TTS returned no audio parts.');
    }

    for (final part in parts) {
      if (part is! Map<String, dynamic>) continue;
      final inlineData = part['inlineData'];
      if (inlineData is! Map<String, dynamic>) continue;
      final data = inlineData['data'];
      if (data is! String || data.isEmpty) continue;
      return _wrapPcmAsWav(base64Decode(data));
    }

    throw const FormatException('Gemini TTS returned no inline audio data.');
  }

  Uint8List _wrapPcmAsWav(Uint8List pcmData) {
    const byteRate = _sampleRate * _channels * _bitsPerSample ~/ 8;
    const blockAlign = _channels * _bitsPerSample ~/ 8;
    final dataLength = pcmData.length;
    final header = BytesBuilder(copy: false);

    void writeAscii(String value) {
      header.add(ascii.encode(value));
    }

    void writeUint16(int value) {
      final data = ByteData(2)..setUint16(0, value, Endian.little);
      header.add(data.buffer.asUint8List());
    }

    void writeUint32(int value) {
      final data = ByteData(4)..setUint32(0, value, Endian.little);
      header.add(data.buffer.asUint8List());
    }

    writeAscii('RIFF');
    writeUint32(36 + dataLength);
    writeAscii('WAVE');
    writeAscii('fmt ');
    writeUint32(16);
    writeUint16(1);
    writeUint16(_channels);
    writeUint32(_sampleRate);
    writeUint32(byteRate);
    writeUint16(blockAlign);
    writeUint16(_bitsPerSample);
    writeAscii('data');
    writeUint32(dataLength);
    header.add(pcmData);

    return header.toBytes();
  }
}
