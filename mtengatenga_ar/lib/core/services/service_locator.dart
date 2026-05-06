import 'package:get_it/get_it.dart';

import '../../brick/config.dart';
import '../data/repositories/artifact_repository_brick.dart';
import '../data/repositories/room_repository_brick.dart';
import '../domain/repositories/artifact_repository.dart';
import '../domain/repositories/room_repository.dart';
import 'auth_service.dart';
import 'auth_state.dart';
import 'indoor_navigation_service.dart';
import 'saved_artifacts_service.dart';
import 'scan_history_service.dart';
import 'supabase_service.dart';
import '../../services/notification_badge_service.dart';
import '../../services/notification_service.dart';
import '../../services/push_notification_service.dart';
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

    // Auth service + reactive state
    final authService = AuthService(supabaseService.client);
    _getIt.registerSingleton<AuthService>(authService);
    final authState = AuthStateNotifier(authService);
    _getIt.registerSingleton<AuthStateNotifier>(authState);

    await BrickConfig.initialize();

    _getIt.registerLazySingleton<IArtifactRepository>(
      ArtifactRepositoryBrick.new,
    );
    _getIt.registerLazySingleton<IRoomRepository>(RoomRepositoryBrick.new);
    _getIt.registerLazySingleton<ScanHistoryService>(ScanHistoryService.new);
    _getIt.registerLazySingleton<IndoorNavigationService>(
      IndoorNavigationService.new,
    );

    final savedArtifactsService = SavedArtifactsService();
    await savedArtifactsService.load();
    _getIt.registerSingleton<SavedArtifactsService>(savedArtifactsService);

    final languageState = LanguageState();
    await languageState.load();
    _getIt.registerSingleton<LanguageState>(languageState);
    _getIt.registerLazySingleton<TranslationService>(
      () => TranslationService(languageState),
    );
    _getIt.registerLazySingleton<SearchService>(SearchService.new);

    // Notification badge (load saved last-read timestamp)
    final badgeService = NotificationBadgeService();
    await badgeService.load();
    _getIt.registerSingleton<NotificationBadgeService>(badgeService);

    // Notification service (shared singleton across screens)
    _getIt.registerLazySingleton<NotificationService>(NotificationService.new);

    // Push notification service (FCM token registration)
    final pushService = PushNotificationService();
    _getIt.registerSingleton<PushNotificationService>(pushService);
    await pushService.initialize();
  }
}
