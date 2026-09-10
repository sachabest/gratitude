# Gratitude

A personal iPhone app for two-minute mindfulness check-ins — one right after waking, one right before bed — plus a "Reflect" mode that resurfaces a specific day from your past, morning and evening together, to revisit.

Built with SwiftUI + SwiftData, using only standard iOS components (system colors/materials, SF Symbols, the stock keyboard's dictation mic) so it looks and feels like part of the OS.

## What it does

- **Morning & Evening check-ins.** Open the app, say how much time you have (Quick / Standard / Long), and answer 2–4 short questions. Quick is multiple-choice only; Standard lets you tap a choice or type instead; Long is free text (with dictation) for a deeper reflection. Evening questions reference what you said that morning. You can optionally attach one photo from your library at the end — picking it needs no permission prompt at all (SwiftUI's `PhotosPicker` runs out-of-process and only gives the app the one photo you pick).
- **Time-windowed check-ins.** Morning and Evening only unlock during their own window (4am-11am and 8pm-2am by default, both configurable in Settings) — outside it, the card shows when it opens, or that it was missed for today. Opening the app while a window is open and that check-in isn't done yet drops you straight into it — no extra taps.
- **Day navigation & streaks.** The Home screen shows today by default, with arrows to page back through past days (never forward past today). A flame + number in the top-left shows your current streak — a day only counts once both morning and evening are done, and today stays "in progress" rather than breaking the streak while it's still underway.
- **Reflect mode.** Open any time to revisit a specific past day, spotlighted front-and-center — its morning intention and evening reflection shown together, with any photo you attached — chosen at random (favoring days where you did both) rather than always the same recent entries. Tap the reroll button for another. If that day had a person tagged on its evening check-in, a one-click "Send a smile to {name}" button resends a smile to them, reusing that day's positive answer as the message, with no composer or contact picker needed. Reflect only ever displays; it never lets you attach a photo there.
- **Local-first, encrypted-if-backed-up.** Everything lives on-device in SwiftData. An optional, off-by-default "Encrypted iCloud Backup" setting encrypts your data (AES-GCM, key in your Keychain, synced privately via iCloud Keychain) before uploading it to *your own* private CloudKit database — Apple/iCloud only ever see ciphertext.
- **Reminders.** Optional local notifications at times you set for morning and evening — no push/server involved.
- **Smiles.** During an evening check-in, optionally tag a person (contact picker, no permission prompt) and send them a smile. It always goes out as an iMessage — but the message includes a link that, if the recipient also has Gratitude installed, opens the smile right in their app's "Smiles" inbox instead of just showing as text. That's real cross-device delivery via CloudKit Sharing, not a custom server. Home has a "Smiles" card with a log of what you've sent and received, and the tagged person/phone number ride along with that check-in so Reflect can offer the one-click resend above. You can also send one anytime from the Smiles log's "+" button, not just during an evening check-in — capped at a few a week so it stays occasional, with the cap itself adjustable from the cloud without shipping an update.
- **Your data, exportable and deletable.** Settings has a plain-JSON export (share sheet) and a destructive "delete everything" option.

## Setup

1. Open `gratitude.xcodeproj` in Xcode.
2. **Signing & Capabilities** → make sure the iCloud capability's CloudKit container is provisioned under your team (Xcode will offer to auto-create it once you're signed into your Apple ID in Xcode's Settings → Accounts).
   - Note: encrypted backup and reminders don't require a paid Apple Developer account — reminders are local notifications and backup is on-demand (not push-triggered), so a free Personal Team is enough. You only need a paid account if you later add features that genuinely require Push Notifications, TestFlight, or App Store distribution.
3. Pick a Simulator or your iPhone as the run destination and build & run.
4. In the app: turn on reminders (grants notification permission) and, if you want to test backup, turn on Encrypted iCloud Backup with the Simulator/device signed into iCloud (Settings app → your name). The first backup happens automatically when you enable the toggle.
5. Smiles work without any extra setup — sending one always works as long as Messages can send texts (real device with cellular; the Simulator can't actually send). The "opens in Gratitude instead of just text" behavior additionally needs the *recipient's* device to be signed into iCloud and have Gratitude installed — genuinely testing that side needs a second device/Apple ID, which isn't something you can fully verify solo in one Simulator.

## Project layout

```
gratitude/
  Models/        SwiftData models (CheckIn, QuestionResponse, Smile) + shared enums
  QuestionBank/   Decodes Resources/questions.json into the question sets per (morning/evening) x (quick/standard/long)
  Resources/      questions.json — the actual question content, editable without touching Swift
  Services/       Notifications, encryption/Keychain, CloudKit backup, Smile sharing, photo downsizing, memory picking, streaks, dev-only sample data seeding
  Views/
    Home/         Root screen — day navigation, streak, calendar picker, morning/evening/reflect/smiles cards
    CheckIn/      The adaptive question flow (time budget → questions → summary → optional Smile)
    Reflect/      Spotlighted single-day memory (morning + evening together) + one-click smile resend
    History/      Browse/read past entries
    Settings/     Reminders, backup, export/delete, privacy note
    Smiles/       Sent/received Smile log
    Common/       Shared design tokens (Theme.swift), the chip flow-layout, and the system-picker presenters
  AppDelegate.swift   Only exists to accept incoming Smile CloudKit shares
Scripts/
  seed-simulator.sh    Installs (optionally builds) and seeds the Simulator with ~2 weeks of sample data
  reset-simulator.sh   Fully wipes the app's local Simulator data
.github/workflows/
  build.yml      CI build (Simulator, no code signing)
  test.yml       CI test run
```

See `CLAUDE.md` for the deeper architectural notes (data model quirks, the CloudKit auto-mirroring gotcha, concurrency model, etc.) if you're working on this with an AI coding assistant.

## Development scripts

Rather than manually clicking through Quick/Standard/Long check-ins a dozen times to get something to look at, seed the Simulator with realistic sample data (the last 13 days filled in with varying moods, a couple of photos, a couple of tagged evenings so Reflect's one-click smile button has something to exercise, a couple of Smiles — today is left empty so auto-launch and empty states still behave normally):

```bash
Scripts/seed-simulator.sh --build   # first time, or after a code change
Scripts/seed-simulator.sh           # after that, if you just want to reinstall + seed
Scripts/seed-simulator.sh --reset   # wipe existing local data first, then seed fresh
```

To fully wipe the app's local data (a clean install, not just a data reset):

```bash
Scripts/reset-simulator.sh
```

Both default to the "iPhone 17" simulator; pass `--simulator "iPhone 17 Pro"` (or whichever) to target a different one. This works via a `--seed-sample-data` launch argument that a `#if DEBUG`-only code path (`Services/DebugSeeding.swift`) checks for and acts on — real SwiftData writes, never compiled into a Release build.

## Continuous integration

`.github/workflows/build.yml` and `test.yml` build and test the app on GitHub's macOS runners against an iOS Simulator, with code signing disabled (not needed for Simulator builds, and the project's signing team is tied to a local Xcode account CI doesn't have). `gratitudeTests`/`gratitudeUITests` are still the unmodified Xcode template stubs — the workflows run whatever's there today and need no changes as real tests are added.

## Interactive Simulator testing (iOS Simulator MCP)

This repo is set up to use the [ios-simulator MCP](https://github.com/joshuayoes/ios-simulator-mcp) server so an AI coding assistant can drive the Simulator directly — screenshotting, tapping, typing, and swiping through flows instead of only reading code. Screenshots/install/launch work out of the box, but the interactive tools (`ui_tap`, `ui_swipe`, `ui_type`, `ui_describe_all`) require Facebook's `idb` (iOS Debug Bridge) client to be on `PATH`. `idb` itself is two pieces:

1. **`idb-companion`** (the simulator-side daemon) — installed globally via Homebrew:
   ```bash
   brew tap facebook/fb
   brew trust facebook/fb   # needed first if brew refuses the tap as "untrusted"
   brew install idb-companion
   ```
2. **`idb`** (the Python CLI client) — kept as a pinned, reproducible local install in `tools/idb/` (a small `uv` project, not part of the app) rather than installed into system Python:
   ```bash
   cd tools/idb
   uv sync                                                     # creates tools/idb/.venv from uv.lock
   ln -sf "$(pwd)/.venv/bin/idb" /opt/homebrew/bin/idb          # put idb on PATH for the MCP server
   ```

`tools/idb/.venv/` is gitignored and disposable — re-run `uv sync` any time to recreate it from `tools/idb/uv.lock`. Without `idb` on `PATH`, the MCP's interactive calls fail with `spawn idb ENOENT`.

## Privacy

Nothing leaves the device unencrypted. Backup is opt-in and off by default; when it's on, only AES-GCM ciphertext is uploaded, to your own private CloudKit database, using a key that never leaves your devices' Keychains.
