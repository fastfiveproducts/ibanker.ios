#!/bin/bash
#
#  generate-screenshots.sh — scripted ASC screenshot generation
#
#  Created by Claude, Fast Five Products LLC, on 8/11/26 (template.ios#180),
#  generalized from the recipe proven in ibanker.ios#55 and the four shipped
#  app sets (iBanker · dtrol · ff · bg).
#  Modified by Claude, Fast Five Products LLC, on 9/5/26 — re-adopted into
#  iBanker at the 2.0.2 store leg, replacing the #55 single-class original.
#
#  Copyright © 2026 Fast Five Products LLC. All rights reserved.
#
#  This file is part of a project licensed under the GNU Affero General Public
#  License v3.0. An exception applies: Fast Five Products LLC retains the right
#  to use this code and derivative works in proprietary software without being
#  subject to the AGPL terms. See the LICENSE and LICENSE-EXCEPTIONS.md files at
#  the root of the template repository (github.com/fastfiveproducts/template.ios)
#  for full terms.
#
#  For licensing inquiries, contact: licenses@fastfiveproducts.com
#
#  CONSUMER-COPYABLE: copy this file, then edit ONLY the CONFIGURE block below.
#  Everything under "--- machinery ---" is app-agnostic and should be taken
#  wholesale, so fixes and gotchas flow to every app from one place.
#
#  ⚠️ iBanker's ONE machinery divergence, marked at its site below: the
#  template.ios#268 windowed-apps guard (two `defaults write` lines after boot).
#  It is filed upstream and unlanded at 0.5.1 — retire this patch, do not
#  re-apply it, at the first reconcile that brings the machinery's own copy.
#
#  Regenerates the App Store screenshot sets end-to-end from a clean simulator
#  state:
#    1. Builds the app once (Debug, generic simulator destination).
#    2. Compiles the dimension/alpha validator, and runs prepare_seed() if the
#       app defines one.
#    3. Per device class: creates the dedicated capture simulator if missing,
#       ERASES it, boots, forces light appearance, overrides the status bar
#       (9:41, full bars/battery), installs the app, takes one throwaway
#       warm-up launch to absorb first-boot system banners, then per shot
#       calls seed_for_shot() and launches with <LAUNCH_ARG> <screen> before
#       capturing via simctl io screenshot — skipping any screen listed in
#       that class's *_SKIP_SCREENS (#253).
#    4. Validates every capture: EXACT accepted ASC pixel dimensions, no alpha.
#
#  Usage: tools/generate-screenshots.sh [iphone|ipad|all]   (default: all)
#
#  Requires: Xcode command-line tools (xcrun/xcodebuild/simctl) and python3
#  (used only to parse `simctl list devices -j`).
#
#  Shell note for anyone editing the machinery (macOS bash 3.2, set -euo
#  pipefail): the `set -e` masking rule is narrower than folklore says.
#  `local u="$(cmd)"` DOES swallow cmd's failure — the `local` builtin's own
#  exit status is what gets tested — but `local u; u="$(cmd)"` does NOT.
#  This file always declares first and assigns second.
#
#  ⚠️ VALIDATION PROVES DIMENSIONS AND ALPHA — NEVER CONTENT.  A run once
#  produced a full set that was entirely the app's "loading data…" overlay and
#  passed every check.  ALWAYS OPEN THE IMAGES before shipping them, and
#  `shasum -a 256` the output directory: two different shots must never produce
#  the same file.  Both checks, every run — they catch different failures.  If a
#  screen shows a spinner or empty state, raise that shot's settle override
#  (third SHOTS field) — see the Screenshots section in AGENTS.md.
#
#  ⚠️ THIS SCRIPT OVERWRITES A COMMITTED DIRECTORY.  It deletes and rewrites
#  every PNG in the output set, and captures are not byte-stable run to run, so
#  a run made only to PROVE THE TOOLING leaves a diff that means nothing.  End
#  such a run with `git restore store-listing/screenshots/` and commit only a
#  deliberate refresh.  ⚠️ And do not use `git status` on the output dir as a
#  change oracle for anything else afterwards; it is noise by construction.
#

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"

# ===========================================================================
#  CONFIGURE — the only app-specific part of this file
# ===========================================================================

