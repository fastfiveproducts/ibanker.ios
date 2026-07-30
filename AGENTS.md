# AGENTS.md

This file provides guidance to AI tools such as Claude Code (claude.ai/code), Google Gemini CLI, OpenAI Codex CLI, and Cursor when working with code in this project.

iBanker is being rewritten in SwiftUI and adopts Fast Five Products LLC's public AGPL template for Apple development. The reference template lives at `../template/template.ios` — see [Template Relationship](#template-relationship).


## Build Command
```bash
xcodebuild build -project iBanker.xcodeproj -scheme "default" -destination 'platform=iOS Simulator,name=iPhone 17' -sdk iphonesimulator ONLY_ACTIVE_ARCH=YES -quiet
```
- The active (and only) Xcode project is `iBanker.xcodeproj` (target `iBanker`, shared scheme `default` — the FFP convention, matching the template's build command; bundle id `com.maiser.ibanker`). Passing `-project iBanker.xcodeproj` is not strictly required now that the repo has a single project, but keep it explicit for clarity.


## What This App Is

iBanker replaces paper money and the "banker" role in board games (Monopoly®, The Game of Life®, etc.). Players send money to/from "the bank" and to each other; everything persists across app launches. It is iOS-only (iPhone/iPad), SwiftUI, iOS 18+. First released on the App Store in 2016 and originally open-sourced under MIT in 2017; as of v2.0.0 it is licensed AGPL-3.0 with the Fast Five Products LLC author exception (see `LICENSE` and `LICENSE-EXCEPTIONS.md`). This branch is a SwiftUI rewrite.


## Architecture

The app is **local-only and event-sourced** — there is no backend, networking, or Firebase. State is derived by replaying a transaction log.

### The central pattern: derived game state
`GameSession` is the single source of truth — created once as a `@StateObject` in `iBankerApp` and injected everywhere as an `@EnvironmentObject`. It stores **two arrays only**:
- `players: [Player]`
- `transactions: [GameTransaction]`

Player **balances and salaries are never stored directly**. `gameSession.currentState` is computed on demand by `GameStateReducer.reduce(players:transactions:)`, which starts every player at 0 and replays each transaction's `GameAction` (`collectSalary`, `payPlayer`, `addMoney`, `subtractMoney`, `updateSalary`, `resetPlayer`, `custom`) to produce a `GameState` (dictionaries `playerBalances` and `playerSalaries`, keyed by player id).

**Consequence for any money/salary change:** append a transaction via `gameSession.perform(action, by: playerID)` — never mutate a balance directly. Views read balances through `gameSession.currentState.playerBalances[player.id]`. `PlayerView` is where all the user-facing `GameAction`s originate.

### Persistence
- `GameSession` JSON-encodes `players` and `transactions` into `@AppStorage` (UserDefaults keys `gamePlayers` / `gameTransactions`). It is saved deterministically whenever the scene leaves the foreground (`scenePhase` → `.background`/`.inactive` in `iBankerApp`, #38 — the root view's `onDisappear` remains as belt-and-braces but never fires on backgrounding) and decoded in `GameSession.init()` (direct `UserDefaults` access, to satisfy two-phase init).
- `SettingsStore` persists individual settings via `@AppStorage` (`selectedGameMode`, `customInitialBalance`, `customInitialSalary`, `soundEffects`, `enabledSpinner`).
- `GameMode` defines preset starting balances/salaries per popular game; `SettingsStore.effectiveDefaultBalance/Salary` resolve the active mode (or custom values).

### Activity Log — a derived SwiftData store
`ActivityLogView` reads `ActivityLogEntry` (a SwiftData `@Model`) via `@Query` (the container comes from the environment; the view holds no `modelContext` of its own). The log is **fed by the transaction log as a derived side effect**: every `gameSession.perform(...)` also inserts a human-readable `ActivityLogEntry` (the container is attached in `iBankerApp`; the context is handed to `GameSession` in `MainTabView`). The transaction log remains the single source of truth — the Activity Log is presentation history, never a second source of state (note: `undoLastTransaction()` does not reconcile the two stores). The Activity Log also records a few **roster events that are not backed by transactions** — player deletions append a marker via `GameSession.recordActivity` (`"<name> was deleted."` / `"All players deleted."`); these are presentation-only and do not affect derived state.

Both files are template v0.4.0 adoptions: entries are **retention-capped** (`ActivityLogEntry.trimToCap`, run from `MainTabView`'s launch `.task`, cap 1000 with a trim-marker entry), and the view is **windowed** (newest 200 with "Show Earlier" paging, bottom-anchored scrolling).

### Navigation & layers
- `MainTabView` (template-skeleton merge file) owns the `NavigationStack`, the Home / Activity / Settings tabs, the brand navigation title, the `mainToolbar` extension (Edit / Spin-to-Win / Add Player, gated on the Home tab), and the add-player/spinner sheets. Per-tab `navigationTitle`/`toolbar` preferences do NOT propagate through a `TabView` to the enclosing stack — put per-tab bar items in `mainToolbar`, not in tab content.
- `HomeView` (merge-pattern body) is the player roster: lists/edits players (delete, reorder) and shows live balances; presents `PlayerView` pushes. **Edit mode** (`@Binding editMode`) is owned by `MainTabView` (its `mainToolbar` Edit/Done button) but injected with `.environment(\.editMode, …)` at the **List level here** — injecting it on the `TabView` does not activate a tab-hosted List (#30). Swipe-to-delete is armed only in Edit mode, and a player who has exchanged money (`GameSession.hasExchangedMoney`) is locked from individual deletion (roster deletes go through `GameSession`, which keeps the transaction log and appends an Activity Log marker; **Delete All Players** in Settings additionally clears the transaction log for a fresh start).
- `PlayerView` is the per-player banking screen (collect salary, add/subtract, send to another player).
- `ViewSupport/` holds presentation config aligned with the template: `AppConfig` (merge file — brand, `dynamicSizeMax`, colors), `CustomLabeledContentStyle`, `ErrorAlertViewModifier`, plus app-owned `PlayerThumbnailView`/`CameraImagePicker`/`KeyboardActionBar` (the shared bar above the keyboard, #35/#37/#42 — carries the focused money field's action, one-tap Add/Subtract/Send with Cancel, or plain Done; a `safeAreaInset(edge: .bottom)` bar, deliberately NOT a `.toolbar(placement: .keyboard)` accessory — the v1 accessory and its in-cell placement rules were retired in #42 after device testing hit the known-broken `placement: .keyboard` plumbing (see that file's history note); screens attach `.keyboardActionBar(focus:action:)` on their Form/container, and shared child sections publish `KeyboardActionBarPreference` rendered by the host's `.keyboardActionBarHost()`) and `MoneyFormatter` (the one shared money-entry `NumberFormatter`, #37 — since #45 it renders committed values grouped with a `$` prefix, matching the money displays, and parses leniently).
- `Utilities/` — template `DebugLogging` (the `DebugPrintable` protocol's `debugprint(_:)`, release no-op, plus `deviceLog`), template `PreviewConfig` (`isPreview`), and app-owned `SoundPlayer`/`PlayerImageMaker`.


## Template Relationship

This project is a child of `../template/template.ios` (Fast Five Products LLC's public AGPL template). The app's adopted template version is recorded in root [`TEMPLATE.md`](./TEMPLATE.md) — the single source of truth (#52); check the template repo's own `TEMPLATE.md` for its current version. **Prefer taking files from the template wholesale** when adopting functionality, rather than reinventing it.

- Template source of truth: `../template/template.ios/` — read its `AGENTS.md`, `CONTRIBUTING.md`, and `README.md` for the full conventions, and its `CHANGELOG.md` (child-app impact per release) when upgrading.
- The template is a Firebase/Data Connect app; **iBanker does not (yet) use Firebase**, so the template's Cloud/CloudSupport/Repositories/ViewModels layers and account/posts/contact views are deliberately not present here. Pull in template files selectively; `../template/template.ios/tools/template-compare.sh iBanker/` (run from this repo's root — the script lives in the template repo and self-resolves its template dir) categorizes files (wholesale/merge/new/app-only).
- **Accepted divergences from the template** (recorded, not drift): folder naming (`Model/`, `ModelSupport/`, `View/`, `Store/` vs the template's `Models/`, `Views/Main|System/`, `Repositories/` — the compare script maps them via basename fallback); the app entry point (`iBankerApp` launches straight to `MainTabView` — no Firebase configure, LaunchView choreography, or overlay stack); a local `Tab` enum in `MainTabView` standing in for the template's `NavigationItem` (feature-flag driven) until cloud features are adopted; `ActivityLogView` carries no "Clear All Logs" button (#28 — the log is the game's audit trail and the retention cap bounds its size; removal proposed upstream as template.ios#167, so this divergence is expected to be temporary); app-original (`app-only`) Swift files omit the `Template vX.Y.Z` and `For licensing inquiries, contact:` header lines that template-derived files keep (see [File headers & licensing](#file-headers--licensing)).
- When copying a template file, keep its structured file header and update the "Modified by" line (see below).

### File headers & licensing
All Swift files carry an FFP AGPL header (standardized for v2.0.0). The project is licensed AGPL-3.0 with the Fast Five Products LLC author exception — see `LICENSE` and `LICENSE-EXCEPTIONS.md` (both bundled as app Resources).

**Two header shapes distinguish provenance** (an accepted divergence from the template's uniform header):
- **Template-derived files** (`wholesale`/`merge` per `template-compare.sh`) carry the **full** header, including the `Template vX.Y.Z — …` alignment line and the `For licensing inquiries, contact: …` line.
- **App-original files** (the `app-only` category — iBanker's own code with no template counterpart) **omit both** the `Template vX.Y.Z` line and the `For licensing inquiries, contact:` line. They keep the Copyright line and the AGPL + author-exception paragraphs (which still point to `LICENSE-EXCEPTIONS.md`). Deliberate: the `Template` line would misrepresent app-original code as template-derived, and dropping the contact line draws the contrast. `template-compare.sh` matches by filename (not header content), so this does not affect the sync tooling.

Use the FFP AGPL header format documented in `../template/template.ios/CONTRIBUTING.md` (this repo's human-facing digest of these conventions is [CONTRIBUTING.md](./CONTRIBUTING.md), #33), with the app-original exception above:
- **Modifying** an existing file: maintain a single `Modified by <name>, <date>` line (replace it — never stack a second). For template-derived files, add an "(updated)" suffix to the template version line; never advance the template version number itself.
- **Creating** a new file: for an **app-original** file use the lighter header (no `Template` or contact line); for a **template-derived** file start with the current template version header. Preserve the layout used across this repo's headers.

### Doc-comment standard
Symbol documentation (types, functions, properties) uses `///` (renders in Xcode Quick Help); inline explanation and section/group notes use `//` (#33). Scope: app-original files and app-authored regions of merge files. Template-owned content keeps the template's comment style until the standard is adopted upstream — don't restyle it locally.

### App-Specific MARK convention
Template "merge" files mark customizable regions with `// MARK: - App-Specific`. Content above the MARK can generally be refreshed from the template; content at/below is app-specific and must be preserved or carefully merged. Treat the MARK as a hint, and always review the full diff.


## Key Patterns

- **Status text vs alerts**: use inline `statusText` only for instant client-side validation (empty fields, mismatches); present anything the user waited on for a server/async result as an alert. (Carried over from the template; relevant as the rewrite adds validation.)
- **Single shared session**: do not create new `GameSession` instances in app code — read the injected `@EnvironmentObject`. (Previews intentionally build their own throwaway session.)


## Code Review

When asked to "do a code review", follow this process:

### Categories to Evaluate
1. **Bugs** — logic errors, copy-paste mistakes, typos
2. **Security** — auth gaps, data exposure, input validation, secrets in source control
3. **Error Handling** — unhandled throws, force unwraps, silent failures, missing edge cases
4. **Deprecated APIs**
5. **Performance** — redundant computation, missing caching, expensive operations
6. **Style** — inconsistencies with the rest of the existing codebase
7. **Licensing** — attribution, copyright headers, commercial risks

### Output Format
Present findings as a numbered table with columns: ID, Category, Priority, Summary, File(s). Use short IDs by category (B1, S1, E1, D1, P1, C1, L1). Prioritize bugs and security first.

### Cross-Referencing
Before reporting a finding, cross-reference it against existing GitHub issues (open and closed) and prior code-review dispositions; omit anything already tracked or dispositioned won't-fix unless circumstances materially changed. Focus on genuinely new findings.

### Workflow
1. Explore the repo, cross-reference, then present the filtered findings table.
2. Discuss each finding with the user — they decide fix/close/defer.
3. For each fix: edit → build → commit → push.
4. After each commit, regenerate the table with an added Status column (keep all original columns — the table must be self-contained).


## Testing
- Manual testing only (no automated test suite). Build with the command above, then run on a simulator from Xcode.
- App Store screenshots are generated, not hand-captured: `tools/generate-screenshots.sh` re-creates the committed `store-listing/screenshots/` sets end-to-end on the dedicated capture simulators (`ASC_69_iBanker` / `ASC_13_iBanker`, created on demand), seeding a demo game through the app's own persistence (`ScreenshotMode`, DEBUG-only) and validating exact accepted ASC dimensions + no alpha (#55).


## Git Workflow

iBanker follows the FFP template's git-flow model:

- **`develop`** — the default working/integration branch. All feature work branches off `develop` and squash-merges back into it.
- **`main`** — the release/production branch: a clean linear history with one commit per release (`Release vX.Y.Z`). Cut a release by squashing all of `develop` since the last release onto `main`.
- The final Objective-C release survives as the **`v1.3.0` tag** (history purged of an encumbered sound asset, #46); the former `objective-c` branch was retired at the v2.0.0 release cut and is archived privately by the owner.

The SwiftUI rewrite (issue #11, targeting v2.0.0) lives on `develop`; it is not yet released, so `main` still points at the last shipped version, v1.3.0.

**Feature flow** (off `develop`):
1. Branch from a GitHub issue: `git checkout develop` → `git pull origin develop` → `gh issue develop <issue-number> --base develop --checkout`.
2. Make changes → build → fix → user reviews/tests on a simulator.
3. On the user's request, commit and push the feature branch.
4. Open a PR targeting `develop`: `gh pr create --base develop`.
5. User squash-merges the PR on GitHub; then refresh: `git checkout develop` → `git pull origin develop`.

**Release flow** (`develop` → `main`): squash all of `develop` since the last release into a single `Release vX.Y.Z` commit on `main`. See the template's `AGENTS.md` "Release Process" for the exact steps.

- Commit/push only when the user asks.


## Common Issues
- **Using the wrong build command**: always use the command above. Agents that invent their own often name an uninstalled simulator; the build then hangs until timeout instead of failing fast.
- **Running commands in the wrong directory**: `cd` into `ibanker` before any git or build operation.
- **Chaining shell commands obscures permission mapping**: run `cd` as its own separate Bash call — never chain with `&&`, `;`, or `|`, and never use `-C`-style flags to avoid `cd`. This keeps the permission prompt mapped to the real operation.
