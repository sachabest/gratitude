#!/usr/bin/env bash
set -euo pipefail

# Fully wipes Gratitude's local data on the Simulator by uninstalling the app
# (SwiftData store, Keychain items, everything) - a clean slate, distinct
# from `seed-simulator.sh --reset`, which only clears app-level data in place
# and immediately reseeds it.
#
# Usage: Scripts/reset-simulator.sh [--simulator "iPhone 17"]

SIMULATOR_NAME="iPhone 17"

while [[ $# -gt 0 ]]; do
  case "$1" in
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
  echo "Could not find an available simulator named $SIMULATOR_NAME." >&2
  exit 1
fi

echo "Uninstalling $BUNDLE_ID from $SIMULATOR_NAME ($UDID)"
xcrun simctl uninstall "$UDID" "$BUNDLE_ID" || true
echo "Done - local data wiped. Install and relaunch to start fresh."
