# Nuvex — Design System and UI Specification

Version: 2.0
Date: 2026-09-11

## 1. Brand

Display: Nuvex
Package: nuvex

Personality:
- clean
- trustworthy
- modern
- minimal
- personal
- storage-focused

## 2. Visual direction

Final approved direction:

- bright white background
- near-white surfaces
- pale gray/blue secondary surfaces
- dark navy/near-black text
- restrained blue accent
- rounded cards
- subtle borders/shadows
- modern sans-serif typography
- generous spacing
- clean Android layouts

Reject:
- dark/blue-heavy UI
- neon-heavy colors
- excessive glassmorphism
- decorative clutter
- dense desktop-style layouts

## 3. Typography

Use a modern sans-serif with consistent hierarchy:

- screen title: large/strong
- section title: bold/compact
- body: regular/readable
- metadata: smaller/muted
- action text: medium/semibold

Centralize typography tokens.

## 4. Color system

Centralize semantic tokens:

```text
background
surface
surfaceVariant
primaryText
secondaryText
divider
primaryAccent
error
```

Blue is the primary interaction accent.

Do not scatter arbitrary raw colors across features.

## 5. Cards and spacing

Use large rounded cards with consistent radii, subtle borders and restrained shadow.

Use generous spacing and avoid cramped compositions.

## 6. Getting Started

```text
Back

Nuvex

Getting Started

Short explanation

┌──────────────────────────┐
│ Step 1                   │
│ Go to my.telegram.org    │
└──────────────────────────┘

┌──────────────────────────┐
│ Step 2                   │
│ Create application       │
└──────────────────────────┘

┌──────────────────────────┐
│ Step 3                   │
│ Copy API ID + Hash       │
└──────────────────────────┘

Privacy / local security card

[ Open my.telegram.org ]
```

Keep it white, calm and minimal.

## 7. Credentials

Approved concept:

```text
Nuvex

Welcome to
Nuvex login now!

App ID
[             ]

App Hash
[             ]

[ Login ]

How do I get my API credentials?
```

Requirements:
- clear labels
- rounded inputs
- appropriate keyboard
- secure hash entry
- obvious action
- validation/loading/error states
- no credential exposure

After credentials are stored, the real account-authentication entry point should be:

Continue with Telegram

Do not display authenticated status until real authorization succeeds.

## 8. Photos

```text
Nuvex                         Bell  Profile

Your files, your space.

Albums                         See all

[ Together ] [ Spotlight ] [ Travel ]

Recent                         Filter/Tune

[ media grid ]

Photos                         Collections
```

No:
- Out of storage
- Create
- footer Search/Magic

## 9. Collections

```text
Collections

┌─────────────┐ ┌─────────────┐
│ Documents   │ │ Places      │
└─────────────┘ └─────────────┘

┌─────────────┐ ┌─────────────┐
│ Stickers    │ │ Moments     │
└─────────────┘ └─────────────┘

Screenshots             >
Videos                   >
Recently added           >
Creations                >
Archive                  >
Locked                   >

Photos       Collections
```

Counts are database-derived once data exists.

## 10. Icons

Use simple outline/rounded icons with consistent weight.

## 11. Interactions

Actionable controls need:
- clear tap target
- pressed state
- disabled state when relevant
- loading state when asynchronous
- useful errors

## 12. Responsiveness

Support different Android phone widths/aspect ratios.

Use SafeArea, flexible constraints, scrolling and adaptive grids where needed.

Do not design around one exact screenshot size.

## 13. Media

Photos:
- thumbnail first
- full-screen viewer
- original on demand

Videos:
- clear visual indication
- duration when known

Documents:
- file icon/preview

Never preload all originals.

## 14. Empty/loading/error states

Each data page needs intentional states.

Loading:
- subtle progress
- concise context

Empty:
- useful explanation
- relevant next action

Error:
- human-readable reason
- retry

Offline:
- make cached-data availability clear

## 15. Principle

Polish must support usability.

Nuvex intentionally removes unnecessary controls.
