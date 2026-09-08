# Releasing iBanker for iOS to the App Store — runbook

Adopted from `template.ios` v0.5.0 (template.ios#196) at the 2.0.2 store leg, and tailored
to iBanker. The listing copy lives beside this file in
[`store-listing/app-store-listing.md`](./store-listing/app-store-listing.md) — that file is
the "what to paste", this one is the "how". (Android analog: `ibanker.android`'s
`RELEASE.md`.)

**§8 of the template's runbook — App Check / Firebase attestation — is deleted here:
iBanker is local-only.** No backend, no accounts, no networking, no Firebase. Sections
after it are renumbered, so this file ends at §9.

**Owner-only acts** (agents hard-stop here): uploading a build, submitting for review, and
releasing. Items marked **⟨OWNER-CONFIRM⟩** are compliance/brand decisions the owner
verifies before submission. ⚠️ Those markers belong to the PROCESS side — the listing doc
deliberately carries none in its content (template.ios#270).

**Process rule (fleet):** create the working branch FIRST, before any release-prep edits —
release-prep changes on `develop` had to be moved to a branch retroactively at the fleet's
first store leg.

---

## 0. Where things stand

- **Account:** Apple Developer Program membership under **Fast Five Products LLC**
  (`DEVELOPMENT_TEAM = 9NMRZ5DQQ6`).
- **Build:** bundle ID `com.maiser.ibanker` — **permanent**; it anchors App Store identity,
  so never change it (the historical `com.maiser.*` form is deliberate and stays).
  App Store ID **1132712489**. `MARKETING_VERSION` is **2.0.2** in the project, bumped at
  release prep on 2026-09-05 — before the archive, and before the screenshot capture,
  because the Settings screen's identity footer renders the version into the store shots.
  Build number (`CURRENT_PROJECT_VERSION`): reset to 1 at each marketing version — it is
  **1** for 2.0.2, and a re-upload of the SAME version needs a higher build (§9).
- **App architecture:** local-only and event-sourced. State lives in `UserDefaults` and a
  local SwiftData log; nothing leaves the device. No backend, no accounts, no data
  collection — which is why §8 is deleted and why §4's standing answer is what it is.
- **Devices:** `TARGETED_DEVICE_FAMILY = "1,2"` — iPhone and iPad, minimum iOS 18.0. Since
  2.0.2 the iPhone is **Portrait-only** while iPad keeps all four orientations, declared in
  the checked-in `iBanker/Info.plist` (the ONLY orientation source of truth — the
  `INFOPLIST_KEY_*` build settings are inert in this target shape, #39). Verify posture on
  the BUILT product, never in the project file.
- **Live:** **v2.0.1** on the App Store since 2026-08-08, with its `Release v2.0.1` marker
  cut on `main` (`176951a`). First released 2016-07-10, so the 10th-anniversary framing in
  the listing copy is current. 2.0.2 is a real submission, not a marker-only release.

---

## 1. Signing

There is no upload-keystore analog on iOS: the fleet uses **Xcode automatic signing**, and
v2.0.0/v2.0.1 shipped on it. Distribution certificates and profiles are Xcode-managed;
uploads need nothing beyond the machine's Xcode being signed into the team (no manually
created distribution certificate, no profile management, no ASC API key).

⚠️ **iBanker's project predates the template's signing block, so do not read the template's
"ships pre-wired, nothing to verify" assurance onto it.** Verified in
`iBanker.xcodeproj/project.pbxproj` at the 2.0.2 leg: `DEVELOPMENT_TEAM = 9NMRZ5DQQ6` is
set at the project level, but `CODE_SIGN_STYLE = Automatic` is declared **only on the
`iBankerTests` configurations** — the `iBanker` app target, the one that actually archives,
declares no `CODE_SIGN_STYLE` at all and still carries the legacy
`CODE_SIGN_IDENTITY = "iPhone Developer"` with an empty `PROVISIONING_PROFILE`. It archives
correctly on Xcode's implicit default (proven again this leg: a headless
`CODE_SIGNING_ALLOWED=NO` archive builds clean), which is why this has never bitten. Confirm
the app target's Signing & Capabilities tab reads "Automatically manage signing" before the
first upload of a release ⟨OWNER-CONFIRM⟩. (`dtrol.ios` carries the identical shape and the
identical note — it is a fleet-wide inheritance, not an iBanker mistake.)

---

## 2. Archive, verify, upload

Pre-flight (agent-doable; each item links its own doc rather than restating it):

- Build AND `xcodebuild test` green per [`AGENTS.md`](./AGENTS.md) — the unit suite is a
  merge gate, and a store build is not exempt. iBanker's gate simulator is
  `iPhone_17_iBanker`.
- **`PrivacyInfo.xcprivacy` present in the BUILT app** — App Store Connect rejects uploads
  whose binaries use required-reason APIs without a manifest (**ITMS-91053**).
  `iBanker/PrivacyInfo.xcprivacy` declares `NSPrivacyTracking = false`, an **empty**
  `NSPrivacyCollectedDataTypes`, and one accessed-API entry (UserDefaults, reason
  `CA92.1`) — the honest answer for a local-only app. ⚠️ The manifest carries no comment
  block explaining itself, so this paragraph is the record: keep it truthful, and re-audit
  it if data practices ever change. Confirm the file is IN the archive
  (`<archive>/Products/Applications/iBanker.app/PrivacyInfo.xcprivacy`), not merely in the
  repo.
- **Export compliance is pre-answered**: `ITSAppUsesNonExemptEncryption = false` lives in
  `iBanker/Info.plist` (⚠️ not in the build settings, where the template puts it), and it
  is present in the built product — so ASC does not ask at submission.
- **DEBUG-only scaffolding provably stripped.** iBanker's screenshot hooks are
  `Utilities/ScreenshotMode.swift` plus `#if DEBUG` branches in `MainTabView` and
  `HomeView`. Prove it: headless archive, then `strings` the **RELEASE** binary —

  ```bash
  xcodebuild archive -project iBanker.xcodeproj -scheme "default" -configuration Release \
      -destination 'generic/platform=iOS' -archivePath <tmp>/iBanker.xcarchive \
      CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
  strings -a <tmp>/iBanker.xcarchive/Products/Applications/iBanker.app/iBanker | grep -c <term>
  ```

  `ibScreenshotScreen`, `ScreenshotMode` and `seedActivityLogFromTransactions` must each
  return **0**; the control `No players added` must HIT. ⚠️ **Run the control first** — a
  Debug binary is a stub whose code lives in `__preview.dylib`, so grepping it is a false
  pass for every string. ⚠️ **And pick a control of at least 16 bytes**: Swift stores
  literals of ≤15 UTF-8 bytes inline as small strings, so `Select a player` (15) greps 0
  in a perfectly good binary — a trap that costs a double-take every time (found 2026-09-05).
- **Aggregated privacy report** (Xcode Organizer, generated from the archive) reviewed
  before upload — it must agree with the manifest.

Then (owner): **Xcode archive → Organizer → Validate App → Distribute/upload.**

- **Upload ≠ submission.** An uploaded build sits in ASC until it is attached to a version
  and submitted.
- **Listing metadata stays editable in ASC between upload and submission.** Keep
  `store-listing/app-store-listing.md` the source of truth: if ASC is edited directly,
  re-sync the doc in the same pass.

---

## 3. App Store Connect — the app record (owner)

1. The iBanker app record already exists (id **1132712489**; v2.0.1 live), so record
   creation does not recur.
2. ⚠️ **The App Name localizes per storefront.** iBanker has been bitten by this: the
   rename to "iBanker Calculator" once went live on the **US storefront only** while
   CA/GB/AU/DE/SG kept serving "iBanker". The current name — "iBanker for Board Games" —
   was applied at 2.0.1 and is confirmed live; iBanker ships in **29** storefronts, so any
   future rename is a 29-storefront check, not one.
3. **TestFlight is standard fleet practice — a must-do, not an option**: install the
   uploaded build via TestFlight and device-verify before submitting. This slots naturally
   into §2's upload ≠ submission gap. For 2.0.2 the device pass that matters is the
   **iPad**: the two-pane split, and rotation on a tier-crossing iPad (mini / 11″ cross the
   840 pt tier between portrait and landscape; 13″ never does).

---

## 4. App Privacy questionnaire — the THIRD hand-maintained surface

**ASC's App Privacy answers are a separate, hand-maintained surface** — distinct from BOTH
`PrivacyInfo.xcprivacy` (the manifest in the binary) and the listing doc — **and Apple
cross-checks them against the manifest.** Keep all three in agreement, in both directions:

- A data type the app STOPS collecting must be **unticked in ASC** too — retiring it in
  code and the manifest is not enough.
- A data type the app STARTS collecting updates the manifest AND these answers before the
  next upload.

iBanker's standing answer is **Data Not Collected** ⟨OWNER-CONFIRM at every submission that
changes data practices⟩. ⚠️ The one place that answer invites a second look is the player
photo: iBanker declares `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription`, and
a chosen photo is stored with the player. It never leaves the device — no backend exists to
send it to — so "not collected" is correct as Apple defines collection. The Availability
rationale in the listing doc rests on the same fact, so if #9 (multi-device sync) or any
networking feature ever lands, this answer, the manifest, the listing copy and the
availability footprint all move together.

---

## 5. Age rating

Set via the ASC questionnaire on the app record. iBanker is rated **4+** (live): no
user-generated content, no accounts, no messaging, no gambling — the money is play money
⟨OWNER-CONFIRM per submission⟩.

---

## 6. Store listing + What's New

**All listing copy & values** — name, subtitle, promotional text, description, What's New,
categories, keywords, the three URLs, availability, copyright — live in
[`store-listing/app-store-listing.md`](./store-listing/app-store-listing.md). Paste from
the doc; never compose in ASC. Every copy field there is a fenced **PASTE-READY** block:
plain text, unwrapped, no Markdown.

- **The three URL fields are one convention with a direction** — Support →
  `https://ibanker.fastfiveproducts.com/support/` · Marketing →
  `https://ibanker.fastfiveproducts.com/` · Privacy →
  `https://ibanker.fastfiveproducts.com/privacy/` — and Support/Privacy mirror
  `AppConfig.supportURL` / `AppConfig.privacyURL`. **Paste the canonical trailing-slash
  form** (AGENTS.md → URL Form, template.ios#222): the slashless form costs a 301 that a
  console validator may not follow. ⚠️ **At the 2.0.2 submission both sides flip
  together** — the app constants moved on the 2.0.2 branch, so the ASC Support and Privacy
  fields must be re-pasted in the same pass; a one-sided flip is what this rule exists to
  prevent.
- **What's New is per-release copy, AUTHORED AT RELEASE PREP, not at paste time**
  (template.ios#270): it is written into the listing doc when `develop` is readied, the
  prior release's notes drop to an HTML comment, and the whole doc gets a material-drift
  scan whose findings are called out in the release-prep handoff. This step only pastes.
- ⚠️ **2.0.2 carries a correction beyond What's New**: the live description shipped with
  five literal `**…**` headings. The doc's block is fixed — **re-paste the Description**
  even though its words are otherwise unchanged.
- **Availability**: iBanker is a **recorded deviation** from the fleet-standard six
  English-first markets — 29 storefronts, with the rationale and the revisit trigger in the
  listing doc's Availability section. A deliberate variant, not drift to clean up.

---

## 7. Screenshots

Generated by script, committed under `store-listing/`, refreshed per release. The tooling,
the exact ASC specs, the capture-sim rules and the gotchas live in
`tools/generate-screenshots.sh` and [`AGENTS.md`](./AGENTS.md) → Screenshots — none of it is
restated here. iBanker captures on `ASC_69_iBanker` (iPhone 17 Pro Max, 1320×2868) and
`ASC_13_iBanker` (iPad Pro 13-inch M5, 2064×2752), seeding the demo game through the app's
own persistence via `tools/make-screenshot-seed.swift`.

Current sets: **5 iPhone shots, 4 iPad** (the iPad set skips the standalone player push —
its roster shot is the two-pane split and already shows the banking screen).

Two rules worth repeating, because validation proves dimensions and alpha but never
CONTENT: **`shasum -a 256` the output directory — two different shots must never produce
the same file — and open every image before uploading.** Both, every run. The committed set
is also what the Android lander verifies cross-store content parity against.

---

## 8. Submit → accepted → cut the release marker

1. **Submit for review** (owner): attach the uploaded build to the version and answer the
   submission questions. Export compliance is pre-answered (§2), so ASC does not ask.
   Provide App Review contact info. No demo account is needed — iBanker has no accounts,
   and every feature is reachable on a fresh install.
2. **On acceptance — the fleet's marker ↔ store convention**: cut the develop→main
   **`Release vX.Y.Z` marker at the ACCEPTED build** — cutting at submission risks a re-cut
   if Apple rejects.

   **The marker recipe is NOT restated here — follow the canonical copy** in the template's
   `AGENTS.md` → Release Process (develop to main): a single-path **tree-set** (clean-tree
   porcelain gate → sync `main` to the published tip → `read-tree` → commit → push →
   verify). ⚠️ `git merge --squash` is **not** part of the release process; the two-path
   form was retired fleet-wide on 2026-08-24. If you find it in an inherited doc, it is
   stale.
3. **Release** (owner): fleet practice is to **release immediately on acceptance**; phased
   release is an ASC option the fleet does not use.
4. **Close the milestone** once the marker verifies — a manual step this round.

---

## 9. Version & build policy (future releases)

- `MARKETING_VERSION` tracks the app's marketing version — fleet convention: lockstep with
  `ibanker.android`'s `versionName` where one exists (the Android 2.0.1 skip is clean by
  design; both platforms ship 2.0.2). Settle the label **before** building a store artifact.
- Bump it in the APP target's Debug and Release configs only — the `iBankerTests` target
  keeps its own `MARKETING_VERSION = 1.0`, which is not the product version. Verify with
  `grep -n MARKETING_VERSION iBanker.xcodeproj/project.pbxproj`: the release version twice,
  `1.0` twice.
- Build number (`CURRENT_PROJECT_VERSION`): **reset to 1 at each new marketing version**;
  if the SAME version needs another upload, bump the build first — ASC rejects a repeated
  build number for the same version.
