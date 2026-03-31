import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

class VisionService {
  String get _cloudFunctionUrl =>
      dotenv.env['CLOUD_FUNCTION_URL']?.trim() ?? '';

  /// Compress and resize image bytes to JPEG, max 800px on longest side.
  /// Runs in an isolate via compute() to avoid UI jank.
  static Future<String> compressAndEncode(Uint8List rawBytes) {
    return compute(_compressIsolate, rawBytes);
  }

  static String _compressIsolate(Uint8List rawBytes) {
    var decoded = img.decodeImage(rawBytes);
    if (decoded == null) throw Exception('Failed to decode image');

    const maxDim = 800;
    if (decoded.width > maxDim || decoded.height > maxDim) {
      if (decoded.width >= decoded.height) {
        decoded = img.copyResize(decoded, width: maxDim);
      } else {
        decoded = img.copyResize(decoded, height: maxDim);
      }
    }

    final jpeg = img.encodeJpg(decoded, quality: 80);
    return base64Encode(jpeg);
  }

  /// Send image + prompt to Cloud Function, get AI text response.
  Future<String> analyzeImage({
    required String imageBase64,
    required String prompt,
  }) async {
    final url = _cloudFunctionUrl;
    if (url.isEmpty) {
      return 'Cloud Function URL not configured. Set CLOUD_FUNCTION_URL in .env';
    }

    try {
      final response = await http.post(
        Uri.parse('$url/ai-chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'prompt': prompt,
          'image': {
            'mimeType': 'image/jpeg',
            'data': imageBase64,
          },
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('Vision /ai-chat failed (${response.statusCode}): ${response.body}');
        return 'Sorry, I could not analyze this image right now.';
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final text = decoded['text'] as String?;
      return text?.trim() ?? 'No description available.';
    } catch (e, st) {
      debugPrint('VisionService error: $e');
      debugPrintStack(stackTrace: st);
      return 'Sorry, something went wrong. Please try again.';
    }
  }

  /// Build the vision prompt.
  /// Generic for now — swap the system block for museum-specific later.
  String buildVisionPrompt({
    required bool isFollowUp,
    String? userQuestion,
    List<Map<String, String>> history = const [],
  }) {
    final sb = StringBuffer();

    // TODO(museum-mode): Replace with museum-specific system prompt when ready
    sb.writeln(
      'You are a knowledgeable and friendly visual assistant at the '
      'Mtengatenga Cultural Museum in Malawi. '
      'The user is pointing their phone camera at an object and wants to learn about it. '
      'Describe what you see in detail: identify the object, explain what it is, '
      'its purpose, interesting facts, and any cultural or historical significance. '
      'Keep your response conversational and under 4 sentences unless asked for more detail.',
    );

    sb.writeln();

    if (history.isNotEmpty) {
      sb.writeln('CONVERSATION SO FAR:');
      for (final msg in history) {
        final role = msg['role'] == 'user' ? 'User' : 'Assistant';
        sb.writeln('$role: ${msg["content"]}');
      }
      sb.writeln();
    }

    if (isFollowUp && userQuestion != null) {
      sb.writeln('User follow-up question: $userQuestion');
    } else {
      sb.writeln('Please describe this object.');
    }

    return sb.toString();
  }
}