PROJECT="$REPO/iBanker.xcodeproj"
SCHEME="default"
APP_NAME="iBanker.app"
BUNDLE="com.maiser.ibanker"
RUNTIME="com.apple.CoreSimulator.SimRuntime.iOS-26-5"

# The launch argument ScreenshotMode reads (see Utilities/ScreenshotMode.swift).
# ⚠️ Must stay IDENTICAL to ScreenshotMode.launchArgument: a mismatch disables
# every hook and still captures and validates cleanly.
LAUNCH_ARG="-ibScreenshotScreen"

# Per-repo capture simulators — never the unit-test simulator (iPhone_17_iBanker),
# never the tablet walk simulator (iPad_13_iBanker), and never a stock shared
# device (parallel sessions in other repos collide on those).
IPHONE_SIM="ASC_69_iBanker"
IPAD_SIM="ASC_13_iBanker"

# Screens to SKIP for one device class, space-separated, matched whole-word
# against the same screen value as SHOTS below (#253).
#
# iPad skips `player`: at the tier the roster shot IS the split, so it already
# shows the banking form beside the roster — and the standalone push renders the
# same form capped at 600 pt on a 1032 pt canvas, which reads as a phone screen
# on an iPad. Judged from the captures at the 2.0.2 store leg (the images, not
# the theory); delete the value and re-run `ipad` to bring the shot back.
IPHONE_SKIP_SCREENS=""
IPAD_SKIP_SCREENS="player"

# Default seconds to wait after launch before capturing.
SETTLE_SECONDS="${SCREENSHOT_SETTLE:-6}"

# Seconds to hold the throwaway warm-up launch (see the machinery below).
WARMUP_SECONDS="${SCREENSHOT_WARMUP:-12}"

# Shot list: <output name> <screen value> [settle override]
#
# The screen value is matched by MainTabView's launch .task, which selects the
# tab, arms the player push, or presents the spinner sheet (iBanker has no
# NavigationItem rawValue route — see ScreenshotMode.swift).  The list mirrors
# the ibanker.android generated set, shot for shot.
SHOTS=(
    "01-players-roster roster"
    "02-player-banking player"
    "03-activity-log activity"
    "04-settings settings"
    "05-spin-to-win spinner"
)

# Optional hook — one-time setup before any capture.  iBanker is the
# persistence-seeded route: compile the seed generator against the app's OWN
# model sources, so the JSON the app decodes is correct by construction.
prepare_seed() {
    log "compiling seed generator"
    xcrun swiftc -O -o "$WORK/seedgen" \
        "$REPO/iBanker/Model/Player.swift" \
        "$REPO/iBanker/Model/GameAction.swift" \
        "$REPO/iBanker/Model/GameTransaction.swift" \
        "$REPO/tools/make-screenshot-seed.swift"

    local seed_output
    seed_output="$("$WORK/seedgen")" || { echo "FAILED: seed generation (see stderr above)" >&2; exit 1; }
    # Sets GAMEPLAYERS_HEX / GAMETRANSACTIONS_HEX for seed_for_shot below.
    eval "$seed_output"
    [ -n "${GAMEPLAYERS_HEX:-}" ] || { echo "FAILED: seed generation produced no GAMEPLAYERS_HEX" >&2; exit 1; }
    [ -n "${GAMETRANSACTIONS_HEX:-}" ] || { echo "FAILED: seed generation produced no GAMETRANSACTIONS_HEX" >&2; exit 1; }
}

# Optional hook — runs before each launch, with the booted simulator and the
# shot about to be taken.  Writes the demo game through the app's own
# persistence keys (GameSession's @AppStorage / SettingsStore), so the app
# decodes real state rather than anything capture-specific.
#   $1 = simulator udid   $2 = output name   $3 = screen value
seed_for_shot() {
    local udid="$1" screen="$3" spinner
    # The Spin-to-Win entry point is settings-gated, so the spinner shot needs
    # it on and the others read better with it off (this was the third SHOTS
    # field in iBanker's pre-adoption script; the machinery's third field is a
    # settle override, so the state moved here where it belongs).
    if [ "$screen" = "spinner" ]; then spinner=true; else spinner=false; fi

    xcrun simctl spawn "$udid" defaults write "$BUNDLE" gamePlayers -data "$GAMEPLAYERS_HEX"
    xcrun simctl spawn "$udid" defaults write "$BUNDLE" gameTransactions -data "$GAMETRANSACTIONS_HEX"
    xcrun simctl spawn "$udid" defaults write "$BUNDLE" soundEffects -bool true
    xcrun simctl spawn "$udid" defaults write "$BUNDLE" selectedGameMode -string '$1500 Balance'
    xcrun simctl spawn "$udid" defaults write "$BUNDLE" enabledSpinner -bool "$spinner"
}

