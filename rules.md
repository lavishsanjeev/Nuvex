# Nuvex — Engineering Rules

Version: 2.0
Date: 2026-09-11

## 1. Naming

- Package/project: `nuvex`
- User-facing name: `Nuvex`
- Dart files: `snake_case.dart`
- Classes/types: `PascalCase`
- Variables/functions: `camelCase`

## 2. Platform

- Android first.
- Physical Android phone over USB is the standard development target.
- Emulator is not required.
- No Windows-specific product requirements just because the reference project is desktop-oriented.

## 3. Telegram security

- Obtain credentials through official Telegram developer tooling.
- Never commit API Hash or session material.
- Never log OTP codes, 2FA passwords or authorization/session secrets.
- Respect Telegram terms, limits and authorization behavior.
- Verify the selected Telegram client on Android before deep dependence.
- Prefer official/native/verified authorization UX.
- API credentials saved ≠ Telegram account authenticated.

## 4. Architecture

- UI never calls Telegram RPC/API directly.
- Remote operations go through Telegram abstraction/repository layers.
- Persistent metadata goes through local repository/database layers.
- Keep domain logic out of widgets.
- Use one transfer manager.
- Persist transfer state when recovery matters.

## 5. Local-first

- Render cached metadata without unnecessary network blocking.
- Sync remote state into the local materialized index.
- Lazy-load originals.
- Cache thumbnails separately.
- Bound/prune caches.
- Never publish partial downloads as completed files.
- Deduplicate stable Telegram identities.

## 6. Performance

- Lazy lists/grids.
- Paginated remote metadata.
- Async media decoding.
- Avoid duplicate in-flight previews.
- Avoid all-original memory loading.
- Avoid rebuilding the whole library for one progress update.

## 7. UI

Approved:
- white / near-white background
- light gray/blue surfaces
- dark navy/near-black text
- restrained blue accent
- large rounded cards
- subtle borders/shadows
- modern sans-serif typography
- generous spacing
- simple outline icons

Do not reintroduce:
- Out of storage button
- Create button
- footer Search/Magic button

Bottom navigation contains only Photos and Collections.

## 8. Photos

```text
Nuvex             Bell  Profile
Your files, your space.
Albums            See all
Together / Spotlight / Travel
Recent            Filter/Tune
Lazy media grid
Photos            Collections
```

Keep Recent focused on media.

## 9. Collections

Primary:
- Documents
- Places
- Stickers
- Moments

Secondary:
- Screenshots
- Videos
- Recently added
- Creations
- Archive
- Locked

## 10. Code quality

- Prefer small focused classes.
- Avoid giant files/widgets.
- Avoid unrelated refactors.
- Do not copy large blocks of reference code.
- Add dependencies only with a reason.
- Run `flutter format`.
- Run `flutter analyze`.
- Run on physical Android after meaningful changes.

## 11. Testing

For important features test:
1. success
2. invalid input
3. network interruption
4. retry
5. app restart
6. empty state
7. expired/revoked authentication
8. slow/large content where relevant

## 12. Git

Use small meaningful commits such as:

```text
feat: add Telegram authorization entry
feat: persist secure credentials
feat: add remote file pagination
feat: add thumbnail cache
feat: add transfer manager
fix: prevent partial downloads from publishing
ui: refine collections cards
```

Never commit credentials, session files, OTPs, passwords, machine-specific paths or debug dumps.

## 13. Definition of done

A change is done only when:
- formatted
- analyzer checked
- failure cases handled
- physical Android device verified where relevant
- secrets protected
- architecture preserved
- acceptance criteria met

## 14. AI coding workflow

For each task:
1. Read all six project documents.
2. Inspect current repository.
3. Identify relevant files.
4. Implement only requested scope.
5. Format.
6. Analyze.
7. Run on device when relevant.
8. Report exact result.
9. Do not claim unverified success.

Never automatically implement future phases.
