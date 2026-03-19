# Project Overview

## What This App Is

`mtengatenga_ar` is a Flutter mobile app for a museum visitor experience.  
It focuses on discovery and engagement around cultural artifacts.

Core user-facing modules:
- Home discovery and featured artifacts
- QR scan to open artifact content
- Artifact details and media
- Scan history
- Indoor navigation/map UI
- Events, tickets/donations, profile, and AI guide UI

## Product Direction (Current)

The project is converging on two core technical outcomes:
1. Real QR scanning with camera and lookup by QR code.
2. Offline-first data access using Brick ORM + SQLite, synced with Supabase.

## Tech Stack (High-Level)

- Flutter / Dart
- Supabase (`supabase_flutter`)
- Brick offline-first stack:
  - `brick_offline_first_with_supabase`
  - `brick_sqlite`
  - generated adapters and migrations in `lib/brick/`
- Dependency injection with `get_it`
- Local UI persistence for scan history with `shared_preferences`

## Key App Entry Points

- App bootstrap: `mtengatenga_ar/lib/main.dart`
- Service registration: `mtengatenga_ar/lib/core/services/service_locator.dart`
- Scan feature: `mtengatenga_ar/lib/features/scan/scan_screen.dart`
- Artifact data contracts: `mtengatenga_ar/lib/core/domain/repositories/`