# ===========================================================================
#  --- machinery — app-agnostic below this line ---
# ===========================================================================

OUT="$REPO/store-listing/screenshots"
# Workdir name derives from APP_NAME (the CONFIGURE field) rather than a hardcoded
# "template-" prefix: everything below `--- machinery ---` is taken wholesale,
# so a literal would name every consumer's temp dir after the template (#209).
WORK_SLUG="$(printf '%s' "${APP_NAME%.app}" | tr -c '[:alnum:]' '-')"
WORK="${SCREENSHOT_WORKDIR:-$(mktemp -d "${TMPDIR:-/tmp}/${WORK_SLUG}-screenshots.XXXXXX")}"

# Anything between `boot` and `shutdown` can fail (or be Ctrl-C'd) and would
# otherwise leave the capture simulator booted, with the app installed and a
# 9:41 status-bar override pinned for the rest of the boot session.  One trap
# owns both that and the temp workdir.
BOOTED_UDID=""
on_exit() {
    local rc=$?
    if [ -n "$BOOTED_UDID" ]; then
        xcrun simctl shutdown "$BOOTED_UDID" >/dev/null 2>&1 || true
    fi
    # Temp workdir is removed on SUCCESS only — a failed run keeps it for
    # inspection.  A SCREENSHOT_WORKDIR override is user-managed, never removed.
    if [ "$rc" -eq 0 ] && [ -z "${SCREENSHOT_WORKDIR:-}" ] && [ -n "$WORK" ]; then
        rm -rf "$WORK"
    fi
    return $rc
}
trap on_exit EXIT

# Device classes: ASC accepts these exact pixel sizes.  iPad only applies if the
# app actually runs on iPad — an iPhone-only app should pass "iphone".
IPHONE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max"
IPHONE_DIR="iphone-6.9"
IPHONE_DIMS="1320x2868"

IPAD_TYPE="com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB"
IPAD_DIR="ipad-13"
IPAD_DIMS="2064x2752"

log() { echo "[screenshots] $*"; }

# --- 1. Build (once) -------------------------------------------------------
log "building (Debug, generic iOS Simulator) into $WORK/dd"
xcodebuild build \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination 'generic/platform=iOS Simulator' \
    -sdk iphonesimulator \
    -derivedDataPath "$WORK/dd" \
    ONLY_ACTIVE_ARCH=YES -quiet
APP="$WORK/dd/Build/Products/Debug-iphonesimulator/$APP_NAME"
[ -d "$APP" ] || { echo "FAILED: app not found at $APP" >&2; exit 1; }

# --- 2. Tools --------------------------------------------------------------
log "compiling validator"
xcrun swiftc -O -o "$WORK/validate" "$REPO/tools/validate-screenshots.swift"

prepare_seed

# --- 3. Capture ------------------------------------------------------------
sim_udid() { # <name> <devicetype> — create if missing, echo UDID
    local name="$1" devicetype="$2" udid status
    # Distinguish "no such device" from "the lookup itself failed".  Swallowing
    # both (a bare `|| true`) means a missing python3, a simctl hiccup, or a
    # JSON shape change all read as "not found" — and then the create branch
    # mints ANOTHER simulator with the same name on every run.  simctl allows
    # duplicate names, so that leak is unbounded and silent.
    set +e
    udid="$(xcrun simctl list devices -j | python3 -c '
import json, sys
name = sys.argv[1]
for devices in json.load(sys.stdin)["devices"].values():
    for device in devices:
        if device["name"] == name and device.get("isAvailable", False):
            print(device["udid"]); sys.exit(0)
sys.exit(9)   # 9 = looked, definitively absent
' "$name")"
    status=$?
    set -e
    if [ "$status" -ne 0 ] && [ "$status" -ne 9 ]; then
        echo "FAILED: simulator lookup for '$name' errored (exit $status). Is python3 on PATH? Try: xcrun simctl list devices" >&2
        exit 1
    fi
    if [ -z "$udid" ]; then
        log "creating simulator $name" >&2
        # Explicit check rather than relying on set -e: this yields an
        # actionable message instead of dying two steps later on a misleading
        # 'Invalid device:'.  Most likely cause: the pinned runtime is no
        # longer installed.
        if ! udid="$(xcrun simctl create "$name" "$devicetype" "$RUNTIME")"; then
            echo "FAILED: simctl create $name ($devicetype) — install the pinned runtime or update RUNTIME in this script (RUNTIME=$RUNTIME)" >&2
            exit 1
        fi
    fi
    echo "$udid"
}

