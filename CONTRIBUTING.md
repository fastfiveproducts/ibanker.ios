# Contributing to iBanker

iBanker is a Fast Five Products LLC (FFP) app, developed in the open. This
file is the short human-facing digest of the project's conventions; the
complete, authoritative version — including architecture notes and
agent-facing rules — lives in [AGENTS.md](./AGENTS.md).

## Licensing

The project is licensed AGPL-3.0 with an FFP author exception — see
[LICENSE](./LICENSE) and [LICENSE-EXCEPTIONS.md](./LICENSE-EXCEPTIONS.md).
By contributing, you agree your contribution is licensed the same way.
For licensing inquiries: licenses@fastfiveproducts.com.

## Building

```bash
xcodebuild build -project iBanker.xcodeproj -scheme "default" -destination 'platform=iOS Simulator,name=iPhone_17_iBanker' -sdk iphonesimulator ONLY_ACTIVE_ARCH=YES -quiet
```

The shared scheme is `default` (the FFP convention). iOS 18+, SwiftUI,
no backend.

## Testing

`xcodebuild build` does NOT run tests, so the merge gate is a separate step:

```bash
xcodebuild test -project iBanker.xcodeproj -scheme "default" -destination 'platform=iOS Simulator,name=iPhone_17_iBanker'
```

`iBankerTests` is a Swift Testing suite (#51) reverse-ported from the
ibanker.android suites — reducer replay, GameSession guards/side-effects/
roster/persistence, event-log JSON serialization, and SettingsStore coupling.
A red suite blocks a commit like a compile error (see AGENTS.md → Testing).
Beyond the suite, still verify UI/behavior on a simulator.

## Git workflow

- `develop` — the default working branch; all feature work branches off it
  (usually from a GitHub issue) and squash-merges back via PR.
- `main` — the release branch: one `Release vX.Y.Z` commit per release.
- The final Objective-C release is preserved as the `v1.3.0` tag.

## File headers

Every Swift file carries the FFP AGPL header. Two shapes distinguish
provenance:

- **Template-derived files** (adopted from FFP's `template.ios` template)
  keep the `Template vX.Y.Z — …` line and the licensing-contact line.
- **App-original files** omit both.

When modifying a file, maintain a **single** `Modified by <name>, <date>`
line — replace it, never stack a second. Template-derived files get an
"(updated)" suffix on their template-version line.

## Comments

- `///` for symbol documentation (types, functions, properties — renders in
  Xcode Quick Help); `//` for inline explanation and section notes.
- Template-owned content keeps the template's comment style until a change
  is adopted upstream; the standard applies to app-original files and
  app-authored regions.

## Template relationship

Several files are adopted from `template.ios` and merged rather than
rewritten; merge files mark their customizable regions with
`// MARK: - App-Specific`. See AGENTS.md ("Template Relationship") for the
sync tooling and the recorded, accepted divergences.
