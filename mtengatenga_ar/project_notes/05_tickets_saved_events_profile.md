# Tickets, Saved Items, Events, and Profile

## How tickets work

Main files:

- `lib/features/tickets/tickets_hub_screen.dart`
- `lib/features/tickets/tickets_donation_screen.dart`
- `lib/features/tickets/ticket_checkout_screen.dart`
- `lib/features/tickets/ticket_wallet_screen.dart`
- `lib/services/payment_service.dart`

### Simple explanation

Think of tickets like a pass to special museum powers.

Flow:

1. user chooses ticket types and donation amount
2. checkout calculates the total in MWK
3. `PaymentService` creates a pending order in Supabase
4. app opens hosted payment
5. app verifies payment success
6. completed tickets appear in the wallet

`PaymentService` also checks whether the user has a valid ticket for today.
That is why ticket-gated features can be protected.

## How saved artifacts work

Main files:

- `lib/core/services/saved_artifacts_service.dart`
- `lib/features/saved/saved_artifacts_screen.dart`
- `lib/features/artifact/artifact_details_screen.dart`

### Easy explanation

This works like bookmarking a favorite page in a book.

- the user taps the heart icon on an artifact
- `SavedArtifactsService` saves or removes the artifact id
- the saved screen reloads and shows the current favorites
- data is stored in the `saved_artifacts` table in Supabase

## How events and notifications work

Main files:

- `lib/features/events/events_screen.dart`
- `lib/features/events/event_details_screen.dart`
- `lib/features/events/notification_center_screen.dart`
- `lib/services/notification_service.dart`
- `lib/services/notification_badge_service.dart`
- `lib/services/push_notification_service.dart`

### Easy explanation

This part is the museum news desk.

- `NotificationService` loads events and news from Supabase
- it can also subscribe to real-time new notifications
- `NotificationBadgeService` tracks what the user has read
- `PushNotificationService` handles device push notifications

## How profile works

Main file:

- `lib/features/profile/profile_preferences_screen.dart`

This screen is like the control room for the user.
It lets the user:

- change language
- open notification center
- open scan history
- open ticket wallet
- sign out

## Easy interview answer

You can say:

`The app includes a full visitor support layer beyond artifact viewing. Tickets and payments are handled through a checkout and wallet flow, saved artifacts work like bookmarks, event and news data come from Supabase with real-time updates, and the profile screen gathers user tools like language selection, ticket access, scan history, and sign out.`
