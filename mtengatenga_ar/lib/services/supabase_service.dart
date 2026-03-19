import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/artifact.dart';

class SupabaseService {
  SupabaseService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<Artifact?> getArtifact(String qrCode) async {
    final candidates = _extractCandidates(qrCode);
    if (candidates.isEmpty) return null;

    for (final candidate in candidates) {
      try {
        final row = await _client
            .from('artifacts')
            .select()
            .eq('qr_code', candidate)
            .single();

        final map = Map<String, dynamic>.from(row as Map);
        return Artifact.fromJson(map);
      } on PostgrestException catch (error, stackTrace) {
        // PGRST116: no rows returned from single() query.
        if (error.code == 'PGRST116') {
          continue;
        }

        debugPrint('Supabase getArtifact PostgrestException: ${error.message}');
        debugPrintStack(stackTrace: stackTrace);
      } catch (error, stackTrace) {
        debugPrint('Supabase getArtifact failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    return null;
  }

  List<String> _extractCandidates(String qrCode) {
    final normalized = qrCode.trim();
    if (normalized.isEmpty) return const [];

    final values = <String>{normalized};
    final uri = Uri.tryParse(normalized);
    if (uri != null) {
      final queryKeys = [
        'qr',
        'code',
        'qrcode',
        'artifact',
        'artifact_id',
        'id',
      ];
      for (final key in queryKeys) {
        final queryValue = uri.queryParameters[key];
        if (queryValue != null && queryValue.trim().isNotEmpty) {
          values.add(queryValue.trim());
        }
      }

      if (uri.pathSegments.isNotEmpty) {
        final lastSegment = uri.pathSegments.last.trim();
        if (lastSegment.isNotEmpty) {
          values.add(lastSegment);
        }
      }
    }

    return values.toList(growable: false);
  }
}
