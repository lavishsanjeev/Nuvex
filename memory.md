# Nuvex — Project Memory

Version: 2.0
Date: 2026-09-11

## 1. Identity

Package/project:
`nuvex`

Display:
`Nuvex`

Platform:
Android first

Framework:
Flutter

Primary development:
physical Android phone over USB

Emulator:
not required

## 2. Product reason

Nuvex is an Android-first mobile alternative inspired by the useful storage behavior of Telegram Drive.

It is not a desktop clone.

It should feel like a polished personal gallery/file workspace powered by the user's Telegram account.

## 3. Reference product

Telegram Drive:
https://github.com/caamer20/Telegram-Drive

Use as behavior/architecture reference only.

Important concepts learned from it:
- Telegram-backed storage
- transfer queues
- thumbnail/preview caching
- local indexing
- file browsing
- advanced features that should come later

## 4. Visual history

Earlier dark/blue-heavy design was rejected.

Approved:
- white/light
- minimal
- clean
- modern
- restrained blue
- rounded cards
- subtle borders/shadows

## 5. Navigation decisions

Bottom navigation:
- Photos
- Collections

Explicitly removed:
- Out of storage button
- Create button
- footer Search/Magic button

Do not reintroduce these without an explicit change.

## 6. Photos

```text
Nuvex                   Bell  Profile
Your files, your space.
Albums                  See all
Together / Spotlight / Travel
Recent                  Filter/Tune
Media grid
Photos                  Collections
```

Mock counts from reference designs are not real data.

## 7. Collections

Cards:
- Documents
- Places
- Stickers
- Moments

Rows:
- Screenshots
- Videos
- Recently added
- Creations
- Archive
- Locked

Counts must eventually be database-derived.

## 8. Authentication decisions

Setup content:

1. Go to my.telegram.org.
2. Create a Telegram application.
3. Copy API ID and API Hash.
4. Store credentials securely.
5. Continue with Telegram.
6. Complete real Telegram authorization.
7. Persist the authorized session.

Critical distinction:

API ID + API Hash
≠
Telegram user authorization/session.

Do not claim the user is authenticated merely because app credentials were saved.

Preferred UX:
- use the cleanest supported official/native Telegram authorization mechanism
- only use phone/code/2FA interaction where the actual Telegram flow requires it

## 9. Architecture

```text
Flutter UI
    ↓
Controllers / Services
    ↓
Repositories
    ├── Local DB/cache
    └── Telegram storage client
              ↓
           Telegram
```

UI must never directly call Telegram methods.

Telegram implementation is replaceable.

## 10. Local-first memory

- local DB = materialized index/cache
- Telegram = remote source of truth
- cached UI first
- incremental sync
- originals lazy-loaded
- thumbnails separate
- bounded cache
- deduplicate Telegram identities
- persist transfer states
- never publish partial downloads

## 11. New project restart

The previous project became too error-prone.

This is a clean restart.

Do not carry accidental implementation complexity into the new project.

Carry forward only:
- product requirements
- confirmed design decisions
- architecture principles
- environment knowledge
- lessons learned

The six new documentation files are the source of truth for the clean project.

## 12. New project state

Known previous environment:
- Flutter stable 3.47.3
- Android SDK 37.0.0
- physical Android device over USB
- Flutter previously launched on the device

The new project must be independently verified.

## 13. Priority

```text
clean project
→ theme/navigation
→ credentials setup
→ real Telegram authorization
→ session persistence
→ remote metadata proof
→ local DB
→ thumbnails
→ transfers
→ Photos
→ Collections
→ viewers
→ reliability
```

## 14. Working style

Build one small verified task at a time.

Inspect before modifying.

Avoid giant files.

Avoid unnecessary dependencies.

Do not fake backend functionality.

Run analyzer and physical-device tests regularly.

## 15. Documentation contract

Every future coding AI must read:

- prd.md
- architecture.md
- rules.md
- phases.md
- design.md
- memory.md

before substantial work.

## 16. Critical checkpoint

Before broad product expansion, prove:

```text
Telegram client
→ real authorization
→ session persistence
→ session restore
→ read remote files
→ upload test file
→ download test file
```

Only then scale the rest of Nuvex.
