# Notifications Feature — Supabase Implementation Plan

> **For Claude Code**: You are connected to the Supabase project via MCP. Follow each phase in order. Do not skip the database setup — the frontend code depends on it.

---

## Context

The `NotificationsPage.tsx` currently uses `mockService` (in-memory fake data) for both fetching the notification history and publishing new posts. The goal is to replace all mock calls with real Supabase reads and writes, and make the thumbnail image upload persist to Supabase Storage so it is accessible from the mobile app.

### Current mock calls to replace

| Location in `NotificationsPage.tsx` | Mock call | Replace with |
|---|---|---|
| `useEffect` on mount | `mockService.getNotifications()` | Supabase select from `notifications` table |
| `publishPost` handler | `mockService.sendNotification(...)` | Supabase insert + Storage upload |
| `saveDraft` handler | `toast.message(...)` only | Supabase insert with `status = 'draft'` |

---

## Phase 1 — Supabase Database Setup (use MCP)

### 1.1 Create the `notifications` table

Run the following SQL via the Supabase MCP tool (use `execute_sql` or the SQL editor tool):

```sql
create table if not exists public.notifications (
  id           uuid primary key default gen_random_uuid(),
  post_type    text not null check (post_type in ('event', 'news')),
  title        text not null,
  summary      text not null,
  audience     text not null check (audience in ('All Visitors', 'Recent Visitors', 'Custom Filter')),
  category     text not null,
  cta_label    text not null default 'Learn more',
  featured     boolean not null default false,
  status       text not null default 'draft' check (status in ('draft', 'sent')),
  -- event-only fields (nullable for news posts)
  event_date   date,
  event_time   time,
  location     text,
  -- thumbnail
  thumbnail_url text,
  -- computed / metadata
  recipients   integer not null default 0,
  sent_at      timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
```

### 1.2 Enable Row Level Security (RLS)

```sql
alter table public.notifications enable row level security;

-- Allow authenticated users (admins) to do everything
create policy "Admins can manage notifications"
  on public.notifications
  for all
  to authenticated
  using (true)
  with check (true);

-- Allow anonymous/app users to only READ sent notifications
create policy "Anyone can read sent notifications"
  on public.notifications
  for select
  to anon
  using (status = 'sent');
```

### 1.3 Create updated_at trigger

```sql
create or replace function public.handle_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger notifications_updated_at
  before update on public.notifications
  for each row execute procedure public.handle_updated_at();
```

---

## Phase 2 — Supabase Storage Setup (use MCP)

### 2.1 Create the storage bucket

Use the Supabase MCP tool to create a storage bucket named **`notification-thumbnails`**:

- **Bucket name**: `notification-thumbnails`
- **Public**: `true` (so the mobile app can access images via a public URL without auth)
- **Allowed MIME types**: `image/jpeg`, `image/png`, `image/webp`
- **Max file size**: `5242880` (5 MB)

### 2.2 Storage bucket policy

Run the following SQL to set policies on the bucket:

```sql
-- Authenticated admins can upload
create policy "Admins can upload thumbnails"
  on storage.objects
  for insert
  to authenticated
  with check (bucket_id = 'notification-thumbnails');

-- Anyone can read/download thumbnails (public bucket)
create policy "Public thumbnail access"
  on storage.objects
  for select
  to anon
  using (bucket_id = 'notification-thumbnails');

-- Authenticated admins can delete thumbnails
create policy "Admins can delete thumbnails"
  on storage.objects
  for delete
  to authenticated
  using (bucket_id = 'notification-thumbnails');
```

---

## Phase 3 — TypeScript Types Update

### 3.1 Update `src/types/index.ts`

Replace the existing `NotificationItem` interface and extend `SentStatus` to include `'draft'`:

```ts
// Replace this:
export type SentStatus = "Sent";

// With this:
export type NotificationStatus = "draft" | "sent";

// Replace the existing NotificationItem interface with:
export interface NotificationItem {
  id: string;
  post_type: "event" | "news";
  title: string;
  summary: string;
  audience: NotificationAudience;
  category: string;
  cta_label: string;
  featured: boolean;
  status: NotificationStatus;
  event_date?: string | null;
  event_time?: string | null;
  location?: string | null;
  thumbnail_url?: string | null;
  recipients: number;
  sent_at?: string | null;
  created_at: string;
  updated_at: string;
}
```

> **Note**: The old `sentAt` (camelCase) field is replaced by `sent_at` (snake_case) matching the Supabase column. Update any references to `item.sentAt` in `NotificationsPage.tsx` to `item.sent_at`.

