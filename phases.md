# Nuvex — Development Phases

Version: 2.0
Date: 2026-09-11

## Phase 0 — Environment baseline
Status: Complete from previous setup, but must be independently verified in the new project.

Known:
- Flutter stable 3.47.3
- Android SDK 37.0.0
- physical Android device over USB
- emulator not required

Exit:
- new project launches on physical device

## Phase 1 — Clean project baseline

- create fresh Flutter project
- package `nuvex`
- display name `Nuvex`
- establish app/theme/router foundations
- add documentation
- remove starter/demo code
- verify analyzer
- verify physical-device launch

Exit:
- clean starter app, no legacy/demo UI

## Phase 2 — Nuvex design system and navigation

- light theme
- typography
- spacing
- components
- Photos shell
- Collections shell
- two-item bottom navigation
- responsive phone layouts

Exit:
- Photos/Collections work visually on physical device

## Phase 3 — Telegram credentials and authorization

- API ID
- API Hash
- secure persistence
- Getting Started
- my.telegram.org external link
- Continue with Telegram entry point
- verify Telegram authorization implementation
- Telegram abstraction
- real account authorization
- session persistence/restoration
- logout/revocation handling

Preferred UX:

```text
API credentials
     ↓
Continue with Telegram
     ↓
official/verified Telegram authorization
```

If the selected real flow requires phone/code/2FA, implement those correctly.

Exit:

```text
first run → authorize → persist → restart → restore
```

on physical Android.

## Phase 4 — Telegram remote storage proof

- access intended Telegram storage source
- read one page of files/messages
- normalize metadata
- stable identifiers
- upload small test file
- download test file
- verify files

Exit:

```text
authorize → list → upload → download
```

works.

## Phase 5 — Local database and synchronization

- choose one DB
- RemoteFile
- Collection
- TransferTask
- repositories
- pagination
- deduplication
- incremental sync
- sync coordinator
- cached startup

Exit:
- cached library survives restart and refreshes from Telegram

## Phase 6 — Real Photos

- real metadata
- lazy grid
- thumbnail cache
- async decode
- loading/error/empty
- recent
- album data
- viewer entry
- on-demand original

Exit:
- large media library browses without downloading all originals

## Phase 7 — Transfer manager

- picker/gallery selection
- durable upload/download queue
- progress
- cancel
- retry
- persisted state
- temporary files
- integrity checks

Exit:
- selected file reliably transfers both ways

## Phase 8 — Collections

- Documents
- Places
- Stickers
- Moments
- Screenshots
- Videos
- Recently added
- Creations
- Archive
- Locked

Build classifier, queries and real counts.

Exit:
- every collection opens a real filtered dataset

## Phase 9 — Albums

- Together
- Spotlight
- Travel
- Favorites
- selection mode
- useful sorting/filtering

Exit:
- Photos feels like a gallery

## Phase 10 — Viewers/media

- photo viewer
- video viewer
- document/PDF viewer
- richer previews
- original download integration

Exit:
- common supported media types open reliably

## Phase 11 — Reliability

- expired sessions
- network interruption
- retry policy
- transfer recovery
- cache pruning
- duplicate prevention
- corrupted transfer handling
- startup sync correctness

Exit:
- core storage loop survives realistic failures

## Phase 12 — Background transfers

Only after foreground transfers are reliable.

- Android background strategy
- real-device testing
- notifications/progress if appropriate
- process-restart recovery

## Phase 13 — Advanced features

Only after MVP is stable.

Potential:
- richer sharing
- advanced security
- vault/locked data improvements
- archive features
- other Telegram Drive-inspired capabilities

Do not make these V1 blockers.

## Phase rule

Never skip a phase's exit criteria to start a later phase.
