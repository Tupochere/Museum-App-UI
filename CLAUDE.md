# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Layout

All Flutter app code lives in `mtengatenga_ar/`. Everything else at the repo root is documentation.

- `AI_HANDOFF.md` — primary orientation doc; read this first for context
- `docs/` — architecture and progress notes
- `GIT_BRANCH_WORKFLOW.md` — branch/PR workflow rules
- `WIRELESS_DEVICE_SETUP.md` — Android wireless debugging setup

## Common Commands

All commands run from inside `mtengatenga_ar/`:

```bash
# Install dependencies
flutter pub get

# Run the app (requires a connected device or emulator)
flutter run

# Static analysis
dart analyze

# Run tests
flutter test

# Run a single test file
flutter test test/path/to/test_file.dart

# Regenerate Brick ORM adapters and SQLite migrations
dart run build_runner build --delete-conflicting-outputs
```

## Environment Setup

Create `mtengatenga_ar/.env` with:
```
SUPABASE_URL=...
SUPABASE_ANON_KEY=...
```

The `.env` file is loaded as a Flutter asset at startup (`flutter_dotenv`).

## Architecture

### Boot Sequence

`main.dart` → `_bootstrapServices()` → `ServiceLocator.setup()`:
1. Loads `.env` via `flutter_dotenv`
2. Initializes `SupabaseService`
3. Initializes Brick repository (`BrickConfig.initialize()`)
4. Registers DI bindings via `get_it`

### Data Layer (Brick ORM)

Offline-first stack: Brick ORM + SQLite (local cache) + Supabase (remote).

- Domain models use `.model.dart` naming and extend `OfflineFirstWithSupabaseModel`
  - `lib/core/domain/entities/artifact.model.dart`
  - `lib/core/domain/entities/room.model.dart`
- Repository interfaces live in `lib/core/domain/repositories/`
- Concrete Brick implementations: `ArtifactRepositoryBrick`, `RoomRepositoryBrick`
- Generated code in `lib/brick/` — never edit manually:
  - `brick.g.dart`, `adapters/*.g.dart`, `db/schema.g.dart`, `db/*.migration.dart`
- Current fetch policies: `awaitRemoteWhenNoneExist` for main reads, `localOnly` for featured subset

### Feature Structure (`lib/features/`)

Each subdirectory is a self-contained feature:
- `scan/` — QR camera scanning via `mobile_scanner`, calls `getArtifactByQrCode`, persists to `ScanHistoryService`
- `ar/` — AR viewer using `arcore_flutter_plugin` (Android-only ARCore)
- `artifact/` — Artifact detail screen
- `home/` — Home discovery and featured artifacts
- `map/`, `tickets/`, `events/`, `profile/`, `saved/`, `ai_guide/` — other museum UI modules

### AR / 3D Viewer Dual-Mode

There are two AR-related viewers. The entry point is `lib/features/ar/ar_viewer_screen.dart`, which checks ARCore availability via `ArService`. If ARCore is unsupported, it falls back to `model_viewer_plus` (3D preview). The legacy `lib/screens/ar_artifact_viewer.dart` is an older single-mode implementation.

`ModelManagerService` (`lib/core/services/model_manager_service.dart`) handles model resolution: it downloads `.glb`/`.gltf` models (or copies from `assets/`) to a 100 MB temp cache, keyed by artifact ID + source hash.

### Services (`lib/core/services/`)

- `ServiceLocator` — `get_it`-based DI; call `ServiceLocator.setup()` once at boot
- `ArService` — ARCore availability checks and session lifecycle
- `ModelManagerService` — 3D model download, asset copy, and LRU cache
- `ScanHistoryService` — scan history persistence via `shared_preferences`
- `SupabaseService` — Supabase client wrapper

### Theme

Design tokens live in `lib/theme/app_tokens.dart` (`AppColors`, `AppSpacing`, `AppRadius`). Theme is configured in `lib/theme/app_theme.dart`. Custom font: Lexend (Regular/SemiBold/Bold).

## Code Style

When generating or modifying code, follow Object-Oriented principles as much as possible:
- **Encapsulation** — keep state private; expose only what is needed via public interfaces
- **Single Responsibility** — each class should have one clear purpose
- **Abstraction** — depend on interfaces/abstract classes, not concrete implementations (repositories, services)
- **Inheritance & Composition** — prefer composition over inheritance where appropriate
- **Polymorphism** — use abstract base classes or interfaces to allow interchangeable implementations

In practice: new logic belongs in a service or repository class, not inline in widgets. Widgets should delegate business logic to services via DI (`get_it`).

## Git Workflow

- `main` — production only, no direct commits
- `dev` — integration branch, merge target for features
- `feature/<name>` — one branch per task

PRs go `feature/<name>` → `dev`, then `dev` → `main` for releases. Use rebase (`git rebase dev`) to sync feature branches, then `git push --force-with-lease`.

## Generated Code

After modifying any `.model.dart` file, always regenerate:
```bash
dart run build_runner build --delete-conflicting-outputs
```