---

## Phase 4 — Notification Service

### 4.1 Create `src/services/notificationService.ts`

Create this new file — do **not** modify `mockService.ts`:

```ts
import { supabase } from "@/lib/supabase";
import type { NotificationAudience, NotificationItem } from "@/types";

const audienceRecipients: Record<NotificationAudience, number> = {
  "All Visitors": 3421,
  "Recent Visitors": 864,
  "Custom Filter": 214,
};

export type CreateNotificationPayload = {
  post_type: "event" | "news";
  title: string;
  summary: string;
  audience: NotificationAudience;
  category: string;
  cta_label: string;
  featured: boolean;
  event_date?: string;
  event_time?: string;
  location?: string;
  thumbnailFile?: File | null;
  status: "draft" | "sent";
};

/**
 * Upload a thumbnail image to Supabase Storage and return the public URL.
 * Returns null if no file is provided.
 */
async function uploadThumbnail(file: File): Promise<string | null> {
  const ext = file.name.split(".").pop();
  const fileName = `${Date.now()}-${Math.random().toString(36).slice(2)}.${ext}`;

  const { error } = await supabase.storage
    .from("notification-thumbnails")
    .upload(fileName, file, { upsert: false });

  if (error) throw new Error(`Thumbnail upload failed: ${error.message}`);

  const { data } = supabase.storage
    .from("notification-thumbnails")
    .getPublicUrl(fileName);

  return data.publicUrl;
}

/**
 * Fetch all notifications ordered by newest first.
 */
export async function fetchNotifications(): Promise<NotificationItem[]> {
  const { data, error } = await supabase
    .from("notifications")
    .select("*")
    .order("created_at", { ascending: false });

  if (error) throw new Error(error.message);
  return data as NotificationItem[];
}

/**
 * Insert a new notification (draft or sent) into Supabase.
 */
export async function createNotification(
  payload: CreateNotificationPayload
): Promise<NotificationItem> {
  let thumbnail_url: string | null = null;

  if (payload.thumbnailFile) {
    thumbnail_url = await uploadThumbnail(payload.thumbnailFile);
  }

  const row = {
    post_type: payload.post_type,
    title: payload.title,
    summary: payload.summary,
    audience: payload.audience,
    category: payload.category,
    cta_label: payload.cta_label,
    featured: payload.featured,
    status: payload.status,
    event_date: payload.event_date || null,
    event_time: payload.event_time || null,
    location: payload.location || null,
    thumbnail_url,
    recipients: audienceRecipients[payload.audience],
    sent_at: payload.status === "sent" ? new Date().toISOString() : null,
  };

  const { data, error } = await supabase
    .from("notifications")
    .insert(row)
    .select()
    .single();

  if (error) throw new Error(error.message);
  return data as NotificationItem;
}

/**
 * Delete a notification by ID (also deletes its thumbnail if stored).
 */
export async function deleteNotification(id: string): Promise<void> {
  const { error } = await supabase.from("notifications").delete().eq("id", id);
  if (error) throw new Error(error.message);
}
```

---

## Phase 5 — Update `NotificationsPage.tsx`

Make the following targeted changes to `src/pages/notifications/NotificationsPage.tsx`:

### 5.1 Remove the mock import, add the service imports

```ts
// REMOVE this line:
import { mockService } from "@/services/mockService";

// ADD these imports:
import { createNotification, fetchNotifications } from "@/services/notificationService";
```

### 5.2 Add a `thumbnailFile` state ref

Below the existing `fileInputRef`, add:

```ts
const [thumbnailFile, setThumbnailFile] = useState<File | null>(null);
```

### 5.3 Update `handleThumbnailChange` to also capture the File object

```ts
const handleThumbnailChange = (event: React.ChangeEvent<HTMLInputElement>) => {
  const file = event.target.files?.[0];
  if (!file) return;

  if (thumbnailPreviewUrl) URL.revokeObjectURL(thumbnailPreviewUrl);

  setThumbnailFile(file);                          // <-- ADD THIS
  setThumbnailPreviewUrl(URL.createObjectURL(file));
  setThumbnailName(file.name);
};
```

### 5.4 Update `clearThumbnail` to also clear the file state

```ts
const clearThumbnail = () => {
  if (thumbnailPreviewUrl) URL.revokeObjectURL(thumbnailPreviewUrl);
  setThumbnailFile(null);                          // <-- ADD THIS
  setThumbnailPreviewUrl(null);
  setThumbnailName("");
  if (fileInputRef.current) fileInputRef.current.value = "";
};
```

