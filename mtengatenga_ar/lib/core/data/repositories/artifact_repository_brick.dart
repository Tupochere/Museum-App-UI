import 'package:brick_core/query.dart';
import 'package:brick_offline_first/brick_offline_first.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sbf;

import '../../../brick/config.dart';
import '../../domain/entities/artifact.model.dart';
import '../../domain/repositories/artifact_repository.dart';
import 'museum_repository.dart';

class ArtifactRepositoryBrick implements IArtifactRepository {
  static const Map<String, String> _testModelUrlByArtifactQrCode = {
    'MASK001': 'assets/models/mask_placeholder.glb',
    'SHIELD001': 'assets/models/shield_placeholder.glb',
  };

  MuseumRepository get _repository => BrickConfig.repository;

  @override
  Future<List<Artifact>> getAllArtifacts() {
    return _repository
        .get<Artifact>(policy: OfflineFirstGetPolicy.awaitRemoteWhenNoneExist)
        .then((artifacts) {
          return artifacts
              .map(_applyTestModelUrlOverride)
              .toList(growable: false);
        });
  }

  @override
  Future<Artifact?> getArtifactById(String id) async {
    try {
      final records = await _repository.get<Artifact>(
        query: Query(where: [Where.exact('id', id)], limit: 1),
        policy: OfflineFirstGetPolicy.awaitRemoteWhenNoneExist,
      );

      if (records.isEmpty) return null;
      return _applyTestModelUrlOverride(records.first);
    } catch (_) {
      return _findArtifactByIdFromSupabase(id);
    }
  }

  @override
  Future<List<Artifact>> getArtifactsByRoom(String roomId) {
    return _repository
        .get<Artifact>(
          query: Query(where: [Where.exact('roomId', roomId)]),
          policy: OfflineFirstGetPolicy.awaitRemoteWhenNoneExist,
        )
        .then((artifacts) {
          return artifacts
              .map(_applyTestModelUrlOverride)
              .toList(growable: false);
        });
  }

  @override
  Future<Artifact?> getArtifactByQrCode(String qrCode) async {
    final candidates = _buildQrCandidates(qrCode);
    if (candidates.isEmpty) return null;

    // Prefer the old known-good path first: direct Supabase lookup by qr_code.
    // If this succeeds, scanning behavior matches pre-Brick implementation.
    final remoteFirst = await _findArtifactByQrFromSupabase(candidates);
    if (remoteFirst != null) {
      return remoteFirst;
    }

    // Local-cache fallback: match in-memory to avoid provider field mapping
    // edge cases that can incorrectly return the first record.
    final cachedMatch = await _findArtifactByQrFromLocalCache(candidates);
    if (cachedMatch != null) {
      return cachedMatch;
    }

    // Last fallback: pull all remote rows and compare normalized candidate variants.
    final remoteByVariant = await _findArtifactByQrVariantsFromSupabase(
      candidates,
    );
    if (remoteByVariant != null) {
      return remoteByVariant;
    }

    return null;
  }

  @override
  Future<List<Artifact>> getFeaturedArtifacts() {
    return _repository
        .get<Artifact>(
          query: Query(where: [Where.exact('isFeatured', true)]),
          policy: OfflineFirstGetPolicy.localOnly,
        )
        .then((artifacts) {
          return artifacts
              .map(_applyTestModelUrlOverride)
              .toList(growable: false);
        });
  }

  List<String> _buildQrCandidates(String raw) {
    final trimmed = raw.trim();
    final set = <String>{};

    if (trimmed.isNotEmpty) {
      set.add(trimmed);
      set.add(trimmed.toLowerCase());
    }

    final uri = Uri.tryParse(trimmed);
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
        final value = uri.queryParameters[key];
        if (value != null && value.trim().isNotEmpty) {
          set.add(value.trim());
        }
      }

