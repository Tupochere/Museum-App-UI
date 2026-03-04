# Technical Architecture

## Runtime Boot Sequence

1. `main()` runs Flutter app immediately.
2. `_bootstrapServices()` loads `.env`.
3. `ServiceLocator.setup()` initializes:
   - Supabase client (`SupabaseService`)
   - Brick repository (`BrickConfig.initialize()`)
   - DI registrations for repositories and scan history service.

Relevant files:
- `mtengatenga_ar/lib/main.dart`
- `mtengatenga_ar/lib/core/services/service_locator.dart`
- `mtengatenga_ar/lib/brick/config.dart`

## Data Layer Design

### Domain Models

Brick models use `.model.dart` naming and `OfflineFirstWithSupabaseModel`:
- `artifact.model.dart`
- `room.model.dart`

These models map to Supabase tables via:
- `@ConnectOfflineFirstWithSupabase`
- `@Supabase(...)`
- `@Sqlite(...)`

### Repositories

Concrete repositories are Brick-backed:
- `ArtifactRepositoryBrick`
- `RoomRepositoryBrick`

Important artifact queries:
- by id
- by room id
- by QR code (`getArtifactByQrCode`)
- featured artifacts

## Scanner Flow

`scan_screen.dart` uses:
- `MobileScanner` for real camera QR detection,
- `IArtifactRepository.getArtifactByQrCode` for lookup,
- `ScanHistoryService.addScan` for persistence.

Success path:
1. detect QR
2. fetch artifact
3. show found state + open details
4. save scan history entry

Failure paths:
- no match -> no-match state + auto retry
- runtime error -> error state + retry

## Offline-First Behavior

Brick repository policies currently include:
- `awaitRemoteWhenNoneExist` for main reads
- `localOnly` for featured subset call

This gives remote-backed reads with local cache fallback/retention in SQLite.

## Generated Code

Generated files live in `mtengatenga_ar/lib/brick/`:
- `brick.g.dart`
- `adapters/*.g.dart`
- `db/schema.g.dart`
- `db/*.migration.dart`

If regeneration is needed:
```bash
dart run build_runner build --delete-conflicting-outputs
```
