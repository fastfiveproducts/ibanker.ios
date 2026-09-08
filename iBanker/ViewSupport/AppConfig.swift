//
//  AppConfig.swift
//
//  Template created as ViewConfig.swift by Pete Maiser, July 2024 through May 2025
//  Renamed to AppConfig.swift by Claude, Fast Five Products LLC, on 7/6/26.
//  Modified by Claude, Fast Five Products LLC, on 9/7/26.
//      Template v0.5.0 (updated) — Fast Five Products LLC's public AGPL template.
//
//  Copyright © 2025, 2026 Fast Five Products LLC. All rights reserved.
//
//  This file is part of a project licensed under the GNU Affero General Public License v3.0.
//  An exception applies: Fast Five Products LLC retains the right to use this code and
//  derivative works in proprietary software without being subject to the AGPL terms.
//  See the LICENSE and LICENSE-EXCEPTIONS.md files at the root of the template repository
//  (github.com/fastfiveproducts/template.ios) for full terms.
//
//  For licensing inquiries, contact: licenses@fastfiveproducts.com
//


import SwiftUI

// AppConfig: branding, settings, config, and reference data specific to
// this implementation.

struct AppConfig {
    static let dynamicSizeMax = DynamicTypeSize.xxxLarge

    // MARK: - App-Specific
    // Child projects customize: brand name, URLs, colors, feature flags,
    // appClientKey, bundledFeatureFlags, and timing values below.
    //
    // iBanker is local-only (no Firebase) and skips the template's splash/overlay
    // choreography, so its launch-timing, feature-flag, multi-tenancy,
    // video-background, and post-display entries are omitted — re-add them from
    // the template when adopting those features (see AGENTS.md, Template Relationship).

    static let brandName = "iBanker"

    // Launch linger (#66 Route B-minimal, owner-approved 2026-09-07): the
    // system launch screen flashes past on fast devices, so an in-app frame
    // pixel-identical to it holds and then fades — anchored to the app's
    // FIRST RENDERED FRAME (the overlay's .task start), not to process
    // launch. Purely visual: the overlay never hit-tests, so it costs zero
    // interaction time. This is NOT the template's LaunchView/overlay
    // choreography (deliberately not adopted — see AGENTS.md).
    static let launchLingerHold: TimeInterval = 0.45   // pawn holds after first frame
    static let launchLingerFade: TimeInterval = 0.35   // then fades out

    // Canonical trailing-slash directory form (AGENTS.md → URL Form, template
    // #222): both pages ARE directories serving index.html, and the slashless
    // form costs a 301 that a store console's validator may not follow. Flipped
    // with the matching ASC fields at the 2.0.2 submission — the mirror rule
    // says both sides move together, never one alone.
    static let privacyText = "Privacy Policy"
    static let privacyURL = URL(string: "https://ibanker.fastfiveproducts.com/privacy/")!

    static let supportText = "\(brandName) Support"
    static let supportURL = URL(string: "https://ibanker.fastfiveproducts.com/support/")!

    // App-identity footer (template #225, AppIdentityFooterView — mounted in
    // SettingsView): the optional logo shown above the brand name, and the
    // copyright line. The logo must be an asset-catalog IMAGE set, never the
    // app-icon set (#234 — an app-icon set is not a lookup-able image asset).
    static let brandLogoAssetName: String? = "iBankerLogo"

    static let copyrightText = "© 2015–2026 Fast Five Products LLC"

    // Fixed Colors
    // brandColor is iBanker's classic dark green. The rest of the pre-upgrade
    // AppColor palette, kept for future branding:
    //   darkGreen  121/153/78    lightGreen 183/231/118
    //   offWhite   242/242/228   darkGray    41/41/38
    //   lightGray   97/97/84     red        231/118/127
    static let brandColor: Color =
        Color(red: 121/255, green: 153/255, blue: 78/255)

    static let linkColor: Color =
        Color.accentColor

    static let bgColor: Color =
        Color(UIColor.systemBackground)

    static let fgColor =
        Color(.label)

}


#if DEBUG

#Preview ("Colors") {
    VStack(spacing: 12) {
        Text("brandColor").foregroundStyle(AppConfig.brandColor)
        Text("linkColor").foregroundStyle(AppConfig.linkColor)
        Text("fgColor on bgColor")
            .foregroundStyle(AppConfig.fgColor)
            .padding()
            .background(AppConfig.bgColor)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
    .dynamicTypeSize(...AppConfig.dynamicSizeMax)
}
#endif
