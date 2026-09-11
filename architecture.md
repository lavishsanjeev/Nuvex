# Nuvex — Technical Architecture

Version: 2.0
Date: 2026-09-11

## 1. Architecture overview

```text
┌────────────────────────────────────────────┐
│                 Flutter UI                 │
│ Auth • Photos • Collections • Viewer       │
└──────────────────────┬─────────────────────┘
                       │
┌──────────────────────▼─────────────────────┐
│ Controllers / Application Services         │
│ auth • sync • photos • transfers            │
└───────────────┬─────────────────┬──────────┘
                │                 │
      ┌─────────▼────────┐  ┌────▼───────────────┐
      │ Local Repository │  │ Telegram Repository│
      │ DB + cache       │  │ API/MTProto        │
      └─────────┬────────┘  └────┬───────────────┘
                │                 │
        ┌───────▼────────┐       │
        │ Local Database │       ▼
        │ + File Cache   │   Telegram
        └────────────────┘
```

UI must not call Telegram API methods directly.

## 2. Flutter project structure

```text
lib/
├── main.dart
├── app/
│   ├── app.dart
│   ├── router.dart
│   └── theme.dart
├── core/
│   ├── errors/
│   ├── logging/
│   ├── database/
│   ├── storage/
│   ├── security/
│   └── network/
├── telegram/
│   ├── telegram_client.dart
│   ├── telegram_auth.dart
│   ├── telegram_session.dart
│   ├── telegram_messages.dart
│   ├── telegram_media.dart
│   ├── telegram_upload.dart
│   ├── telegram_download.dart
│   └── telegram_models.dart
├── features/
│   ├── auth/
│   ├── photos/
│   ├── collections/
│   ├── viewer/
│   ├── transfers/
│   ├── settings/
│   └── account/
└── shared/
    ├── models/
    ├── widgets/
    └── utils/
```

Adapt to the actual project rather than forcing destructive restructures.

## 3. Telegram boundary

The rest of Nuvex must not depend directly on one Telegram package.

Conceptually:

```dart
abstract class TelegramStorageClient {
  Future<AuthState> restoreSession();
  Future<AuthState> beginAuthorization();
  Future<void> submitAuthorizationStep(AuthorizationInput input);

  Stream<RemoteFile> listFiles({int? offsetId});

  Future<UploadResult> uploadFile(
    LocalFile file,
    void Function(double progress) onProgress,
  );

  Future<FilePath> downloadFile(
    RemoteFile file,
    void Function(double progress) onProgress,
  );

  Future<void> logout();
}
```

The exact API may evolve after the Telegram implementation is verified.

## 4. Authentication architecture

Separate:

```text
App credentials
API ID + API Hash
```

from:

```text
User authorization/session
Telegram account identity + authorized session
```

Flow:

```text
Credentials UI
     ↓
Secure credential storage
     ↓
Telegram authentication service
     ↓
Official/native/verified authorization mechanism
     ↓
Authorized session
     ↓
Secure session persistence
```

If the selected Telegram implementation requires phone number, code or 2FA, those belong to the authentication service and its real authorization flow.

## 5. Secure storage

Sensitive data includes:
- API Hash
- authorization/session material
- authentication state
- other Telegram secrets

Use platform secure storage. Never store sensitive data in source code, normal JSON, logs, Git or unencrypted files.

Use a dedicated abstraction such as:

```dart
abstract class SecureStore {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
}
```

## 6. Local models

Use one primary local database technology.

RemoteFile:

```text
id
telegramChatId
telegramMessageId
telegramFileId
name
mimeType
sizeBytes
createdAt
modifiedAt
thumbnailPath
localPath
remoteAvailable
isFavorite
isArchived
isLocked
latitude
longitude
durationMs
width
height
checksumOrIntegrityInfo
```

Collection:

```text
id
name
type
coverFileId
createdAt
updatedAt
```

TransferTask:

```text
id
kind
remoteFileId
localPath
targetPath
state
progress
bytesTransferred
totalBytes
attemptCount
lastErrorCode
lastErrorMessage
createdAt
updatedAt
```

## 7. Local-first sync

```text
App starts
   ↓
Open local DB
   ↓
Render cached metadata
   ↓
Sync coordinator
   ↓
Fetch paginated remote metadata
   ↓
Normalize
   ↓
Deduplicate
   ↓
Upsert
   ↓
Update affected UI
```

Do not run overlapping initial sync operations.

## 8. Cache separation

```text
Database metadata
≠
Thumbnail cache
≠
Temporary transfer files
≠
User-visible originals
```

Original lifecycle:

```text
Remote
  ↓
temporary download
  ↓
integrity verification
  ↓
published local file
```

Partial/failed transfers must never be exposed as completed files.

## 9. Photos flow

```text
PhotosPage
   ↓
PhotosController
   ↓
LocalFileRepository
   ↓
Database
   ↓
Lazy grid
   ↓
ThumbnailCache
   ↓
Image tile
```

Tap:

```text
Image tile
   ↓
ViewerController
   ↓
Original cached?
 ├─ yes → open
 └─ no  → transfer manager → verify → open
```

## 10. Collections flow

```text
RemoteFile metadata
      ↓
Classification service
      ↓
Documents / Places / Stickers / ...
      ↓
Collection query
      ↓
Collections UI
```

Classification must stay outside widgets.

## 11. Transfer manager

```text
TransferManager
├── enqueue()
├── pause()
├── resume()
├── cancel()
├── retry()
└── stream state changes
```

States:

```text
queued
active
paused
completed
failed
cancelled
```

Persist queue state when recovery is needed.

## 12. Error model

Possible domain failures:

```text
AuthFailure
NetworkFailure
RateLimitFailure
PermissionFailure
InvalidSessionFailure
FileNotFoundFailure
IntegrityFailure
StorageFailure
UnsupportedMediaFailure
```

UI receives user-readable messages.

Never log credentials, OTPs, passwords or session secrets.

## 13. Performance

- paginate remote metadata
- lazy build grids/lists
- decode media asynchronously
- avoid loading all originals
- separate thumbnail cache
- avoid duplicate preview requests
- deduplicate stable remote identities
- minimize unnecessary rebuilds

## 14. Background work

First make foreground transfers reliable.

Background transfer is a separate subsystem requiring real-device testing against Android constraints.

## 15. Technical checkpoint

Before broad UI/backend investment, prove:

```text
Flutter Android
   ↓
Telegram client
   ↓
Real authorization
   ↓
Session persistence
   ↓
Session restoration
   ↓
Read remote files/messages
   ↓
Upload test file
   ↓
Download test file
```
