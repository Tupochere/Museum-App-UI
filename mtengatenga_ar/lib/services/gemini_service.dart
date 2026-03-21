import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../core/domain/entities/artifact.model.dart';

class GeminiService {
  static const String _defaultModel = 'gemini-2.5-flash';
  static const int _maxRetries = 3;

  GeminiService();

  GenerativeModel _buildModel() {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    final modelName = _resolveModelName();
    return GenerativeModel(model: modelName, apiKey: apiKey);
  }

  String _resolveModelName() {
    final configuredModel = dotenv.env['GEMINI_MODEL']?.trim();
    if (configuredModel == null || configuredModel.isEmpty) {
      return _defaultModel;
    }

    // Accept either "gemini-2.5-flash" or "models/gemini-2.5-flash".
    return configuredModel.replaceFirst(RegExp(r'^models/'), '');
  }

  // ── Quota retry helpers ──────────────────────────────────────────────────

  static bool _isQuotaError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('quota') ||
        message.contains('rate limit') ||
        message.contains('resource has been exhausted') ||
        message.contains('429');
  }

  static Duration _retryDelay(Object error, int attempt) {
    // Try to parse "retry in Xs" from the error message.
    final match =
        RegExp(r'retry\s+in\s+([\d.]+)s', caseSensitive: false)
            .firstMatch(error.toString());
    if (match != null) {
      final seconds = double.tryParse(match.group(1)!);
      if (seconds != null && seconds > 0 && seconds < 120) {
        // Add a small jitter to avoid thundering herd.
        final jitterMs = Random().nextInt(500);
        return Duration(
          milliseconds: (seconds * 1000).ceil() + jitterMs,
        );
      }
    }
    // Exponential backoff: 3s, 6s, 12s …
    final baseMs = 3000 * pow(2, attempt).toInt();
    final jitterMs = Random().nextInt(1000);
    return Duration(milliseconds: baseMs + jitterMs);
  }

  // ── Prompt ───────────────────────────────────────────────────────────────

  String _buildPrompt(
    Artifact artifact,
    String userMessage,
    List<Map<String, String>> history, {
    bool voiceMode = false,
  }) {
    final contextBlock = StringBuffer();
    contextBlock.writeln(
      'You are a knowledgeable, warm and engaging museum guide at Mtengatenga Cultural Museum in Malawi.'
      ' You specialize in Malawian cultural heritage, Chewa traditions, and the artifacts in this museum.'
      ' Keep responses conversational and under ${voiceMode ? 3 : 4} sentences unless asked for detail.'
      ' Only answer questions about the artifact below or directly related Malawian cultural heritage.'
      ' If asked about something unrelated, politely redirect to the artifact.'
      ' Use respectful language when discussing cultural and spiritual practices.',
    );
    if (voiceMode) {
      contextBlock.writeln(
        ' This response will be spoken aloud, so keep it natural, concise, and easy to follow.'
        ' Avoid lists unless the visitor explicitly asks for them.'
        ' Lead with the most useful point quickly.',
      );
    }
    contextBlock.writeln();
    if (artifact.id != 'general') {
      contextBlock.writeln('ARTIFACT CONTEXT:');
      contextBlock.writeln('Name: ${artifact.name}');
      if (artifact.category != null) {
        contextBlock.writeln('Category: ${artifact.category}');
      }
      if (artifact.period != null) {
        contextBlock.writeln('Period: ${artifact.period}');
      }
      contextBlock.writeln('Description: ${artifact.description}');
      if (artifact.aiContext?.isNotEmpty == true) {
        contextBlock.writeln('Cultural Context: ${artifact.aiContext}');
      }
      contextBlock.writeln();
    }

    if (history.isNotEmpty) {
      contextBlock.writeln('CONVERSATION SO FAR:');
      for (final msg in history) {
        final role = msg['role'] == 'user' ? 'Visitor' : 'Guide';
        contextBlock.writeln('$role: ${msg['content']}');
      }
      contextBlock.writeln();
    }

    contextBlock.writeln('Visitor: $userMessage');
    contextBlock.writeln('Guide:');
    return contextBlock.toString();
  }

  // ── Chat (text mode) ────────────────────────────────────────────────────

  Future<String> chatAboutArtifact(
    Artifact artifact,
    String userMessage,
    List<Map<String, String>> history,
  ) async {
    final prompt = _buildPrompt(artifact, userMessage, history);

    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final model = _buildModel();
        final response =
            await model.generateContent([Content.text(prompt)]);
        final text = response.text;
        if (text == null || text.trim().isEmpty) {
          debugPrint('GeminiService: empty response');
          return _fallback(artifact);
        }
        return text.trim();
      } catch (e, st) {
        if (attempt < _maxRetries && _isQuotaError(e)) {
          final delay = _retryDelay(e, attempt);
          debugPrint(
            'GeminiService.chatAboutArtifact: quota exceeded, '
            'retrying in ${delay.inSeconds}s '
            '(attempt ${attempt + 1}/$_maxRetries)',
          );
          await Future.delayed(delay);
          continue;
        }
        debugPrint(
          'GeminiService.chatAboutArtifact ERROR '
          '(model: ${_resolveModelName()}): $e',
        );
        debugPrintStack(stackTrace: st);
        return _fallback(artifact);
      }
    }
    return _fallback(artifact);
  }

  // ── Tour narration ──────────────────────────────────────────────────────

  Future<String> generateTourNarration(
    Artifact artifact,
    String narrationContext,
  ) async {
    return chatAboutArtifact(
      artifact,
      'Provide a brief spoken narration for a visitor standing in front of this artifact. Context: $narrationContext',
      const [],
    );
  }

  // ── Voice query (single shot) ───────────────────────────────────────────

  Future<String> voiceQuery(Artifact? artifact, String userMessage) async {
    final target = artifact ?? museumGuideArtifact;
    return chatAboutArtifact(target, userMessage, const []);
  }

  // ── Voice query (streaming with retry) ──────────────────────────────────

  Stream<String> voiceQueryStream(
    Artifact? artifact,
    String userMessage, {
    List<Map<String, String>> history = const [],
  }) async* {
    final target = artifact ?? museumGuideArtifact;
    final prompt = _buildPrompt(
      target,
      userMessage,
      history,
      voiceMode: true,
    );

    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      var hasYielded = false;
      try {
        final model = _buildModel();
        await for (final response in model.generateContentStream([
          Content.text(prompt),
        ])) {
          final text = response.text;
          if (text == null || text.trim().isEmpty) continue;
          hasYielded = true;
          yield text;
        }
        return; // Stream completed successfully.
      } catch (e, st) {
        // Only retry if we haven't yielded any data yet (the consumer
        // hasn't received partial text) and the error is quota-related.
        if (!hasYielded && attempt < _maxRetries && _isQuotaError(e)) {
          final delay = _retryDelay(e, attempt);
          debugPrint(
            'GeminiService.voiceQueryStream: quota exceeded, '
            'retrying in ${delay.inSeconds}s '
            '(attempt ${attempt + 1}/$_maxRetries)',
          );
          await Future.delayed(delay);
          continue;
        }
        debugPrint(
          'GeminiService.voiceQueryStream ERROR '
          '(model: ${_resolveModelName()}): $e',
        );
        debugPrintStack(stackTrace: st);
        rethrow;
      }
    }
  }

  // ── Fallback ────────────────────────────────────────────────────────────

  String _fallback(Artifact artifact) {
    if (artifact.aiContext?.isNotEmpty == true) return artifact.aiContext!;
    if (artifact.id != 'general' && artifact.description.isNotEmpty) {
      return artifact.description;
    }
    return 'Welcome to Mtengatenga Cultural Museum! I\'m here to help you explore Malawian heritage. What would you like to know?';
  }

  static final museumGuideArtifact = Artifact(
    id: 'general',
    name: 'Mtengatenga Cultural Museum',
    description:
        'A cultural museum dedicated to the heritage of Malawi, featuring artifacts from the Chewa, Ngoni, and other peoples of the region.',
    isFeatured: false,
    updatedAt: DateTime(2024),
  );
}
