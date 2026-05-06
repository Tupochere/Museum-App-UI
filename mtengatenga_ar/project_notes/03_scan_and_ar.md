# Scan and AR

## How scanning works

The main scan feature is here:

- `lib/features/scan/scan_screen.dart`

This screen supports two kinds of scanning:

- QR scanning
- vision-based scanning with the camera

### QR scanning

For QR mode, the app uses:

- `mobile_scanner`
- `IArtifactRepository.getArtifactByQrCode(...)`

Flow:

1. user points camera at a QR code
2. app reads the code
3. app looks up the artifact from the repository
4. app saves the scan in `ScanHistoryService`
5. app opens the artifact viewer or details

Related files:

- `lib/core/services/scan_history_service.dart`
- `lib/features/scan/scan_history_screen.dart`
- `lib/features/artifact/artifact_details_screen.dart`

### Vision scanning

Vision scanning also lives in:

- `lib/features/scan/scan_screen.dart`
- `lib/services/vision_service.dart`
- `lib/services/search_service.dart`

Flow:

1. app captures an image
2. `VisionService` analyzes the picture
3. result becomes a text description
4. `SearchService` tries to match that description to an artifact
5. if a match is good enough, the artifact details open

## How AR works

Main AR screen:

- `lib/features/ar/ar_viewer_screen.dart`

Important helper files:

- `lib/core/services/ar_service.dart`
- `lib/core/services/plane_detection_service.dart`
- `lib/core/services/model_manager_service.dart`
- `lib/screens/model_3d_viewer.dart`

### Easy explanation

Think of AR like placing a digital object on a real table.

- `ArService` checks if the device can do AR
- `PlaneDetectionService` helps find a flat real-world surface
- `ModelManagerService` loads and caches the 3D model file
- `ArViewerScreen` lets the user place, scale, move, and rotate the model

If AR is not available or the model is missing:

- the app shows a fallback message
- the user can still go to normal artifact details or 3D preview

## Ticket protection for premium features

Important file:

- `lib/core/services/ticket_gate.dart`

This file protects special features.
Before opening Scan, AR, or AI Guide, the app can check whether the user has a valid ticket for today.

## Easy interview answer

You can say:

`The scan feature supports both QR recognition and camera-based visual matching. QR scanning directly fetches an artifact by code, while vision scanning analyzes an image and then uses search to find the closest artifact. The AR feature checks device support, detects a surface, loads a 3D model, and lets the user place the object in the real world.`