### 5.5 Replace the `useEffect` that loads notifications

```ts
// REMOVE:
useEffect(() => {
  mockService.getNotifications().then((data) => {
    setItems(data);
    setLoading(false);
  });
}, []);

// REPLACE WITH:
useEffect(() => {
  fetchNotifications()
    .then((data) => setItems(data))
    .catch(() => toast.error("Failed to load notifications."))
    .finally(() => setLoading(false));
}, []);
```

### 5.6 Replace `saveDraft`

```ts
// REMOVE the old saveDraft function and replace with:
const saveDraft = async () => {
  const payload = form.getValues();
  try {
    const saved = await createNotification({
      post_type: payload.postType,
      title: payload.title || "Untitled Draft",
      summary: payload.summary || "",
      audience: payload.audience,
      category: payload.category,
      cta_label: payload.ctaLabel,
      featured: payload.featured,
      event_date: payload.date,
      event_time: payload.time,
      location: payload.location,
      thumbnailFile,
      status: "draft",
    });
    setItems((prev) => [saved, ...prev]);
    toast.message("Draft saved", {
      description: "Your post has been saved as a draft in the database.",
    });
  } catch (err) {
    toast.error("Failed to save draft.");
    console.error(err);
  }
};
```

### 5.7 Replace `publishPost`

```ts
// REMOVE the existing publishPost and replace with:
const publishPost = form.handleSubmit(async (payload) => {
  try {
    const sent = await createNotification({
      post_type: payload.postType,
      title: payload.title,
      summary: payload.summary,
      audience: payload.audience,
      category: payload.category,
      cta_label: payload.ctaLabel,
      featured: payload.featured,
      event_date: payload.date,
      event_time: payload.time,
      location: payload.location,
      thumbnailFile,
      status: "sent",
    });

    setItems((prev) => [sent, ...prev]);
    toast.success(payload.postType === "event" ? "Event post published." : "News post published.");

    const nextDefaults = getDefaultValues(payload.postType);
    nextDefaults.audience = payload.audience;
    form.reset(nextDefaults);
    clearThumbnail();
  } catch (err) {
    toast.error("Failed to publish post. Please try again.");
    console.error(err);
  }
});
```

### 5.8 Fix the sent history list rendering

In the JSX where items are rendered, update the field names to match the new `NotificationItem` shape:

```tsx
// Change item.message → item.summary
<p className="max-w-2xl text-sm text-muted-foreground">{item.summary}</p>

// Change item.sentAt → item.sent_at
<span>Sent: {item.sent_at ? new Date(item.sent_at).toLocaleString() : "Draft"}</span>

// Add thumbnail display inside the list item (optional but recommended):
{item.thumbnail_url ? (
  <img
    src={item.thumbnail_url}
    alt={item.title}
    className="h-12 w-16 rounded-md object-cover shrink-0"
  />
) : null}
```

---

## Phase 6 — Verification Checklist

After implementing all phases above, verify the following:

- [ ] `notifications` table exists in Supabase with all columns
- [ ] RLS policies are enabled and correct
- [ ] `notification-thumbnails` storage bucket is created and public
- [ ] Storage policies allow authenticated upload and public read
- [ ] `notificationService.ts` file is created with no TypeScript errors
- [ ] `NotificationsPage.tsx` no longer imports from `mockService`
- [ ] Publishing a post inserts a row into Supabase and the image appears in the bucket
- [ ] Saving a draft inserts a row with `status = 'draft'`
- [ ] The "Recent Posts" list loads from Supabase on page mount
- [ ] Error toasts appear if any Supabase call fails

---

## Notes for the Mobile App

The mobile app (React Native / Expo) will need to:

1. Query `notifications` table where `status = 'sent'` — this is already permitted by the `anon` RLS policy.
2. Use `thumbnail_url` directly as an `<Image>` source — it's a public Supabase Storage URL.
3. Optionally set up a **Supabase Realtime** subscription on the `notifications` table to push live updates to devices without polling.

---

## Files Modified Summary

| File | Action |
|---|---|
| `src/types/index.ts` | Update `NotificationItem` + `NotificationStatus` type |
| `src/services/notificationService.ts` | **Create new file** |
| `src/pages/notifications/NotificationsPage.tsx` | Replace mock calls with service calls |
| Supabase: `notifications` table | **Create via MCP** |
| Supabase: `notification-thumbnails` bucket | **Create via MCP** |
