import 'package:get_it/get_it.dart';

import '../../brick/config.dart';
import '../data/repositories/artifact_repository_brick.dart';
import '../data/repositories/room_repository_brick.dart';
import '../domain/repositories/artifact_repository.dart';
import '../domain/repositories/room_repository.dart';
import 'scan_history_service.dart';
import 'supabase_service.dart';
import '../../services/search_service.dart';
import '../../services/translation_service.dart';

class ServiceLocator {
  static final GetIt _getIt = GetIt.instance;

  static GetIt get instance => _getIt;

  static Future<void> setup() async {
    if (_getIt.isRegistered<SupabaseService>()) return;

    final supabaseService = SupabaseService();
    await supabaseService.initialize();
    _getIt.registerSingleton<SupabaseService>(supabaseService);

    await BrickConfig.initialize();

    _getIt.registerLazySingleton<IArtifactRepository>(
      ArtifactRepositoryBrick.new,
    );
    _getIt.registerLazySingleton<IRoomRepository>(
      RoomRepositoryBrick.new,
    );
    _getIt.registerLazySingleton<ScanHistoryService>(
      ScanHistoryService.new,
    );

    final languageState = LanguageState();
    await languageState.load();
    _getIt.registerSingleton<LanguageState>(languageState);
    _getIt.registerLazySingleton<TranslationService>(
      () => TranslationService(languageState),
    );
    _getIt.registerLazySingleton<SearchService>(
      SearchService.new,
    );
  }
}