shot_is_skipped() { # <skip-list> <screen>
    # Whole-word match: the padding on BOTH sides is what stops a list of "home"
    # swallowing "home_detail".  ⚠️ The emptiness test is not an optimization —
    # without it an empty list (" ") matches an empty screen value (" "), so a
    # malformed SHOTS row would be silently skipped and then blamed on a skip
    # list that is empty.  The list is matched LITERALLY; there are no wildcards.
    [ -n "$1" ] || return 1
    [[ " $1 " == *" $2 "* ]]
}

capture_device() { # <sim name> <devicetype> <outdir> <dims> [skip-screens]
    # The 5th parameter is OPTIONAL and defaulted (#253): a child app that took
    # this machinery before the skip existed calls with four arguments and is
    # completely unaffected.  Keep it that way.
    local name="$1" devicetype="$2" outdir="$3" dims="$4" skip_screens="${5:-}" udid
    # Guard the empty case explicitly: under `set -u`, bash 3.2 expands an empty
    # array's "${A[@]}" to an "unbound variable" error, which reads as a script
    # bug rather than "you commented out all your shots".
    if [ "${#SHOTS[@]}" -eq 0 ]; then
        echo "FAILED: SHOTS is empty — nothing to capture (see the CONFIGURE block)" >&2
        exit 1
    fi
    # Every-shot-skipped is a configuration mistake, and it must be caught
    # BEFORE the destructive steps below — the same fail-first shape as the
    # empty-SHOTS guard above.  By the time the capture loop could notice, this
    # function has already deleted the existing set and erased the simulator, so
    # a child app with committed screenshots would lose them to a typo.
    local planned=0 planned_entry planned_shot planned_screen
    for planned_entry in "${SHOTS[@]}"; do
        read -r planned_shot planned_screen _ <<< "$planned_entry"
        shot_is_skipped "$skip_screens" "$planned_screen" && continue
        planned=$((planned + 1))
    done
    if [ "$planned" -eq 0 ]; then
        echo "FAILED: every shot is skipped for $outdir — check this class's skip list (${skip_screens:-<empty>}) against the screen values in SHOTS" >&2
        exit 1
    fi

    udid="$(sim_udid "$name" "$devicetype")"
    log "=== $name ($udid) -> $outdir ($dims) ==="
    mkdir -p "$OUT/$outdir"
    # Clean state applies to the output dir too: a renamed or dropped shot must
    # not survive as a stale PNG that validation would silently bless.
    rm -f "$OUT/$outdir"/*.png

    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
    # ⚠️ Apps whose content needs Firebase App Check: the DEBUG token is
    # registered per SIMULATOR, and erasing drops it.  Data Connect then fails
    # `unauthenticated` and the app sits on "Loading…" — captured as a set that
    # passes validation.  Such an app must skip this erase and manage clean
    # state another way.  (iBanker is local-only: nothing to lose, always erase.)
    log "erasing (clean-state acceptance)"
    xcrun simctl erase "$udid"
    BOOTED_UDID="$udid"   # from here on, the exit trap owns shutting it down
    xcrun simctl boot "$udid"
    xcrun simctl bootstatus "$udid" >/dev/null
    # ⚠️ iBanker DIVERGENCE from the machinery — template.ios#268, OPEN at 0.5.1.
    # iPadOS 26's windowed-apps mode captures the app as a floating window on the
    # desktop wallpaper: right dimensions, no alpha, distinct hashes, exit 0, and
    # unusable — and the narrowed window drops the app BELOW the 840 tier, so an
    # iPad set renders the phone-shaped layout and reads as a layout bug that does
    # not exist.  It is per-simulator state; an erase is believed to reset it, but
    # believing that is what template.ios#256 cost.  Two writes make the question
    # moot (verified on bg.ios#146's leg).  RETIRE this block — do not re-apply it
    # — at the first reconcile whose machinery carries #268's own copy.
    xcrun simctl spawn "$udid" defaults write com.apple.springboard SBChamoisWindowingEnabled -bool false
    xcrun simctl spawn "$udid" defaults write com.apple.springboard SBMedusaMultitaskingEnabled -bool false
    xcrun simctl ui "$udid" appearance light
    xcrun simctl status_bar "$udid" override \
        --time "9:41" \
        --dataNetwork wifi --wifiMode active --wifiBars 3 \
        --cellularMode active --cellularBars 4 \
        --batteryState discharging --batteryLevel 100
    xcrun simctl install "$udid" "$APP"

    # Warm-up launch, then discard it.  A freshly-erased simulator fires a
    # one-time first-boot system notification ("Ready for Apple Intelligence"
    # and friends) that can land ON TOP of a captured shot — and a banner does
    # not change dimensions or alpha, so validation blesses it.  Spending one
    # throwaway launch here absorbs it before any real capture.
    log "warm-up launch (absorbing first-boot system banners)"
    xcrun simctl launch "$udid" "$BUNDLE" >/dev/null
    sleep "$WARMUP_SECONDS"
    xcrun simctl terminate "$udid" "$BUNDLE" >/dev/null 2>&1 || true

    local entry shot screen settle
    for entry in "${SHOTS[@]}"; do
        # third field optional — default settle when omitted
        read -r shot screen settle <<< "$entry"
        if shot_is_skipped "$skip_screens" "$screen"; then
            log "skip $shot (screen=$screen) — not in the $outdir set"
            continue
        fi
        [ -n "${settle:-}" ] || settle="$SETTLE_SECONDS"
        log "shot $shot (screen=$screen settle=${settle}s)"
        xcrun simctl terminate "$udid" "$BUNDLE" >/dev/null 2>&1 || true
        seed_for_shot "$udid" "$shot" "$screen"
        xcrun simctl launch "$udid" "$BUNDLE" "$LAUNCH_ARG" "$screen" >/dev/null
        sleep "$settle"
        xcrun simctl io "$udid" screenshot --type=png "$OUT/$outdir/$shot.png" >/dev/null
    done

    xcrun simctl shutdown "$udid"
    BOOTED_UDID=""        # cleanly down — nothing for the trap to do

    # --- 4. Validate -------------------------------------------------------
    log "validating $outdir against $dims (+ no alpha)"
    "$WORK/validate" "$dims" "$OUT/$outdir"/*.png
}

TARGET="${1:-all}"
case "$TARGET" in
# ⚠️ The skip lists are defaulted HERE, not just in CONFIGURE.  This block is
# below the machinery marker and is taken wholesale, so it must not require a
# CONFIGURE variable that an older copy does not define — under `set -u` that is
# an "unbound variable" death at the very end of a long run.  A child can take
# the new machinery and add the CONFIGURE lines later, or never.
    iphone) capture_device "$IPHONE_SIM" "$IPHONE_TYPE" "$IPHONE_DIR" "$IPHONE_DIMS" "${IPHONE_SKIP_SCREENS:-}" ;;
    ipad)   capture_device "$IPAD_SIM" "$IPAD_TYPE" "$IPAD_DIR" "$IPAD_DIMS" "${IPAD_SKIP_SCREENS:-}" ;;
    all)
        capture_device "$IPHONE_SIM" "$IPHONE_TYPE" "$IPHONE_DIR" "$IPHONE_DIMS" "${IPHONE_SKIP_SCREENS:-}"
        # ⚠️ simctl status_bar sets the TIME but not the iPad status-bar DATE,
        # which follows the simulator clock — so a set shot across two days
        # shows two different dates.  Shoot a full set in ONE run.
        capture_device "$IPAD_SIM" "$IPAD_TYPE" "$IPAD_DIR" "$IPAD_DIMS" "${IPAD_SKIP_SCREENS:-}"
        ;;
    *) echo "usage: $0 [iphone|ipad|all]" >&2; exit 2 ;;
esac

# Simulator shutdown and temp-workdir removal are handled by the EXIT trap.

log "done — sets in $OUT"
log "NOW OPEN THEM: validation cannot tell a real screen from a loading overlay."
