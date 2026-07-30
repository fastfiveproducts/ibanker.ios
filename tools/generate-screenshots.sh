#!/bin/bash
#
#  generate-screenshots.sh — scripted ASC screenshot generation (#55)
#
#  Created by Claude, Fast Five Products LLC, on 7/30/26.
#
#  Copyright © 2026 Fast Five Products LLC. All rights reserved.
#
#  This file is part of a project licensed under the GNU Affero General Public
#  License v3.0. See the LICENSE file at the root of this repository for full
#  terms. An exception applies: Fast Five Products LLC retains the right to use
#  this code and derivative works in proprietary software without being subject
#  to the AGPL terms. See LICENSE-EXCEPTIONS.md for details.
#
#  Regenerates the committed App Store screenshot sets end-to-end from a clean
#  simulator state:
#
#    1. Builds the app once (Debug, generic simulator destination).
#    2. Compiles the seed generator (with the app's own model sources — JSON
#       format fidelity by construction) and the dimension/alpha validator.
#    3. Per device class: creates the dedicated capture simulator if missing,
#       ERASES it, boots, forces light appearance, overrides the status bar
#       (9:41, full bars/battery), installs the app, then per shot seeds the
#       demo game through the app's own persistence (simctl spawn defaults
#       write of gamePlayers/gameTransactions/settings) and launches with
#       -ibScreenshotScreen <screen> (see ScreenshotMode.swift) before
#       capturing via simctl io screenshot.
#    4. Validates every capture: EXACT accepted ASC pixel dimensions and no
#       alpha channel (flattening in place if the capture carried one).
#
#  Usage: tools/generate-screenshots.sh [iphone|ipad|all]   (default: all)
#
#  Output: store-listing/screenshots/iphone-6.9/  (1320x2868, iPhone 17 Pro Max)
#          store-listing/screenshots/ipad-13/     (2064x2752, iPad Pro 13-inch M5)
#

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE="com.maiser.ibanker"
RUNTIME="com.apple.CoreSimulator.SimRuntime.iOS-26-5"
OUT="$REPO/store-listing/screenshots"
WORK="${IB_SCREENSHOT_WORKDIR:-$(mktemp -d "${TMPDIR:-/tmp}/ibanker-screenshots.XXXXXX")}"
SETTLE_SECONDS="${IB_SCREENSHOT_SETTLE:-6}"

# Device classes: name | device type | output dir | expected pixels (portrait)
IPHONE_SIM="ASC_69_iBanker"
IPHONE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max"
IPHONE_DIR="iphone-6.9"
IPHONE_DIMS="1320x2868"

IPAD_SIM="ASC_13_iBanker"
IPAD_TYPE="com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB"
IPAD_DIR="ipad-13"
IPAD_DIMS="2064x2752"

# Shot list (mirrors the ibanker.android generated sets):
#   <output name> <-ibScreenshotScreen value> <enabledSpinner for the shot>
SHOTS=(
    "01-players-roster roster false"
    "02-player-banking player false"
    "03-activity-log activity false"
    "04-settings settings false"
    "05-spin-to-win spinner true"
)

log() { echo "[screenshots] $*"; }

# --- 1. Build (once) -------------------------------------------------------
log "building (Debug, generic iOS Simulator) into $WORK/dd"
xcodebuild build \
    -project "$REPO/iBanker.xcodeproj" \
    -scheme "default" \
    -destination 'generic/platform=iOS Simulator' \
    -sdk iphonesimulator \
    -derivedDataPath "$WORK/dd" \
    ONLY_ACTIVE_ARCH=YES -quiet
APP="$WORK/dd/Build/Products/Debug-iphonesimulator/iBanker.app"
[ -d "$APP" ] || { echo "app not found at $APP" >&2; exit 1; }

# --- 2. Tools --------------------------------------------------------------
log "compiling seed generator + validator"
xcrun swiftc -O -o "$WORK/seedgen" \
    "$REPO/iBanker/Model/Player.swift" \
    "$REPO/iBanker/Model/GameAction.swift" \
    "$REPO/iBanker/Model/GameTransaction.swift" \
    "$REPO/tools/make-screenshot-seed.swift"
xcrun swiftc -O -o "$WORK/validate" "$REPO/tools/validate-screenshots.swift"

seed_output="$("$WORK/seedgen")" || { echo "FAILED: seed generation (see stderr above)" >&2; exit 1; }
eval "$seed_output"
[ -n "${GAMEPLAYERS_HEX:-}" ] || { echo "FAILED: seed generation produced no GAMEPLAYERS_HEX" >&2; exit 1; }
[ -n "${GAMETRANSACTIONS_HEX:-}" ] || { echo "FAILED: seed generation produced no GAMETRANSACTIONS_HEX" >&2; exit 1; }

