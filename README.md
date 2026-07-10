# NoteStalgia — iOS

A person-centred music-reminiscence and sensory-calm POC for UK care homes, built in SwiftUI for
iPad (also runs on iPhone with proportional scaling). Formerly "Mellority Flow"; renamed to
**NoteStalgia** ("Sound that takes you back").

> Android sibling: `../NoteStalgia-Android` (Kotlin + Jetpack Compose, Galaxy Tab optimised).

## Flow

Supervisor sign-in (org-scoped, 6-digit PIN) → home picker → welcome → **curated roster** (pinned /
recent / due / wing / search) → person-centred resident profile → session hand-off → resident calm
surface (nebula orb, instrument-glyph genre picker, mood-matched visuals, comfort feedback) →
sequential post-session observations → auto-generated insight saved to the record. Multi-home leads
also get a **Home Admin insights dashboard** (KPIs, calm/wellbeing trends, wing breakdown,
highlights, attention list). New residents can be onboarded via **discovery calibration**.

Everything is in-memory and on-device (mocked tenancy, roster, and analytics).

## Build

Project is generated with [XcodeGen](https://github.com/yonyz/XcodeGen) from `project.yml`.

```bash
xcodegen generate            # produces NoteStalgia-iOS.xcodeproj
open NoteStalgia-iOS.xcodeproj
# or from CLI:
xcodebuild -project NoteStalgia-iOS.xcodeproj -scheme NoteStalgia-iOS \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build
```

- Bundle id: `com.notestalgia.ios` · Display name: **NoteStalgia** · Deployment target: iOS 17.
- Source lives in `App/`, `Core/`, `Flow/`, `Screens/`; docs in `docs/`.

## Demo credentials

- `max@sunrise-care.co.uk` · PIN `123456` — single-home supervisor.
- `alex@sunrise-care.co.uk` · PIN `123456` — multi-home lead (admin insights dashboard).

## Docs

See `docs/IMPLEMENTATION_PLAN.md` (production architecture, PII/GDPR strategy, analytics pipeline)
and `docs/NoteStalgia-PitchDeck.md`.
