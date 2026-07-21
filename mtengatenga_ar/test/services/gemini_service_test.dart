import 'package:flutter_test/flutter_test.dart';
import 'package:mtengatenga_ar/core/domain/entities/artifact.model.dart';
import 'package:mtengatenga_ar/services/gemini_service.dart';
import 'package:mtengatenga_ar/services/translation_service.dart';

void main() {
  group('GeminiService request shaping', () {
    late LanguageState languageState;
    late GeminiService service;
    late Artifact artifact;

    setUp(() {
      languageState = LanguageState();
      languageState.value = 'ny';
      service = GeminiService(languageState: languageState);
      artifact = Artifact(
        id: 'artifact-123',
        name: 'Kaligo Drum',
        description: 'A ceremonial drum.',
        isFeatured: true,
        updatedAt: DateTime(2024),
      );
    });

    test('text mode trims history to the latest 10 turns', () {
      final history = List<Map<String, String>>.generate(12, (index) {
        return {
          'role': index.isEven ? 'user' : 'model',
          'content': 'message $index',
        };
      });

      final request = service.buildRequest(
        artifact: artifact,
        userMessage: 'Tell me about this artifact',
        history: history,
        mode: AiGuideMode.text,
      );

      expect(request.mode, AiGuideMode.text);
      expect(request.history.length, 10);
      expect(request.history.first.content, 'message 2');
      expect(request.history.last.content, 'message 11');
    });

    test('voice mode trims history to the latest 6 turns', () {
      final history = List<Map<String, String>>.generate(8, (index) {
        return {
          'role': index.isEven ? 'user' : 'model',
          'content': 'turn $index',
        };
      });

      final request = service.buildRequest(
        artifact: artifact,
        userMessage: 'Who used it?',
        history: history,
        mode: AiGuideMode.voice,
      );

      expect(request.mode, AiGuideMode.voice);
      expect(request.history.length, 6);
      expect(request.history.first.content, 'turn 2');
      expect(request.history.last.content, 'turn 7');
    });

    test('tour mode clears history entirely', () {
      final request = service.buildRequest(
        artifact: artifact,
        userMessage: 'Give me a narration',
        history: const [
          {'role': 'user', 'content': 'hello'},
          {'role': 'model', 'content': 'hi'},
        ],
        mode: AiGuideMode.tour,
      );

      expect(request.mode, AiGuideMode.tour);
      expect(request.history, isEmpty);
    });

    test('general museum requests omit artifactId and keep language', () {
      final request = service.buildRequest(
        artifact: GeminiService.museumGuideArtifact,
        userMessage: 'What can I explore here?',
      );

      expect(request.artifactId, isNull);
      expect(request.language, 'ny');
      expect(request.query, 'What can I explore here?');
    });

    test('toJson matches the structured cloud function contract', () {
      final request = service.buildRequest(
        artifact: artifact,
        userMessage: 'Explain this for a visitor',
        history: const [
          {'role': 'user', 'content': 'Tell me about it'},
          {'role': 'model', 'content': 'It is a ceremonial drum.'},
        ],
      );

      expect(request.toJson(), {
        'query': 'Explain this for a visitor',
        'mode': 'text',
        'artifactId': 'artifact-123',
        'history': [
          {'role': 'user', 'content': 'Tell me about it'},
          {'role': 'model', 'content': 'It is a ceremonial drum.'},
        ],
        'language': 'ny',
      });
    });
  });
}
