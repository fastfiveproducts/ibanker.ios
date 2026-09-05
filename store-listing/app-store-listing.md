# App Store Listing — iBanker

The "what to paste" into App Store Connect. The **process/how** lives in the root
[`RELEASE.md`](../RELEASE.md) runbook; screenshot **generation** is scripted — see
`tools/generate-screenshots.sh` and AGENTS.md → Screenshots. The **assets** are the
sibling files in this folder.

Leveled against the fleet listing format canon (template.ios#194, v0.4.7) and the
paste-copy convention (template.ios#221, in the skeleton since v0.4.8) at the 2.0.2
store leg. Per template.ios#270, pending ⟨OWNER-CONFIRM⟩ tags are **not** used in
content here: iBanker's field decisions are already made, so they are recorded as
dated facts. Process-side owner acts live in `RELEASE.md`.

> App Store search indexes ONLY the app name, subtitle, and keyword field — not the
> description or promotional text — and every word of a multi-word query must match.
> Name and subtitle carry the most ranking weight. Words already in the name/subtitle
> are indexed from those fields and do not need to be repeated as keywords.

## Fields (quick reference)

| Field | Value |
|---|---|
| Bundle ID | `com.maiser.ibanker` (permanent — anchors App Store identity; the historical `com.maiser.*` form is deliberate and stays) |
| App Store ID | `1132712489` — `https://apps.apple.com/app/id1132712489` |
| App Name (≤30) | `iBanker for Board Games` (23) |
| Subtitle (≤30) | `replace paper $ in board games` (30 — at the cap) |
| Primary / secondary category | Games — Board, Family / Entertainment (live: Games · Board · Family · Entertainment) |
| Support URL (ASC-required) | `https://ibanker.fastfiveproducts.com/support/` (= `AppConfig.supportURL`) |
| Marketing URL (ASC-optional) | `https://ibanker.fastfiveproducts.com/` (live) |
| Privacy Policy URL (ASC-required) | `https://ibanker.fastfiveproducts.com/privacy/` (= `AppConfig.privacyURL`) |
| Terms of Service (EULA) URL | N/A — standard Apple EULA (local-only app: no accounts, no custom terms) |
| Contact email | `ibanker@fastfiveproducts.com` (the address the product site's support page publishes) |
| Age rating | 4+ (live) |
| Availability | 29 storefronts — a recorded deviation from the fleet six; see Availability below |
| Copyright | `© 2015–2026 Fast Five Products LLC` |
| Price | Free · English only · requires iOS 18 · first released 2016-07-10 |

**The three URLs are one convention** — distinct values, no duplicates: **Support → the
site's `/support/` page · Marketing → the product-site root · Privacy → the `/privacy/`
page.** Support and Privacy MUST mirror what the app itself opens
(`AppConfig.supportURL` / `AppConfig.privacyURL`); keep the `` = `AppConfig.<field>` ``
annotations on those rows so drift is visible in this doc rather than discovered at
submission — nothing else links a code constant to a store field. All three paste in the
**canonical trailing-slash directory form** (AGENTS.md → URL Form, template.ios#222):
the slashless form costs a 301 that a console validator may not follow. Verified live
2026-09-05: `/`, `/support/`, `/privacy/` all return **200 with no redirect**, while
`/support` and `/privacy` return **301** to the slash form.

⚠️ **Both sides flip together at THIS submission** (the mirror rule): the app constants
moved to the slash form on the 2.0.2 branch, so the ASC Support and Privacy fields must
be re-pasted from this doc in the same pass. The Marketing field is already the slash
form on the live listing.

## Paste-copy convention (PASTE-READY)

Every copy field below marked **PASTE-READY** is pasted into App Store Connect verbatim —
and ASC fields are **plain text**. This is a Markdown document holding non-Markdown copy,
which is a trap; the rules that defuse it:

- **No Markdown.** ASC renders none of it: `**bold**` pastes as visible asterisks. A
  paste block containing `**`, `__`, backticks, or a leading `#` is a defect in this doc.
  Section headings inside the copy are plain text on their own line. ⚠️ **iBanker shipped
  this defect**: the live 2.0.1 description carries five literal `**…**` headings, pasted
  from this file's pre-leveling form (verified against the live listing 2026-09-05 — the
  ff.ios#247 class). The blocks below are corrected; re-paste the Description at this
  submission even though the words are otherwise unchanged.
- **Unwrapped.** The store preserves line breaks literally, so hard-wrapped prose pastes
  as ragged mid-sentence breaks. Keep each paragraph on one long line; blank lines
  separate paragraphs.
- **Fenced.** The copy lives inside a ```` ```text ```` fence so this document's own
  Markdown cannot contaminate it — the literal string is what you see and what you copy.
- **Single copy.** Never keep a prettier second version of approved store copy; two
  copies drift, and the pretty one is the one that ends up pasted.

The character caps beside each heading are ASC-enforced — measure before pasting, and
re-measure after any edit.

## App Name (30 characters max)

**PASTE-READY**

```text
iBanker for Board Games
```

<!-- 23/30. Set with the 2.0.1 submission (owner decision, 2026-07-31), superseding the
     earlier storefront split (US had served "iBanker Calculator"; CA/GB/AU/DE/SG served
     "iBanker"). Disambiguates the brand from a finance/calculator read and plants the
     "board games" search keyword in the highest-weighted field. Fits both the App Store
     and Google Play 30-char title limits, so it reads identically cross-platform
     (ibanker.android). Confirmed live on the US storefront 2026-09-05; the name
     localizes per storefront, so a future rename is a 29-storefront check. -->

## Subtitle (30 characters max)

**PASTE-READY**

```text
replace paper $ in board games
```

<!-- 30/30 — exactly at the cap, so any edit must re-measure. Verified on the US
     storefront 2026-07-30. Complements the name for search: no word repeated from it
     except "board games", which carries the query. -->

## Promotional Text (170 characters max)

**PASTE-READY** — plain text, unwrapped, no Markdown (see the paste-copy convention).

```text
Celebrating 10 years of iBanker — rebuilt from the ground up! Replace the paper money in board games like Monopoly® and The Game of Life®.
```

<!-- 138/170. Unchanged for 2.0.2 and still accurate (first released 2016-07-10). This is
     the one field editable in ASC without a new build, so it is the natural place for
     timely messaging — leading with the iPad split is an option the owner may prefer
     once 2.0.2 is live. -->

## Description (4000 characters max)

**PASTE-READY** — plain text, unwrapped, no Markdown (see the paste-copy convention).

```text
Avoid the hassle of counting cash — keep the paper money in the box and use iBanker instead! Send money to and from "the bank" or directly from one player to another: iBanker completely replaces paper money and the job of "banker" in board games.

Now celebrating its 10th year on the App Store, iBanker 2.0 is a complete ground-up rebuild — a fresh, modern app for iPhone and iPad, with Dark Mode, larger-text support, and the same fast table-side banking families have used for a decade.

Players, Made Personal
Add and manage players with an easy interface — including a photo for each player, taken with the camera or chosen from your library. Every balance stays in view on the roster, formatted like real money.

One-Tap Banking
Type an amount and tap once — Add, Subtract, or Send, right from the keyboard. Sending money starts with picking the player, so transfers are quick between turns. Collect Salary keeps payday to a single tap.

Side by Side on iPad
On iPad, the player roster and the selected player's banking screen sit side by side — tap a player on the left, bank on the right, and keep the whole table in view.

Every Move on the Record
The Activity Log records every transaction in plain language, and the whole game saves automatically — take a break, switch apps, or come back days later and pick up right where you left off.

Game Modes
Change the Mode in Settings to automatically match the starting bank value of the most popular games — $0, $1,500, $10,000, $400,000, or $15,000,000 — or set your own Custom values. When you are ready to start a new game, Reset Players returns everyone to the starting value.

Spin to Win®
The Spinner provides the Spin to Win® function for the electronic banking version of The Game of Life®. It is automatically enabled for the $400,000 Mode.

iBanker is free. It requires iOS 18.

Monopoly and The Game of Life are registered trademarks of Hasbro, Inc. Spin to Win is a registered trademark of The Trustee of the Reuben B. Klamer L.T. The author of this application is not affiliated with those trademark owners, nor is this application endorsed by, supported by, or in any other way connected with those registered trademark owners.
```

<!-- 2197/4000. Three MATERIAL changes at the 2.0.2 leveling, all called out in the
     release-prep handoff rather than slipped in:
       1. The five heading lines lost their ** ** — they are live on the store as literal
          asterisks today (see the paste-copy convention above). Words unchanged.
       2. New section "Side by Side on iPad" — 2.0.2's headline feature, and the store
          shots now lead with it.
       3. New close "iBanker is free. It requires iOS 18." — the price/requirements line
          the fleet's listing shape calls for and this description never carried
          (verified against the live listing: free, minimum iOS 18.0).
     The trademark disclaimer stays last, after the requirements line. -->

## What's New in This Version (4000 characters max)

**PASTE-READY** — plain text, unwrapped, no Markdown (see the paste-copy convention;
this is the field through which ff.ios re-introduced asterisks with every release).

```text
iBanker 2.0.2 brings the iPad up to full size.

Players Side by Side
On iPad, the player roster and the selected player's banking screen now appear together — tap a player on the left, do the banking on the right, and keep the whole table in view.

Room to Breathe
The tab bar becomes a sidebar-style bar on larger screens, and text and forms stay a comfortable width instead of stretching from edge to edge.

Steady on iPhone
iBanker now stays in portrait on iPhone — the orientation it is built for.

iBanker is free. It requires iOS 18.
```

<!-- 539/4000. Authored at release prep for 2.0.2 (template.ios#270: What's New is
     written when develop is readied, not at paste time). The portrait line is here
     deliberately — landscape on iPhone was possible before 2.0.2 and is not now, which
     is a user-visible change even though it is a narrowing.

     Prior release's notes, kept for reference:

     iBanker 2.0.1 is a small polish update to the completely-new 10th Anniversary Edition:

     - A crisper iBanker icon on your home screen
     - Small improvements under the hood

     (Those 2.0.1 notes ARE the ones live on the store — verified 2026-09-05. The old
     "the store still shows the v2.0.0 launch notes" annotation in this file was stale
     and is removed.) -->

## Categories

Primary: Games — Board, Family
Secondary: Entertainment

<!-- Verified live 2026-09-05 (Games · Board · Family · Entertainment). Matches the Play
     categories for cross-platform consistency. -->

## Keywords (100 characters max, comma-separated, no spaces)

**PASTE-READY**

```text
board game, banker, monopoly, game of life, family game, ibanker, calculator
```

<!-- 76/100 — the current LIVE value, recorded as listed, unchanged for 2.0.2. Two
     standing improvements, left as the owner's ASO call rather than changed here:
       - the spaces after commas count against the cap (6 chars);
       - "ibanker" is already indexed from the App Name, so it buys nothing here.
     Reclaiming both frees ~14 characters for a term the name/subtitle do not already
     carry (e.g. "money"). "calculator" is a deliberate holdover from the former
     "iBanker Calculator" storefront name — dropping it would forfeit that query. -->

## Support URL

`https://ibanker.fastfiveproducts.com/support/` (= `AppConfig.supportURL`)
<!-- ASC-required. The product site's /support/ page (canonical trailing-slash form) —
     the SAME page the app's own Support link opens. Flipped from the slashless form at
     2.0.2 (template.ios#222); re-paste in ASC at this submission. -->

## Marketing URL

`https://ibanker.fastfiveproducts.com/`
<!-- ASC-optional; fleet convention: the product site root, trailing-slash form. Already
     this form on the live listing (verified 2026-09-05). The site lives in the sibling
     repo ../ibanker.web/ — file page changes there, never in this repo. -->

## Privacy Policy URL

`https://ibanker.fastfiveproducts.com/privacy/` (= `AppConfig.privacyURL`)
<!-- ASC-required. The product site's /privacy/ page (canonical trailing-slash form) —
     the SAME page the app's own Privacy Policy link opens. Flipped at 2.0.2; re-paste. -->

## Terms of Service (EULA) URL

N/A — standard Apple EULA (local-only app: no accounts, no custom terms).

## Availability (countries/regions)

**iBanker is a deliberate broad-distribution variant — a recorded, accepted
deviation from the fleet standard (owner decision, 2026-07-31).** The fleet
standard is the six English-first markets (Australia, Canada, Ireland, New
Zealand, United Kingdom, United States) for both stores — a support-burden +
cross-border-data hedge. That hedge largely does not apply to iBanker: it is a
**local-only, no-backend, no-data-collection** utility, so the GDPR / UK-GDPR /
PIPA / APPI surface is minimal (no personal-data processing), support is minimal
(no accounts or server), the UI is number/icon-driven (English-only is a low
barrier), and the content is 4+ and a utility, not gambling. So the broad
footprint is a deliberate variant, not drift to clean up.

**Revisit trigger:** this rationale is coupled to staying no-backend. If #9
(multi-device sync) or any account/backend/networking feature lands, the
cross-border-data burden returns — reassess the footprint (and the privacy
manifest / policy) then. Noted on #9.

Current App Store availability (owner-confirmed 2026-07-31 — **29 storefronts**):
Australia, Austria, Belgium, Canada, Croatia, Czech Republic, Denmark, Finland,
France, Germany, Hungary, Iceland, Ireland, Italy, Japan, Korea (Republic of),
Luxembourg, Netherlands, New Zealand, Norway, Portugal, Singapore, Slovakia,
Slovenia, Spain, Sweden, Switzerland, United Kingdom, United States. A superset
of the fleet six across developed, App-Store-mature markets; excludes
friction/emerging regimes (no China/sanctioned markets; not India/South Africa).
Google Play (ibanker.android) to expand to match — see its alignment issue.

## Copyright

© 2015–2026 Fast Five Products LLC

## Assets (sibling files in this folder)

Published store content — the owner reviews/approves before upload. Refreshed per
release; the committed sets are what ibanker.android verifies cross-store content
parity against. Demo data only — the seeded game is fictional.

- `icon-master-1024.png` — the crisp 1024×1024 master (RGB, no alpha) shared
  with ibanker.android: byte-identical to the copy committed in its
  `store-listing/` (white + green token art; owner chose white over the
  branded-green variant, 2026-07-26; regenerated crisp Android-side via
  supersample-threshold). This master doubles as the ASC 1024 reference
  export: the App Store serves the icon from the app's asset catalog
  (`AppIcon.appiconset`), whose 14 slots are exact-size renders of this
  master (#54) — the 1024 marketing slot is a byte-copy of it.
  Note (#54, owner decision 2026-07-30): the rim/gloss visible around the
  token on the iOS 26 home screen is the system's Liquid Glass treatment of
  legacy flat icons, not an artifact in these assets (verified: the master
  is two flat colors with 1-px anti-aliasing) — accepted as-is; adopting the
  layered Icon Composer format would be the only way to change it.
- `screenshots/iphone-6.9/` — **5 shots**, 1320×2868 (iPhone 17 Pro Max):
  01-players-roster · 02-player-banking · 03-activity-log · 04-settings ·
  05-spin-to-win, mirroring the ibanker.android set's shot list, composition, and
  demo state (token names carried from the v2.0.0 published sets).
- `screenshots/ipad-13/` — **4 shots**, 2064×2752 (iPad Pro 13-inch M5): the same
  list without 02-player-banking. 01-players-roster is the set's **flagship** — the
  2.0.2 two-pane split, roster beside the selected player's banking screen — which
  is why the standalone banking push is skipped here (it renders the same form on a
  much wider canvas). 04-settings shows the app-identity footer with the version.
- Regenerate both sets end-to-end with `tools/generate-screenshots.sh [iphone|ipad|all]`
  (the template's tooling since 2.0.2): it erases the dedicated capture simulators,
  seeds the demo game through the app's own persistence, and validates exact accepted
  ASC dimensions + no alpha. Validation never proves CONTENT — hash the output
  directory and open every image, both, every run (AGENTS.md → Screenshots).
- No feature graphic — that is a Google Play asset; the App Store has no equivalent.
