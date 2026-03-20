import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../core/domain/entities/artifact.model.dart';

class GeminiService {
  static const String _defaultModel = 'gemini-2.5-flash';

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

  String _buildPrompt(Artifact artifact, String userMessage, List<Map<String, String>> history) {
    final contextBlock = StringBuffer();
    contextBlock.writeln(
      'You are a knowledgeable, warm and engaging museum guide at Mtengatenga Cultural Museum in Malawi.'
      ' You specialize in Malawian cultural heritage, Chewa traditions, and the artifacts in this museum.'
      ' Keep responses conversational and under 4 sentences unless asked for detail.'
      ' Only answer questions about the artifact below or directly related Malawian cultural heritage.'
      ' If asked about something unrelated, politely redirect to the artifact.'
      ' Use respectful language when discussing cultural and spiritual practices.',
    );
    contextBlock.writeln();
    if (artifact.id != 'general') {
      contextBlock.writeln('ARTIFACT CONTEXT:');
      contextBlock.writeln('Name: ${artifact.name}');
      if (artifact.category != null) contextBlock.writeln('Category: ${artifact.category}');
      if (artifact.period != null) contextBlock.writeln('Period: ${artifact.period}');
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

  Future<String> chatAboutArtifact(
    Artifact artifact,
    String userMessage,
    List<Map<String, String>> history,
  ) async {
    try {
      final model = _buildModel();
      final prompt = _buildPrompt(artifact, userMessage, history);
      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text;
      if (text == null || text.trim().isEmpty) {
        debugPrint('GeminiService: empty response');
        return _fallback(artifact);
      }
      return text.trim();
    } catch (e, st) {
      debugPrint(
        'GeminiService.chatAboutArtifact ERROR '
        '(model: ${_resolveModelName()}): $e',
      );
      debugPrintStack(stackTrace: st);
      return _fallback(artifact);
    }
  }

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

  Future<String> voiceQuery(Artifact? artifact, String userMessage) async {
    final target = artifact ?? museumGuideArtifact;
    return chatAboutArtifact(target, userMessage, const []);
  }

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
    description: 'A cultural museum dedicated to the heritage of Malawi, featuring artifacts from the Chewa, Ngoni, and other peoples of the region.',
    isFeatured: false,
    updatedAt: DateTime(2024),
  );
}
