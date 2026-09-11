#!/usr/bin/env bash
set -euo pipefail

# Seeds the local Simulator install of Gratitude with ~2 weeks of realistic
# sample data (varying moods, a couple of photos, a couple of Thank Yous) for
# interactive UI testing. Today itself is left untouched so auto-launch and
# the empty "not completed" state can still be exercised manually.
#
# This works by launching the app with a launch argument that a DEBUG-only
# code path (Services/DebugSeeding.swift) checks for and acts on - real
# SwiftData writes through the normal model layer, not a raw SQLite hack.
#
# Usage:
#   Scripts/seed-simulator.sh                        # seed (adds to whatever's already there)
#   Scripts/seed-simulator.sh --reset                 # wipe local app data first, then seed
#   Scripts/seed-simulator.sh --build                 # xcodebuild first, then install + seed
#   Scripts/seed-simulator.sh --simulator "iPhone 17 Pro"

cd "$(dirname "$0")/.."

SIMULATOR_NAME="iPhone 17"
DO_BUILD=0
DO_RESET=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build) DO_BUILD=1; shift ;;
    --reset) DO_RESET=1; shift ;;
    --simulator) SIMULATOR_NAME="$2"; shift 2 ;;
    -h|--help)
      grep '^#' "$0" | cut -c3-
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

BUNDLE_ID="com.sachabest.gratitude"

UDID=$(xcrun simctl list devices available | grep -F "$SIMULATOR_NAME (" | head -1 | grep -oE '[0-9A-F-]{36}')
if [[ -z "$UDID" ]]; then
  echo "Could not find an available simulator named $SIMULATOR_NAME. Available devices:" >&2
  xcrun simctl list devices available >&2
  exit 1
fi

if ! xcrun simctl list devices | grep -q "$UDID.*Booted"; then
  echo "Booting $SIMULATOR_NAME ($UDID)"
  xcrun simctl boot "$UDID"
  sleep 3
fi

if [[ "$DO_BUILD" -eq 1 ]]; then
  echo "Building"
  xcodebuild \
    -project gratitude.xcodeproj \
    -scheme gratitude \
    -destination "platform=iOS Simulator,id=$UDID" \
    build
fi

APP_PATH=$(find "$HOME/Library/Developer/Xcode/DerivedData" -type d -name "gratitude.app" -path "*Debug-iphonesimulator*" -not -path "*/Index.noindex/*" -print -quit)
if [[ -z "$APP_PATH" ]]; then
  echo "Could not find a built gratitude.app in DerivedData - run with --build first." >&2
  exit 1
fi

echo "Installing $APP_PATH"
xcrun simctl install "$UDID" "$APP_PATH"

ARGS=(--seed-sample-data)
if [[ "$DO_RESET" -eq 1 ]]; then
  ARGS+=(--reset-data)
  echo "Launching (resetting existing data first, then seeding)"
else
  echo "Launching (seeding)"
fi

xcrun simctl launch "$UDID" "$BUNDLE_ID" "${ARGS[@]}"

echo "Done. Sample data covers the last 13 days; today is left empty."
