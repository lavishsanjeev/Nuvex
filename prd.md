# Nuvex — Product Requirements Document

Version: 2.0
Date: 2026-09-11
Platform: Android-first
Framework: Flutter
Project/package name: `nuvex`
Display name: `Nuvex`

## 1. Product definition

Nuvex is an Android-first, local-first personal file and photo workspace that uses the user's own Telegram account as the remote storage backend.

Nuvex is inspired by the useful storage/file-management behavior of Telegram Drive, but is an independent Flutter application with its own architecture, UI, data models, repositories and infrastructure boundaries.

Core path:

```text
Flutter UI
    ↓
State / Controllers
    ↓
Repositories
    ├── Local database / cache
    └── Telegram storage client
                ↓
             Telegram
```

Nuvex must not require a Nuvex-owned storage server for the core storage path.

## 2. Problem

Telegram can store personal files and media, but its native interface is not designed as a dedicated personal drive/gallery. Nuvex turns Telegram-backed storage into a focused mobile workspace with gallery browsing, local metadata, lazy previews, on-demand originals, transfers, collections and albums.

## 3. Primary goals

1. Build a reliable Android application with Flutter.
2. Authenticate the user's Telegram account using a real supported Telegram authorization flow.
3. Establish the Telegram session required for Nuvex storage operations.
4. Read Telegram-backed media/file metadata.
5. Upload files from the Android device to Telegram.
6. Download/open originals on demand.
7. Keep the UI responsive through local metadata and thumbnail caching.
8. Provide Photos and Collections as the initial navigation.
9. Provide reliable transfers with progress, retry and cancellation.
10. Protect credentials and session material locally.
11. Make a physical Android phone over USB the primary development target.

## 4. Authentication model

Nuvex distinguishes between:

### Telegram application credentials
- API ID
- API Hash

These identify the Nuvex Telegram application and are entered during initial setup.

### Telegram user authentication
This authenticates the user's Telegram account and establishes the session needed for Nuvex storage operations.

Preferred UX:

```text
Getting Started
    ↓
API ID + API Hash
    ↓
Continue with Telegram
    ↓
Telegram-supported authorization
    ↓
Authorized Nuvex session
    ↓
Initial sync
```

Prefer the cleanest official/native Telegram authorization mechanism that supports the required storage access on Android.

Do not force custom phone/OTP/2FA forms when the selected official/native flow can provide the required account authorization more directly. If the real authorization flow requires such steps, support them correctly as part of real Telegram authentication. Never fake or bypass authentication.

## 5. First-run experience

```text
Nuvex
  ↓
Getting Started
  ↓
API Credentials
  ↓
Securely save credentials
  ↓
Continue with Telegram
  ↓
Real Telegram authorization
  ↓
Secure session persistence
  ↓
Initial metadata sync
  ↓
Photos
```

Returning user:

```text
App launch
  ↓
Restore local session
  ↓
Open cached library
  ↓
Synchronize
  ↓
Update local metadata
```

## 6. Core requirements

### Authentication
- API ID input
- API Hash input
- secure credential persistence
- real Telegram user authorization
- session persistence/restoration
- logout
- session clearing
- invalid/revoked session handling

### Remote library
- read Telegram-backed files/messages used as storage source
- track stable Telegram identifiers
- paginate metadata
- deduplicate remote records
- detect additions/removals/changes

### Uploads
- choose photos/videos/documents
- durable queue
- queued/uploading/completed/failed states
- progress
- cancellation
- retry
- future-compatible pause/resume design

### Downloads
- originals only when needed
- temporary and completed files separated
- integrity verification
- retry after interruption

### Preview/cache
- thumbnail-first browsing
- bounded thumbnail cache
- asynchronous decoding
- avoid duplicate previews
- original files loaded on demand
- partial files never considered complete

## 7. Information architecture

```text
Nuvex
├── Photos
│   ├── Albums
│   ├── Recent
│   └── Viewer
├── Collections
│   ├── Documents
│   ├── Places
│   ├── Stickers
│   ├── Moments
│   ├── Screenshots
│   ├── Videos
│   ├── Recently added
│   ├── Creations
│   ├── Archive
│   └── Locked
├── Transfers
├── Telegram Account / Connection
└── Settings
```

Approved bottom navigation contains only Photos and Collections. Do not add Create or footer Search/Magic controls unless explicitly requested.

## 8. Photos requirements

Approved structure:

```text
Nuvex                    Bell   Profile
Your files, your space.

Albums                   See all
[ Together ] [ Spotlight ] [ Travel ]

Recent                   Filter/Tune

[ lazy media grid ]

Photos                   Collections
```

Do not reintroduce:
- Out of storage button
- Create button
- footer Search/Magic button

Album reference counts in mockups are visual examples only.

## 9. Collections requirements

Primary cards:
- Documents
- Places
- Stickers
- Moments

Secondary rows:
- Screenshots
- Videos
- Recently added
- Creations
- Archive
- Locked

Counts must ultimately come from local real metadata.

## 10. V1 non-goals

Do not make these prerequisites:
- WebDAV
- REST API
- broad desktop parity
- advanced archive management
- complex vault/encryption systems
- desktop integrations
- every Telegram Drive feature

V1 priority:

```text
Authentication
→ Remote metadata
→ Local database
→ Photo browsing
→ Upload/download
→ Collections
→ Viewer
→ Reliability
```

## 11. Success criteria

On a physical Android phone:

1. Nuvex installs and launches reliably.
2. API credentials can be entered and securely persisted.
3. Telegram authorization succeeds using a real supported flow.
4. Session survives app restart.
5. Nuvex fetches a page of Telegram-backed metadata.
6. Photos shows local metadata and lazy previews.
7. A remote photo opens with on-demand original retrieval.
8. A supported local file uploads.
9. Failed transfers do not corrupt completed cache data.
10. Collections open real filtered views.
11. UI matches the approved light Nuvex design.

## 12. Product principles

### Local-first
Render useful cached metadata quickly and synchronize with Telegram.

### Telegram-backed
Telegram is the remote source of truth for remotely stored data.

### Replaceable infrastructure
The Telegram implementation sits behind an application-facing abstraction.

### Real functionality
Never present mocks or fake authentication as production functionality.

### Small verified steps
Build and test incrementally on the physical Android device.
