# App Store Listing — iBanker

> App Store search indexes ONLY the app name, subtitle, and keyword field —
> not the description or promotional text — and every word of a multi-word
> query must match. Name and subtitle carry the most ranking weight. Words
> already in the name/subtitle are indexed from those fields and do not need
> to be repeated as keywords.

## App Name (30 characters max)

iBanker Calculator

> Storefront split observed 2026-07-30 (public lookups): the US storefront
> serves "iBanker Calculator", while other probed storefronts — CA, GB, AU
> of the standard six, plus DE and SG — still serve "iBanker". Likely an App
> Store Connect localization whose Name was never updated; owner to
> confirm/normalize in the console.

## Subtitle (30 characters max)

replace paper $ in board games

> Verified on the US storefront (2026-07-30); confirm alongside the App Name
> localization check above.

## Promotional Text (170 characters max)

Celebrating 10 years of iBanker — rebuilt from the ground up! Replace the paper money in board games like Monopoly® and The Game of Life®.

## Description (4000 characters max)

Avoid the hassle of counting cash — keep the paper money in the box and use iBanker instead! Send money to and from "the bank" or directly from one player to another: iBanker completely replaces paper money and the job of "banker" in board games.

Now celebrating its 10th year on the App Store, iBanker 2.0 is a complete ground-up rebuild — a fresh, modern app for iPhone and iPad, with Dark Mode, larger-text support, and the same fast table-side banking families have used for a decade.

**Players, Made Personal**
Add and manage players with an easy interface — including a photo for each player, taken with the camera or chosen from your library. Every balance stays in view on the roster, formatted like real money.

**One-Tap Banking**
Type an amount and tap once — Add, Subtract, or Send, right from the keyboard. Sending money starts with picking the player, so transfers are quick between turns. Collect Salary keeps payday to a single tap.

**Every Move on the Record**
The Activity Log records every transaction in plain language, and the whole game saves automatically — take a break, switch apps, or come back days later and pick up right where you left off.

**Game Modes**
Change the Mode in Settings to automatically match the starting bank value of the most popular games — $0, $1,500, $10,000, $400,000, or $15,000,000 — or set your own Custom values. When you are ready to start a new game, Reset Players returns everyone to the starting value.

**Spin to Win®**
The Spinner provides the Spin to Win® function for the electronic banking version of The Game of Life®. It is automatically enabled for the $400,000 Mode.

Monopoly and The Game of Life are registered trademarks of Hasbro, Inc. Spin to Win is a registered trademark of The Trustee of the Reuben B. Klamer L.T. The author of this application is not affiliated with those trademark owners, nor is this application endorsed by, supported by, or in any other way connected with those registered trademark owners.

## What's New in This Version (4000 characters max)

iBanker 2.0.1 is a small polish update to the 10th Anniversary Edition:

- A crisper iBanker icon on your home screen
- Small improvements under the hood

> Live listing note: the store currently shows the v2.0.0 launch notes (the
> full 10th-Anniversary rebuild list); this is the copy for the 2.0.1
> submission. Extend it if more accrues on the 2.0.1 milestone before the
> release act.

## Categories

Primary: Games — Board, Family
Secondary: Entertainment

## Keywords (100 characters max, comma-separated, no spaces)

board game, banker, monopoly, game of life, family game, ibanker, calculator

> Current live value, recorded as listed. Note (2026-07-30): the spaces after
> commas count against the 100-char cap (see the field rule above) — consider
> tightening to comma-only at the next listing update.

## Support URL

https://ibanker.fastfiveproducts.com

## Privacy Policy URL

https://ibanker.fastfiveproducts.com/privacy

## Terms of Service (EULA) URL

N/A — standard Apple EULA (local-only app: no accounts, no custom terms).

## Availability (countries/regions)

Fleet distribution standard (2026-07-30): the **six English-first markets** —
Australia, Canada, Ireland, New Zealand, United Kingdom, United States — for
both stores. Deliberate exclusions (e.g. India, South Africa, Singapore) are a
support-burden trade-off; do not broaden without an owner decision.

Current live availability (verified 2026-07-30 via public storefront lookups;
owner to confirm in App Store Connect): all six standard markets, **plus at
least 17 additional storefronts** — Austria, Belgium, Czechia, Denmark,
Finland, France, Germany, Italy, Japan, Netherlands, Norway, Portugal,
Singapore, South Korea, Spain, Sweden, Switzerland — a deviation from the
standard, flagged for owner cleanup in the console.

## Copyright

© 2015–2026 Fast Five Products LLC

## Assets (sibling files in this folder)

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
- `screenshots/iphone-6.9/` (1320×2868, iPhone 17 Pro Max) and
  `screenshots/ipad-13/` (2064×2752, iPad Pro 13-inch M5) — the generated
  ASC screenshot sets (#55): 01-players-roster · 02-player-banking ·
  03-activity-log · 04-settings · 05-spin-to-win, mirroring the
  ibanker.android sets' shot list, composition, and demo state (token names
  carried from the v2.0.0 published sets). Regenerate end-to-end with
  `tools/generate-screenshots.sh` — it erases the dedicated capture
  simulators, seeds the demo game through the app's own persistence, and
  validates exact accepted dimensions + no alpha. These ship with the 2.0.1
  release.