# --- 3. Capture ------------------------------------------------------------
sim_udid() { # <name> <devicetype> — create if missing, echo UDID
    local name="$1" devicetype="$2" udid
    udid="$(xcrun simctl list devices -j | python3 -c '
import json, sys
name = sys.argv[1]
for devices in json.load(sys.stdin)["devices"].values():
    for device in devices:
        if device["name"] == name and device.get("isAvailable", False):
            print(device["udid"]); sys.exit(0)
' "$name" || true)"
    if [ -z "$udid" ]; then
        log "creating simulator $name" >&2
        # Explicit check: a failed create inside $() does not trip set -e in
        # the caller, and an empty UDID would die two steps later on a
        # misleading 'Invalid device:' error. Most likely cause: the pinned
        # runtime is no longer installed.
        if ! udid="$(xcrun simctl create "$name" "$devicetype" "$RUNTIME")"; then
            echo "FAILED: simctl create $name ($devicetype) — install the pinned runtime or update RUNTIME in this script (RUNTIME=$RUNTIME)" >&2
            exit 1
        fi
    fi
    echo "$udid"
}

capture_device() { # <sim name> <devicetype> <outdir> <dims>
    local name="$1" devicetype="$2" outdir="$3" dims="$4" udid
    udid="$(sim_udid "$name" "$devicetype")"
    log "=== $name ($udid) -> $outdir ($dims) ==="
    mkdir -p "$OUT/$outdir"
    # Clean-state applies to the output dir too: a renamed/dropped shot must
    # not survive as a stale PNG that validation would silently bless.
    rm -f "$OUT/$outdir"/*.png

    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
    log "erasing (clean-state acceptance)"
    xcrun simctl erase "$udid"
    xcrun simctl boot "$udid"
    xcrun simctl bootstatus "$udid" >/dev/null
    xcrun simctl ui "$udid" appearance light
    xcrun simctl status_bar "$udid" override \
        --time "9:41" \
        --dataNetwork wifi --wifiMode active --wifiBars 3 \
        --cellularMode active --cellularBars 4 \
        --batteryState discharging --batteryLevel 100
    xcrun simctl install "$udid" "$APP"

    local entry shot screen spinner
    for entry in "${SHOTS[@]}"; do
        read -r shot screen spinner <<< "$entry"
        log "shot $shot (screen=$screen spinner=$spinner)"
        xcrun simctl terminate "$udid" "$BUNDLE" >/dev/null 2>&1 || true
        xcrun simctl spawn "$udid" defaults write "$BUNDLE" gamePlayers -data "$GAMEPLAYERS_HEX"
        xcrun simctl spawn "$udid" defaults write "$BUNDLE" gameTransactions -data "$GAMETRANSACTIONS_HEX"
        xcrun simctl spawn "$udid" defaults write "$BUNDLE" soundEffects -bool true
        xcrun simctl spawn "$udid" defaults write "$BUNDLE" selectedGameMode -string '$1500 Balance'
        xcrun simctl spawn "$udid" defaults write "$BUNDLE" enabledSpinner -bool "$spinner"
        xcrun simctl launch "$udid" "$BUNDLE" -ibScreenshotScreen "$screen" >/dev/null
        sleep "$SETTLE_SECONDS"
        xcrun simctl io "$udid" screenshot --type=png "$OUT/$outdir/$shot.png" >/dev/null
    done

    xcrun simctl shutdown "$udid"

    # --- 4. Validate -------------------------------------------------------
    log "validating $outdir against $dims (+ no alpha)"
    "$WORK/validate" "$dims" "$OUT/$outdir"/*.png
}

TARGET="${1:-all}"
case "$TARGET" in
    iphone) capture_device "$IPHONE_SIM" "$IPHONE_TYPE" "$IPHONE_DIR" "$IPHONE_DIMS" ;;
    ipad)   capture_device "$IPAD_SIM" "$IPAD_TYPE" "$IPAD_DIR" "$IPAD_DIMS" ;;
    all)
        capture_device "$IPHONE_SIM" "$IPHONE_TYPE" "$IPHONE_DIR" "$IPHONE_DIMS"
        capture_device "$IPAD_SIM" "$IPAD_TYPE" "$IPAD_DIR" "$IPAD_DIMS"
        ;;
    *) echo "usage: $0 [iphone|ipad|all]" >&2; exit 2 ;;
esac

# Default temp workdir is removed on success only — a failed run exits above
# (set -e) and keeps it for inspection. An IB_SCREENSHOT_WORKDIR override is
# user-managed and never removed.
if [ -z "${IB_SCREENSHOT_WORKDIR:-}" ] && [ -n "$WORK" ]; then
    rm -rf "$WORK"
fi

log "done — sets in $OUT"
