# Login, Data, and Structure

## How login works

The login system lives in these files:

- `lib/features/auth/login_screen.dart`
- `lib/features/auth/registration_screen.dart`
- `lib/features/auth/forgot_password_screen.dart`
- `lib/features/auth/auth_gate.dart`
- `lib/core/services/auth_service.dart`
- `lib/core/services/auth_state.dart`

### Simple explanation

Think of login like a gatekeeper.

- `AuthGate` shows either Login or Register.
- `AuthService` talks to Supabase for sign in, sign up, sign out, and password reset.
- `AuthStateNotifier` listens for auth changes and tells the UI when the user becomes logged in or logged out.
- `main.dart` listens to that auth state and switches between auth screens and the real app.

## How shared services work

The service setup file is:

- `lib/core/services/service_locator.dart`

This file is like a toolbox shelf.
It creates shared helpers once, then the rest of the app can reuse them.

Examples registered there:

- `SupabaseService`
- `AuthService`
- `AuthStateNotifier`
- `IArtifactRepository`
- `ScanHistoryService`
- `SavedArtifactsService`
- `LanguageState`
- `TranslationService`
- `SearchService`
- `NotificationService`
- `PushNotificationService`

## How data is stored and fetched

Main data code lives in:

- `lib/core/domain/entities/`
- `lib/core/domain/repositories/`
- `lib/core/data/repositories/`

### Easy explanation

Think of it like this:

- `entities` are the shapes of the data, like artifact or room
- `repositories` are the workers that know how to get that data
- `services` are helpers that manage special behaviors around the data

Important repository files:

- `lib/core/data/repositories/artifact_repository_brick.dart`
- `lib/core/data/repositories/artifact_repository_supabase.dart`
- `lib/core/data/repositories/room_repository_brick.dart`

## Supabase and backend connection

Important file:

- `lib/core/services/supabase_service.dart`

This is the bridge to the backend.
It initializes Supabase, and then other services use the client for:

- authentication
- ticket orders
- saved artifacts
- notifications
- artifact search data

## Easy interview answer

You can say:

`The app uses a service locator pattern to register shared services at startup. Authentication is handled with Supabase through AuthService and AuthStateNotifier. Data is organized into entities, repositories, and services so the UI stays separate from backend logic.`
