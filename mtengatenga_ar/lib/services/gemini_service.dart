import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_it/get_it.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../core/domain/entities/artifact.model.dart';
import 'translation_service.dart';

enum AiGuideMode { text, voice, tour }

extension on AiGuideMode {
  String get wireValue => switch (this) {
    AiGuideMode.text => 'text',
    AiGuideMode.voice => 'voice',
    AiGuideMode.tour => 'tour',
  };

  int get historyLimit => switch (this) {
    AiGuideMode.text => 10,
    AiGuideMode.voice => 6,
    AiGuideMode.tour => 0,
  };
}

class AiGuideMessage {
  final String role;
  final String content;

  const AiGuideMessage({required this.role, required this.content});

  Map<String, String> toJson() => {'role': role, 'content': content};
}

class AiGuideRequest {
  final String query;
  final AiGuideMode mode;
  final String? artifactId;
  final List<AiGuideMessage> history;
  final String language;

  const AiGuideRequest({
    required this.query,
    required this.mode,
    required this.history,
    required this.language,
    this.artifactId,
  });

  Map<String, dynamic> toJson() => {
    'query': query,
    'mode': mode.wireValue,
    'artifactId': artifactId,
    'history': history.map((message) => message.toJson()).toList(),
    'language': language,
  };
}

class GeminiService {
  static const String _defaultModel = 'gemini-2.5-flash';
  static const int _maxRetries = 3;

  GeminiService({LanguageState? languageState})
    : _languageState = languageState ?? _resolveLanguageState();

  final LanguageState _languageState;

  static LanguageState _resolveLanguageState() {
    final getIt = GetIt.instance;
    if (getIt.isRegistered<LanguageState>()) {
      return getIt<LanguageState>();
    }
    return LanguageState();
  }

  String get _cloudFunctionUrl =>
      dotenv.env['CLOUD_FUNCTION_URL']?.trim() ?? '';

  bool get _useCloudFunction => _cloudFunctionUrl.isNotEmpty;

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

