# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Layout

All Flutter app code lives in `mtengatenga_ar/`. Everything else at the repo root is documentation.

- `AI_HANDOFF.md` — primary orientation doc; read this first for context
- `docs/` — architecture and progress notes
- `WIRELESS_DEVICE_SETUP.md` — Android wireless debugging setup

Branch/PR and release rules live in [Git Workflow](#git-workflow) and
[Release Pipeline](#release-pipeline-apk) below.

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

### Cloud Functions Deploy

Run from inside `cloud_functions/` (PowerShell):

```powershell
gcloud.cmd functions deploy aiProxy `
  --gen2 `
  --runtime=nodejs20 `
  --region=us-central1 `
  --trigger-http `
  --allow-unauthenticated `
  --entry-point=aiProxy `
  --memory=512MB `
  --timeout=120s `
  --min-instances=1 `
  --source=. `
  --env-vars-file=env.yaml
```

## Environment Setup

Create `mtengatenga_ar/.env` (git-ignored) with at least:
```
SUPABASE_URL=...
SUPABASE_ANON_KEY=...
PAYCHANGU_SECRET_KEY=...     # PayChangu API secret (use a sec-test-... key in test mode)
PAYCHANGU_TEST_MODE=true
```
See `mtengatenga_ar/.env.example` for the full list of supported keys (AI/TTS
providers, Cloud Function proxy URL, etc.).

The `.env` file is loaded as a Flutter asset at startup (`flutter_dotenv`) and is
read throughout the app via `dotenv.env['KEY']`.

> **CI note:** `.env` is git-ignored, so the release pipeline **recreates it from
> GitHub Actions secrets** at build time (see [Release Pipeline](#release-pipeline-apk)).
> Any new env var the app depends on must be added in **three** places or it will
> be empty in released builds: (1) `.env.example`, (2) a GitHub Actions repository
> secret, and (3) the `Create .env` step in `.github/workflows/release.yml`.
> Forgetting (3) is exactly what caused the PayChangu "403 secret key missing" bug.

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

- `main` — production; releases are cut from here by pushing a version tag
- `dev` — integration branch, merge target for features
- `feature/<name>` — one branch per task

PRs go `feature/<name>` → `dev`, then `dev` → `main` for releases. Use rebase (`git rebase dev`) to sync feature branches, then `git push --force-with-lease`.

## Release Pipeline (APK)

The app is distributed as a signed Android APK via **GitHub Releases**, built by
`.github/workflows/release.yml` (repo: `Tupochere/Museum-App-UI`).

**Trigger:** pushing a tag matching `v*` builds *and publishes* a Release.
`workflow_dispatch` (manual run) builds and uploads an APK artifact **without**
publishing a Release — use it to validate a build.

```bash
# Cut a release (tags the given commit; that commit's tree is what ships):
git tag v1.0.9 <commit-sha>
git push origin v1.0.9
```

**What the workflow does, in order:** checkout the tagged commit → set up Java 17
+ Flutter **3.38.3** (pinned; newer Flutter breaks the legacy `arcore_flutter_plugin`)
→ **Create `.env` from secrets** → restore keystore & sign → `flutter pub get` →
`build_runner` → patch the legacy ARCore plugin (namespace + Kotlin null-safety)
→ `flutter build apk --release` → stage two APK copies → publish the Release.

**Required GitHub Actions repository secrets:**
`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `PAYCHANGU_SECRET_KEY`, `PAYCHANGU_TEST_MODE`,
`KEYSTORE_BASE64`, `KEYSTORE_STORE_PASSWORD`, `KEYSTORE_KEY_PASSWORD`, `KEYSTORE_KEY_ALIAS`.

**Critical rules:**
- **The tag builds the commit it points to** — not "main now". Make sure your fix
  is on that commit before tagging.
- **Set/update any needed secret _before_ pushing the tag.** Secrets are read at
  build time; a missing secret becomes an empty string in the bundled `.env`.
- The build produces two assets: a versioned `mtengatenga-ar-<tag>.apk` and a
  stable `mtengatenga-ar.apk`. The stable name powers the permanent "latest" URL:
  `https://github.com/Tupochere/Museum-App-UI/releases/latest/download/mtengatenga-ar.apk`
- **The signing keystore (`KEYSTORE_BASE64`) is irreplaceable.** Android refuses to
  *update* an installed app with an APK signed by a different key. Lose it and
  existing users can only move forward by uninstalling (losing local data).
- **Sideloaded APKs do not auto-update** like Play Store apps. Already-installed
  users keep their version until they re-download or an in-app updater prompts them.

## Secrets & What Not to Commit

- **Never commit secrets.** `.env`, `cloud_functions/env.yaml`, and keystores are
  git-ignored and injected at deploy/build time from GitHub secrets / GCP Secret
  Manager. Rotate any key that leaks.
- **Secret keys do not belong in the mobile app.** A key placed in `.env` ships
  inside the APK asset and is extractable by anyone. `PAYCHANGU_SECRET_KEY` is
  currently bundled this way as a **test-mode stopgap**; a live key must instead be
  proxied server-side (mirror the existing `aiProxy` Cloud Function, which holds the
  AI keys server-side).
- **Never commit generated/installed artifacts:** `node_modules/`, `build/`,
  `.dart_tool/`, or Claude Code worktree copies under `.claude/worktrees/`. These
  are large, platform-specific, and regenerable (`npm ci`, `flutter pub get`).
- Remember: **`.gitignore` does not untrack files already tracked.** To stop
  tracking something already committed, use `git rm -r --cached <path>` (keeps it on
  disk), add it to `.gitignore`, then commit.

## Generated Code

After modifying any `.model.dart` file, always regenerate:
```bash
dart run build_runner build --delete-conflicting-outputs
```
