# PhotoWindow MVP Checklist

This checklist maps the MVP specification to the current implementation.

## Product Scope

- Focus: photography timing windows and event reminders.
- In scope: SwiftUI MVP, local mock data, scoring, event cards, local notification placeholder, repository interfaces.
- Out of scope: social feed, chat, booking marketplace, payments, real auth, real weather API, real aviation API, TestFlight configuration.

## Core Models

- `UserProfile`: `PhotoWindow/Models/UserProfile.swift`
- `PhotographyCategory`: `PhotoWindow/Models/PhotographyCategory.swift`
- `ShootingLocation`: `PhotoWindow/Models/ShootingLocation.swift`
- `ShootingEvent`: `PhotoWindow/Models/ShootingEvent.swift`
- `ShootingWindow`: `PhotoWindow/Models/ShootingWindow.swift`
- `WeatherSnapshot`: `PhotoWindow/Models/WeatherSnapshot.swift`
- `AlertRule`: `PhotoWindow/Models/AlertRule.swift`
- `NotificationItem`: `PhotoWindow/Models/NotificationItem.swift`

All core models are separate files and conform to Swift value-type patterns suitable for mock storage and future backend serialization.

## Business Logic

- Scoring service: `PhotoWindow/Services/ShootingWindowScoringService.swift`
- Mock data service: `PhotoWindow/Services/MockDataService.swift`
- Notification placeholder: `PhotoWindow/Services/NotificationService.swift`
- Repository protocols: `PhotoWindow/Repositories/Repositories.swift`
- Mock repository implementations: `PhotoWindow/Repositories/MockRepositories.swift`

The views do not own scoring or data generation logic; state and actions live in services or view models.

## Mock Data Coverage

- Locations:
  - Brisbane Airport
  - UQ St Lucia Campus
  - Lake Moogerah
- Scenarios:
  - Astro / Milky Way window
  - Aviation special aircraft window
  - Landscape sunset / blue-hour window
  - Graduation and portrait windows
  - Cityscape window
- Each `ShootingWindow` includes score, score level, reason summary, weather snapshot, recommendation text, bookmark state, and alert state.

## SwiftUI Screens

- `HomeView`: today recommendation, top 3 windows, category entry points, special events.
- `CategoryView`: category-specific window list and detail navigation.
- `ShootingWindowDetailView`: title, category, location, time, score, reasons, weather, related events, alert toggle, bookmark toggle.
- `AlertSettingsView`: enabled state, reminder timing, minimum score, delete action.
- `ExploreLocationsView`: list-based location exploration, ready for future MapKit replacement.

## View Models

- `HomeViewModel`
- `CategoryViewModel`
- `ShootingWindowDetailViewModel`
- `AlertSettingsViewModel`
- `LocationViewModel`

Each view model reads from repository protocols, so mock repositories can later be replaced by Supabase, Firebase, or a custom backend.

## Verification

Validated commands:

```bash
bash Scripts/verify_core.sh
xcodebuild -scheme PhotoWindow -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Simulator deployment has also been verified with:

```bash
xcrun simctl install <device> <PhotoWindow.app>
xcrun simctl launch <device> com.photowindow.app
```

Latest simulator screenshot:

- `Screenshots/photowindow-home.png`

## GitHub

- Repository: `https://github.com/nhwwnhww/PhotoWindow`
- Default branch: `main`
