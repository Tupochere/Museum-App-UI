# AI Handoff: Museum App UI

This repository contains a Flutter app for a Malawi museum experience (`mtengatenga_ar`) with:
- rich museum UI flows (home, scan, artifact details, tickets, map, profile),
- Supabase backend integration,
- Brick offline-first caching (SQLite + Supabase sync),
- real QR scanning flow (`mobile_scanner`) wired to artifact lookup.

Use this file as the entry point, then read:
- `docs/PROJECT_OVERVIEW.md`
- `docs/TECH_ARCHITECTURE.md`
- `docs/PROGRESS_AND_NEXT_STEPS.md`
- `docs/GITHUB_PLAYBOOK.md`

## Fast Orientation

1. App code lives in `mtengatenga_ar/`.
2. Dependency bootstrapping starts in `mtengatenga_ar/lib/main.dart`.
3. Service DI and repository wiring are in `mtengatenga_ar/lib/core/services/service_locator.dart`.
4. Brick setup is in `mtengatenga_ar/lib/brick/config.dart`.
5. Scanner flow is in `mtengatenga_ar/lib/features/scan/scan_screen.dart`.

## Current Branch Context

- Active branch goal: combine offline-first Brick data layer with real QR scan flow.
- Branch: `feature/brick-offline-first`.
- Existing long-lived branches: `main`, `develop`, `feature/data-layer-supabase`, `feature/wire-ui-to-data`.

## Environment Notes

- Required `.env` keys:
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
- Wireless Android setup guide: `WIRELESS_DEVICE_SETUP.md`.
