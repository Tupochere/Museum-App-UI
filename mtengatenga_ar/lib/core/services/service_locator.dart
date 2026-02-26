import '../data/repositories/artifact_repository_supabase.dart';
import '../data/repositories/i_artifact_repository.dart';
import 'scan_history_service.dart';
import 'supabase_service.dart';

class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();

  factory ServiceLocator() => _instance;

  ServiceLocator._internal();

  late final SupabaseService supabaseService;
  late final IArtifactRepository artifactRepository;
  late final ScanHistoryService scanHistoryService;

  void init() {
    supabaseService = SupabaseService();
    artifactRepository = ArtifactRepositorySupabase(supabaseService);
    scanHistoryService = ScanHistoryService();
  }
}
