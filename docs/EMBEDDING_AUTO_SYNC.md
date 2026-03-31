# Automatic Artifact Embedding Sync

## Overview

When an artifact is created or updated in Supabase, its vector embedding is automatically regenerated. This keeps semantic search (`match_artifacts`) accurate without any manual steps.

## Architecture

```
Artifact INSERT/UPDATE (Supabase dashboard, app, or API)
  → Postgres trigger (trg_embed_artifact)
    → pg_net HTTP POST to Cloud Function /embed-single
      → Vertex AI text-embedding-005 generates 768-dim vector
        → Cloud Function PATCHes embedding back to artifacts row
```

## Components

### 1. Cloud Function endpoint — `POST /embed-single`

**File:** `cloud_functions/index.js`

Accepts `{ "id": "<artifact-uuid>" }`, fetches the artifact from Supabase, builds a document string from its content columns, generates an embedding via Vertex AI, and writes it back.

The document string is built from these fields (nulls excluded):
- `name`, `subtitle`, `category`
- `period` (prefixed with "Period:")
- `description`, `cultural_significance` (prefixed with "Cultural Significance:")
- `additional_notes`, `ai_context`
- `location` (prefixed with "Location:")

### 2. Postgres trigger — `trg_embed_artifact`

**Location:** Supabase database (applied as migration `add_auto_embed_trigger`)

- Uses the `pg_net` extension to make async HTTP calls from Postgres
- Fires `AFTER INSERT OR UPDATE` on these columns:
  - `name`, `subtitle`, `category`, `period`
  - `description`, `cultural_significance`, `ai_context`, `location`
- Calls `embed_artifact_on_change()` which POSTs the artifact ID to the Cloud Function
- The HTTP call is async (non-blocking) — the INSERT/UPDATE returns immediately

### 3. Batch endpoint — `POST /embed-artifacts` (existing)

Still available for bulk re-embedding. Send `{ "confirm": "yes-embed-all" }` to re-embed every artifact. Useful after:
- Deploying a new embedding model
- Changing the document string format
- Initial setup on a fresh database

## Trigger columns

The trigger only fires when one of the content columns changes. Updating non-content columns (e.g., `display_image_url`, `is_featured`, `display_order`) does **not** trigger a re-embed, since those fields are not included in the embedding document.

## Embedding model

Uses Vertex AI with fallback chain:
1. `text-embedding-005` (preferred)
2. `text-embedding-004`
3. `textembedding-gecko@003`

Output: 768-dimensional vector stored in the `embedding` column (pgvector `vector` type).

## Dependencies

| Component | Requirement |
|---|---|
| `pg_net` extension | Enabled in Supabase (migration handles this) |
| Cloud Function | Must be deployed with `/embed-single` endpoint |
| Vertex AI API | Must be enabled on the GCP project |
| `SUPABASE_URL` / `SUPABASE_SERVICE_KEY` | Set in Cloud Function env (`env.yaml`) |

## Testing

After editing an artifact in the Supabase dashboard, verify the embedding updated:

```sql
SELECT name, embedding IS NOT NULL AS has_embedding, updated_at
FROM artifacts
WHERE id = '<artifact-id>';
```

Or test the endpoint directly:

```bash
curl -X POST https://us-central1-project-8650b0cd-d679-4210-8e3.cloudfunctions.net/aiProxy/embed-single \
  -H "Content-Type: application/json" \
  -d '{"id": "<artifact-uuid>"}'
```

## Troubleshooting

- **Embedding not updating after edit:** Check Cloud Function logs (`gcloud functions logs read aiProxy`). The `pg_net` call is fire-and-forget — if the Cloud Function is down, the embedding silently won't update.
- **Wrong embedding dimension:** If you switch embedding models, run `POST /embed-artifacts` to re-embed all rows with the new model.
- **Trigger not firing:** Confirm the trigger exists: `SELECT tgname FROM pg_trigger WHERE tgrelid = 'artifacts'::regclass;`
