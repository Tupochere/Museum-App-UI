# Artifact Data Flow

## Source of Truth
- Online: Supabase `artifacts` table
- Offline: SQLite local cache (synced via Brick)

## Layers
1. Supabase (PostgreSQL)
   ↓
2. Repository (ArtifactRepositorySupabase)
   ↓
3. Domain Entity (Artifact)
   ↓
4. Mapper (ArtifactMapper)
   ↓
5. UI Model (UiArtifactSummary)
   ↓
6. Widget (displays in UI)

## Adding a new artifact property
1. Add column in Supabase SQL editor
2. Update `Artifact` entity in `domain/entities/artifact.dart`
3. Update `fromJson` factory in same file
4. Update `ArtifactRepositorySupabase` mapping if needed
5. Update `ArtifactMapper` if UI needs it
6. Update `UiArtifactSummary` if displaying new field