    return configuredModel.replaceFirst(RegExp(r'^models/'), '');
  }

  static bool _isQuotaError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('quota') ||
        message.contains('rate limit') ||
        message.contains('resource has been exhausted') ||
        message.contains('429');
  }

  static Duration _retryDelay(Object error, int attempt) {
    final match = RegExp(
      r'retry\s+in\s+([\d.]+)s',
      caseSensitive: false,
    ).firstMatch(error.toString());
    if (match != null) {
      final seconds = double.tryParse(match.group(1)!);
      if (seconds != null && seconds > 0 && seconds < 120) {
        final jitterMs = Random().nextInt(500);
        return Duration(milliseconds: (seconds * 1000).ceil() + jitterMs);
      }
    }

    final baseMs = 3000 * pow(2, attempt).toInt();
    final jitterMs = Random().nextInt(1000);
    return Duration(milliseconds: baseMs + jitterMs);
  }

  @visibleForTesting
  static List<AiGuideMessage> sanitizeHistory(
    List<Map<String, String>> history,
  ) {
    return history
        .map((entry) {
          final role = entry['role'];
          final content = entry['content']?.trim() ?? '';
          if ((role != 'user' && role != 'model') || content.isEmpty) {
            return null;
          }
          return AiGuideMessage(role: role!, content: content);
        })
        .whereType<AiGuideMessage>()
        .toList(growable: false);
  }

  @visibleForTesting
  static List<AiGuideMessage> trimHistoryForMode(
    AiGuideMode mode,
    List<AiGuideMessage> history,
  ) {
    final limit = mode.historyLimit;
    if (limit <= 0) return const [];
    if (history.length <= limit) return history;
    return history.sublist(history.length - limit);
  }

  @visibleForTesting
  AiGuideRequest buildRequest({
    required Artifact artifact,
    required String userMessage,
    List<Map<String, String>> history = const [],
    AiGuideMode mode = AiGuideMode.text,
  }) {
    final query = userMessage.trim();
    final artifactId = artifact.id == museumGuideArtifact.id
        ? null
        : artifact.id;
    final sanitizedHistory = sanitizeHistory(history);
    final trimmedHistory = trimHistoryForMode(mode, sanitizedHistory);

    return AiGuideRequest(
      query: query,
      mode: mode,
      artifactId: artifactId,
      history: trimmedHistory,
      language: _languageState.value == 'ny' ? 'ny' : 'en',
    );
  }

  Future<String> chatAboutArtifact(
    Artifact artifact,
    String userMessage,
    List<Map<String, String>> history,
  ) async {
    final request = buildRequest(
      artifact: artifact,
      userMessage: userMessage,
      history: history,
      mode: AiGuideMode.text,
    );
    return _queryGuide(request, artifact);
  }

  Future<String> generateTourNarration(
    Artifact artifact,
    String narrationContext,
  ) async {
    final request = buildRequest(
      artifact: artifact,
      userMessage:
          'Provide a brief spoken narration for a visitor standing in front of this artifact. Context: $narrationContext',
      mode: AiGuideMode.tour,
    );
    return _queryGuide(request, artifact);
  }

  Future<String> voiceQuery(Artifact? artifact, String userMessage) async {
    final target = artifact ?? museumGuideArtifact;
    final request = buildRequest(
      artifact: target,
      userMessage: userMessage,
      mode: AiGuideMode.voice,
    );
    return _queryGuide(request, target);
  }

  Stream<String> voiceQueryStream(
    Artifact? artifact,
    String userMessage, {
    List<Map<String, String>> history = const [],
  }) async* {
    final target = artifact ?? museumGuideArtifact;
    final request = buildRequest(
      artifact: target,
      userMessage: userMessage,
      history: history,
      mode: AiGuideMode.voice,
    );

    if (_useCloudFunction) {
      yield* _streamViaCloudFunction(request);
      return;
    }

    final prompt = _buildFallbackPrompt(target, request);
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
        return;
      } catch (e, st) {
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

  Future<String> _queryGuide(
    AiGuideRequest request,
    Artifact fallbackArtifact,
  ) async {
    if (_useCloudFunction) {
      return _chatViaCloudFunction(request, fallbackArtifact);
    }

    final prompt = _buildFallbackPrompt(fallbackArtifact, request);
    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final model = _buildModel();
        final response = await model.generateContent([Content.text(prompt)]);
        final text = response.text;
        if (text == null || text.trim().isEmpty) {
          debugPrint('GeminiService: empty response');
          return _fallback(fallbackArtifact);
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
        return _fallback(fallbackArtifact);
      }
    }

    return _fallback(fallbackArtifact);
  }

  String _buildFallbackPrompt(Artifact artifact, AiGuideRequest request) {
    final buffer = StringBuffer()
      ..writeln(
        'You are the AI guide for Mtengatenga Cultural Museum in Malawi.',
      )
      ..writeln(
        'Be grounded, respectful, and concise. Do not invent exhibit facts.',
      )
      ..writeln(
        'If details are missing, say what is known and keep uncertainty brief.',
      )
      ..writeln('Answer in English only. Translation happens after generation.')
      ..writeln();

    switch (request.mode) {
      case AiGuideMode.text:
        buffer.writeln(
          'TEXT MODE: Keep the response conversational and around 3 to 5 short sentences.',
        );
      case AiGuideMode.voice:
        buffer.writeln(
          'VOICE MODE: Keep the response natural and easy to follow out loud in 2 to 3 short sentences.',
        );
        if (request.language == 'en') {
          buffer.writeln(
            'If a Malawian term is hard for English TTS, you may spell it phonetically without showing the original spelling beside it.',
          );
        }
      case AiGuideMode.tour:
        buffer.writeln(
          'TOUR MODE: Give 2 to 3 vivid narration sentences as if you are beside the artifact with the visitor.',
        );
    }

    if (artifact.id != museumGuideArtifact.id) {
      buffer
        ..writeln()
        ..writeln('SELECTED ARTIFACT:')
        ..writeln('Name: ${artifact.name}');
      if (artifact.subtitle?.isNotEmpty == true) {
        buffer.writeln('Subtitle: ${artifact.subtitle}');
      }
      if (artifact.category?.isNotEmpty == true) {
        buffer.writeln('Category: ${artifact.category}');
      }
      if (artifact.period?.isNotEmpty == true) {
        buffer.writeln('Period: ${artifact.period}');
      }
      buffer.writeln('Description: ${artifact.description}');
      if (artifact.culturalSignificance?.isNotEmpty == true) {
        buffer.writeln(
          'Cultural significance: ${artifact.culturalSignificance}',
        );
      }
      if (artifact.additionalNotes?.isNotEmpty == true) {
        buffer.writeln('Additional notes: ${artifact.additionalNotes}');
      }
      if (artifact.aiContext?.isNotEmpty == true) {
        buffer.writeln('Museum guide notes: ${artifact.aiContext}');
      }
      if (artifact.location?.isNotEmpty == true) {
        buffer.writeln('Location: ${artifact.location}');
      }
      if (artifact.timeline?.isNotEmpty == true) {
        final timelineText = artifact.timeline!
            .map((entry) => '${entry.year}: ${entry.event}')
            .join('; ');
        buffer.writeln('Timeline: $timelineText');
      }
    } else {
      buffer
        ..writeln()
        ..writeln('MUSEUM OVERVIEW:')
        ..writeln(
          'Mtengatenga Cultural Museum helps visitors explore Malawian cultural heritage, especially Chewa traditions, artifacts, performances, and everyday life.',
        );
    }

    if (request.history.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('RECENT CONVERSATION:');
      for (final message in request.history) {
        final role = message.role == 'user' ? 'Visitor' : 'Guide';
        buffer.writeln('$role: ${message.content}');
      }
    }

    buffer
      ..writeln()
      ..writeln('Visitor question: ${request.query}')
      ..writeln('Guide:');

    return buffer.toString();
  }

  String _fallback(Artifact artifact) {
    if (artifact.aiContext?.isNotEmpty == true) return artifact.aiContext!;
    if (artifact.id != museumGuideArtifact.id &&
        artifact.description.isNotEmpty) {
      return artifact.description;
    }
    return 'Welcome to Mtengatenga Cultural Museum! I\'m here to help you explore Malawian heritage. What would you like to know?';
  }

  Future<String> _chatViaCloudFunction(
    AiGuideRequest request,
    Artifact artifact,
  ) async {
    final client = HttpClient();
    try {
      final httpRequest = await client.postUrl(
        Uri.parse('$_cloudFunctionUrl/ai-chat'),
      );
      httpRequest.headers.contentType = ContentType.json;
      httpRequest.add(utf8.encode(jsonEncode(request.toJson())));

      final response = await httpRequest.close();
      final body = await utf8.decoder.bind(response).join();

      if (response.statusCode != 200) {
        debugPrint(
          'Cloud function /ai-chat failed (${response.statusCode}): $body',
        );
        return _fallback(artifact);
      }

      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final text = decoded['text'] as String?;
      if (text == null || text.trim().isEmpty) return _fallback(artifact);
      return text.trim();
    } catch (e, st) {
      debugPrint('Cloud function /ai-chat error: $e');
      debugPrintStack(stackTrace: st);
      return _fallback(artifact);
    } finally {
      client.close(force: true);
    }
  }

  Stream<String> _streamViaCloudFunction(AiGuideRequest request) async* {
    final client = HttpClient();
    try {
      final httpRequest = await client.postUrl(
        Uri.parse('$_cloudFunctionUrl/ai-chat-stream'),
      );
      httpRequest.headers.contentType = ContentType.json;
      httpRequest.add(utf8.encode(jsonEncode(request.toJson())));

      final response = await httpRequest.close();

      if (response.statusCode != 200) {
        final body = await utf8.decoder.bind(response).join();
        throw HttpException(
          'Cloud function /ai-chat-stream failed '
          '(${response.statusCode}): $body',
        );
      }

      var buffer = '';
      await for (final chunk in utf8.decoder.bind(response)) {
        buffer += chunk;
        while (buffer.contains('\n\n')) {
          final idx = buffer.indexOf('\n\n');
          final event = buffer.substring(0, idx).trim();
          buffer = buffer.substring(idx + 2);

          if (!event.startsWith('data: ')) continue;
          final payload = event.substring(6);
          if (payload == '[DONE]') return;

          try {
            final decoded = jsonDecode(payload) as Map<String, dynamic>;
            final text = decoded['text'] as String?;
            if (text != null && text.isNotEmpty) yield text;
          } catch (_) {
            // Skip malformed SSE events.
          }
        }
      }
    } finally {
      client.close(force: true);
    }
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