      if (uri.pathSegments.isNotEmpty) {
        final last = uri.pathSegments.last.trim();
        if (last.isNotEmpty) {
          set.add(last);
        }
      }
    }

    return set.toList(growable: false);
  }

  List<String> _buildCaseVariants(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return const [];
    return <String>{
      trimmed,
      trimmed.toLowerCase(),
      trimmed.toUpperCase(),
    }.toList(growable: false);
  }

  String _normalizeQr(String value) {
    final lower = value.trim().toLowerCase();
    return lower.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  Future<Artifact?> _findArtifactByIdFromSupabase(String id) async {
    final client = sbf.Supabase.instance.client;

    try {
      final row = await client
          .from('artifacts')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;
      return _artifactFromSupabaseRow(Map<String, dynamic>.from(row as Map));
    } catch (_) {
      return null;
    }
  }

  Future<Artifact?> _findArtifactByQrFromSupabase(
    List<String> candidates,
  ) async {
    final client = sbf.Supabase.instance.client;

    for (final candidate in candidates) {
      final variants = _buildCaseVariants(candidate);

      for (final variant in variants) {
        try {
          final row = await client
              .from('artifacts')
              .select()
              .eq('qr_code', variant)
              .maybeSingle();

          if (row != null) {
            return _artifactFromSupabaseRow(
              Map<String, dynamic>.from(row as Map),
            );
          }
        } catch (_) {
          // Continue trying remaining candidates.
        }
      }

      try {
        for (final variant in variants) {
          final row = await client
              .from('artifacts')
              .select()
              .eq('id', variant)
              .maybeSingle();
          if (row != null) {
            return _artifactFromSupabaseRow(
              Map<String, dynamic>.from(row as Map),
            );
          }
        }
      } catch (_) {
        // Continue trying remaining candidates.
      }
    }

    return null;
  }

  Future<Artifact?> _findArtifactByQrFromLocalCache(
    List<String> candidates,
  ) async {
    try {
      final cached = await _repository.get<Artifact>(
        policy: OfflineFirstGetPolicy.localOnly,
      );

      for (final artifact in cached) {
        final artifactCandidates = <String>[];
        if (artifact.qrCode != null && artifact.qrCode!.isNotEmpty) {
          artifactCandidates.addAll(_buildQrCandidates(artifact.qrCode!));
        }
        artifactCandidates.addAll(_buildQrCandidates(artifact.id));

        if (_hasCandidateOverlap(candidates, artifactCandidates)) {
          return _applyTestModelUrlOverride(artifact);
        }
      }
    } catch (_) {
      // Keep lookup non-throwing.
    }

    return null;
  }

  Future<Artifact?> _findArtifactByQrVariantsFromSupabase(
    List<String> candidates,
  ) async {
    final client = sbf.Supabase.instance.client;

    try {
      final rows = await client.from('artifacts').select();

      for (final row in rows) {
        final map = Map<String, dynamic>.from(row);
        final rowCandidates = _rowCandidates(map);
        if (_hasCandidateOverlap(candidates, rowCandidates)) {
          return _artifactFromSupabaseRow(map);
        }
      }
    } catch (_) {
      // Keep non-throwing behavior.
    }

    return null;
  }

  Artifact _artifactFromSupabaseRow(Map<String, dynamic> row) {
    final id = row['id']?.toString();
    final name = row['name']?.toString();
    if (id == null || id.isEmpty || name == null || name.isEmpty) {
      throw StateError('Invalid artifact row: missing id/name');
    }

    final timelineRaw = row['timeline'];
    List<TimelineEvent>? timeline;
    if (timelineRaw is List) {
      final events = <TimelineEvent>[];
      for (final item in timelineRaw) {
        if (item is Map) {
          final mapped = _timelineEventFromDynamic(
            Map<String, dynamic>.from(item),
          );
          if (mapped != null) events.add(mapped);
        }
      }
      timeline = events.isEmpty ? null : events;
    }

    return _applyTestModelUrlOverride(
      Artifact(
        id: id,
        name: name,
        subtitle: _asString(row['subtitle']),
        category: _asString(row['category']),
        period: _asString(row['period']),
        description: _asString(row['description']) ?? '',
        culturalSignificance: _asString(row['cultural_significance']),
        additionalNotes: _asString(row['additional_notes']),
        timeline: timeline,
        markerImageUrl: _asString(row['marker_image_url']),
        displayImageUrl: _asString(row['display_image_url']),
        galleryImages: _asStringList(row['gallery_images']),
        audioUrl: _asString(row['audio_url']),
        videoUrls: _asStringList(row['video_urls']),
        model3dUrl: _asString(row['model_3d_url']),
        modelThumbnailUrl: _asString(row['model_thumbnail_url']),
        roomId: _asString(row['room_id']),
        location: _asString(row['location']),
        qrCode: _asString(row['qr_code']),
        isFeatured: _asBool(row['is_featured']),
        updatedAt: _parseDateTime(row['updated_at']),
      ),
    );
  }

  Artifact _applyTestModelUrlOverride(Artifact artifact) {
    final current = artifact.model3dUrl?.trim();
    if (current != null && current.isNotEmpty) {
      return artifact;
    }

    final qrCodeKey = artifact.qrCode?.trim().toUpperCase();
    if (qrCodeKey == null || qrCodeKey.isEmpty) {
      return artifact;
    }

    final override = _testModelUrlByArtifactQrCode[qrCodeKey];
    if (override == null || override.isEmpty) {
      return artifact;
    }

    return Artifact(
      id: artifact.id,
      name: artifact.name,
      subtitle: artifact.subtitle,
      category: artifact.category,
      period: artifact.period,
      description: artifact.description,
      culturalSignificance: artifact.culturalSignificance,
      additionalNotes: artifact.additionalNotes,
      timeline: artifact.timeline,
      markerImageUrl: artifact.markerImageUrl,
      displayImageUrl: artifact.displayImageUrl,
      galleryImages: artifact.galleryImages,
      audioUrl: artifact.audioUrl,
      videoUrls: artifact.videoUrls,
      model3dUrl: override,
      modelThumbnailUrl: artifact.modelThumbnailUrl,
      roomId: artifact.roomId,
      location: artifact.location,
      qrCode: artifact.qrCode,
      isFeatured: artifact.isFeatured,
      updatedAt: artifact.updatedAt,
    );
  }

  TimelineEvent? _timelineEventFromDynamic(Map<String, dynamic> row) {
    final year = _asString(row['year']);
    final event = _asString(row['event']);
    if (year == null || event == null) return null;

    return TimelineEvent(
      id: _asString(row['id']),
      year: year,
      event: event,
      artifactId: _asString(row['artifact_id']),
    );
  }

  String? _asString(dynamic value) {
    if (value == null) return null;
    final text = value.toString();
    if (text.isEmpty) return null;
    return text;
  }

  List<String>? _asStringList(dynamic value) {
    if (value is! List) return null;
    final list = value
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList();
    if (list.isEmpty) return null;
    return list;
  }

  bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase().trim();
      return lower == 'true' || lower == '1' || lower == 'yes';
    }
    return false;
  }

  DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value == null) return DateTime.now();
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }

  List<String> _rowCandidates(Map<String, dynamic> row) {
    final set = <String>{};

    final qr = _asString(row['qr_code']);
    if (qr != null && qr.isNotEmpty) {
      set.addAll(_buildQrCandidates(qr));
    }

    final id = _asString(row['id']);
    if (id != null && id.isNotEmpty) {
      set.addAll(_buildQrCandidates(id));
    }

    final code = _asString(row['code']);
    if (code != null && code.isNotEmpty) {
      set.addAll(_buildQrCandidates(code));
    }

    return set.toList(growable: false);
  }

  bool _hasCandidateOverlap(List<String> left, List<String> right) {
    final leftSet = left.map(_normalizeQr).where((v) => v.isNotEmpty).toSet();
    final rightSet = right.map(_normalizeQr).where((v) => v.isNotEmpty).toSet();
    return leftSet.intersection(rightSet).isNotEmpty;
  }
}
