import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/domain/repositories/artifact_repository.dart';

class SearchResult {
  final String id;
  final String name;
  final String? subtitle;
  final String? category;
  final String? period;
  final String? description;
  final String? displayImageUrl;
  final String? location;
  final double similarity;

  const SearchResult({
    required this.id,
    required this.name,
    this.subtitle,
    this.category,
    this.period,
    this.description,
    this.displayImageUrl,
    this.location,
    required this.similarity,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    final name = json['name']?.toString();
    if (id == null || id.isEmpty || name == null || name.isEmpty) {
      throw const FormatException('Invalid search row: missing id/name');
    }

    return SearchResult(
      id: id,
      name: name,
      subtitle: json['subtitle']?.toString(),
      category: json['category']?.toString(),
      period: json['period']?.toString(),
      description: json['description']?.toString(),
      displayImageUrl: json['display_image_url']?.toString(),
      location: json['location']?.toString(),
      similarity: ((json['similarity'] as num?) ?? 1.0).toDouble(),
    );
  }
}

class SearchService {
  String get _cloudFunctionUrl =>
      dotenv.env['CLOUD_FUNCTION_URL']?.trim() ?? '';

  /// Semantic search: generate query embedding via Cloud Function,
  /// then call Supabase RPC for cosine similarity match.
  Future<List<SearchResult>> search(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return [];

    try {
      final embedding = await _generateEmbedding(trimmedQuery);
      if (embedding != null) {
        final semanticResults = await _semanticSearch(
          query: trimmedQuery,
          embedding: embedding,
        );
        if (semanticResults.isNotEmpty) {
          return semanticResults;
        }

        debugPrint(
          'SearchService: semantic search returned no matches for "$trimmedQuery"; using text fallback.',
        );
      } else {
        debugPrint(
          'SearchService: embedding unavailable for "$trimmedQuery"; using text fallback.',
        );
      }
    } catch (e, st) {
      debugPrint('SearchService.search error for "$trimmedQuery": $e');
      debugPrintStack(stackTrace: st);
    }

    final serverResults = await _serverTextSearch(trimmedQuery);
    if (serverResults.isNotEmpty) {
      return serverResults;
    }

    return _localFallbackSearch(trimmedQuery);
  }

  Future<List<SearchResult>> _semanticSearch({
    required String query,
    required List<double> embedding,
  }) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'match_artifacts',
        params: {
          'query_embedding': embedding.toString(),
          'match_threshold': 0.45,
          'match_count': 10,
        },
      );

      final rows = response as List<dynamic>;
      return rows
          .map(
            (r) => SearchResult.fromJson(Map<String, dynamic>.from(r as Map)),
          )
          .toList(growable: false);
    } catch (e, st) {
      debugPrint('SearchService.semantic search failed for "$query": $e');
      debugPrintStack(stackTrace: st);
      return const [];
    }
  }

  /// Generate embedding vector via Cloud Function.
  Future<List<double>?> _generateEmbedding(String text) async {
    final url = _cloudFunctionUrl;
    if (url.isEmpty) return null;

    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse('$url/embed-query'));
      request.headers.contentType = ContentType.json;
      request.add(utf8.encode(jsonEncode({'text': text})));

      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();

      if (response.statusCode != 200) {
        debugPrint('Embedding failed (${response.statusCode}): $body');
        return null;
      }

      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final values = decoded['embedding'] as List<dynamic>;
      return values.map((v) => (v as num).toDouble()).toList();
    } catch (e, st) {
      debugPrint('Embedding error for "$text": $e');
      debugPrintStack(stackTrace: st);
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// Network fallback: query base artifact fields directly, avoiding Brick
  /// relation hydration when the semantic RPC or schema cache is broken.
  Future<List<SearchResult>> _serverTextSearch(String query) async {
    try {
      final response = await Supabase.instance.client
          .from('artifacts')
          .select(
            'id,name,subtitle,category,period,description,display_image_url,location,cultural_significance,updated_at',
          )
          .order('updated_at', ascending: false);

      final rows = (response as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(growable: false);

      final results = rows
          .map((row) => _buildTextMatchResult(row, query))
          .whereType<SearchResult>()
          .toList(growable: false);

      debugPrint(
        'SearchService: direct text fallback returned ${results.length} result(s) for "$query".',
      );

      return results.take(10).toList(growable: false);
    } catch (e, st) {
      debugPrint('SearchService.serverTextSearch error for "$query": $e');
      debugPrintStack(stackTrace: st);
      return const [];
    }
  }

  SearchResult? _buildTextMatchResult(Map<String, dynamic> row, String query) {
    final id = row['id']?.toString();
    final name = row['name']?.toString();
    if (id == null || id.isEmpty || name == null || name.isEmpty) {
      return null;
    }

    final normalizedQuery = query.toLowerCase();
    final textFields = <String>[
      name,
      row['subtitle']?.toString() ?? '',
      row['category']?.toString() ?? '',
      row['period']?.toString() ?? '',
      row['description']?.toString() ?? '',
      row['cultural_significance']?.toString() ?? '',
      row['location']?.toString() ?? '',
    ];

    final searchableText = textFields
        .where((value) => value.trim().isNotEmpty)
        .join(' ')
        .toLowerCase();

    if (!searchableText.contains(normalizedQuery)) {
      return null;
    }

    final tokens = normalizedQuery
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    final matchedTokenCount = tokens
        .where((token) => searchableText.contains(token))
        .length;
    final tokenScore = tokens.isEmpty
        ? 0.0
        : matchedTokenCount / math.max(tokens.length, 1);

    final nameLower = name.toLowerCase();
    double similarity = 0.70 + (tokenScore * 0.20);
    if (nameLower == normalizedQuery) {
      similarity = 0.99;
    } else if (nameLower.startsWith(normalizedQuery)) {
      similarity = 0.95;
    } else if (nameLower.contains(normalizedQuery)) {
      similarity = 0.90;
    } else if ((row['category']?.toString().toLowerCase() ?? '').contains(
      normalizedQuery,
    )) {
      similarity = 0.84;
    }

    return SearchResult(
      id: id,
      name: name,
      subtitle: row['subtitle']?.toString(),
      category: row['category']?.toString(),
      period: row['period']?.toString(),
      description: row['description']?.toString(),
      displayImageUrl: row['display_image_url']?.toString(),
      location: row['location']?.toString(),
      similarity: similarity.clamp(0.0, 0.99).toDouble(),
    );
  }

  /// Last fallback: simple substring match on locally cached artifacts.
  Future<List<SearchResult>> _localFallbackSearch(String query) async {
    try {
      final repo = GetIt.instance<IArtifactRepository>();
      final allArtifacts = await repo.getAllArtifacts();
      final q = query.toLowerCase();

      final matches = allArtifacts
          .where((a) {
            final searchText = [
              a.name,
              a.subtitle,
              a.category,
              a.period,
              a.description,
              a.culturalSignificance,
            ].where((s) => s != null).join(' ').toLowerCase();
            return searchText.contains(q);
          })
          .toList(growable: false);

      return matches
          .map(
            (a) => SearchResult(
              id: a.id,
              name: a.name,
              subtitle: a.subtitle,
              category: a.category,
              period: a.period,
              description: a.description,
              displayImageUrl: a.displayImageUrl,
              location: a.location,
              similarity: 1.0,
            ),
          )
          .toList(growable: false);
    } catch (e, st) {
      debugPrint('SearchService.localFallbackSearch error for "$query": $e');
      debugPrintStack(stackTrace: st);
      return [];
    }
  }
}
