## [1.0.2]

- Fixed ContactsUI issue for iOS

## [1.0.1]

- Dart format

## [1.0.0] - 2025-08-07

### Added

- Light and full contact fetching (with optional photo, email, phone, etc.)
- Pagination and streaming-based contact loading for large datasets
- Fetch contact by ID
- Insert, update, delete single and multiple contacts
- vCard export and import (Pending)
- Contact change observer:
    - Android: using `ContentObserver`
    - iOS: using `CNContactStoreDidChangeNotification`
- Contact search by name, phone, email
- Fetch groups/labels, assign to contacts
- Merge suggestions based on duplicates
- Filter contacts by SIM, device, or social account (enum-based)
- Fetch deleted contacts (Android only)
- Permission handling (Android & iOS)
- Dart-side null-safe abstraction
- Platform channel integration
- Example app
