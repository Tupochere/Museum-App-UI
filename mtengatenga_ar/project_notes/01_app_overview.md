# App Overview

## What this app is

Think of the app like a smart museum helper.

- It helps visitors log in.
- It helps them find artifacts.
- It lets them scan museum items.
- It can open 3D and AR views.
- It gives AI help and voice guidance.
- It lets people buy tickets and save favorite artifacts.

## Where the app starts

The app starts in:

- `lib/main.dart`

This file does the first important jobs:

- starts Flutter
- loads `.env`
- starts Firebase
- starts Supabase-related services
- sets up shared services with `ServiceLocator.setup()`

After that, `MtengatengaApp` decides what the user should see:

- if the user is logged in, show `AppShell`
- if the user is not logged in, show `AuthGate`

## How screen navigation works

The main shell is here:

- `lib/core/ui/shell/app_shell.dart`

This is like the app's main house.
It keeps the bottom navigation tabs and swaps the main pages.

Main tabs inside `AppShell`:

- Home
- Saved
- Tickets
- Profile

## Main feature folders

Most user features live in:

- `lib/features/`

Important examples:

- `features/home/mtengatenga_home_screen.dart`
- `features/auth/`
- `features/scan/`
- `features/search/`
- `features/artifact/`
- `features/ar/`
- `features/ai_guide/`
- `features/tickets/`
- `features/events/`
- `features/profile/`
- `features/saved/`

## Easy way to explain the app flow

You can say:

`The app starts in main.dart, loads shared services, checks whether the user is signed in, and then opens either the auth flow or the main app shell with tabs like Home, Saved, Tickets, and Profile. From there, users can scan artifacts, open details, use AI help, and access AR or ticket features.`
