//
//  ScreenshotMode.swift
//
//  Template file created by Claude, Fast Five Products LLC, on 8/11/26.
//  App-specific content created by Claude, Fast Five Products LLC, on 7/30/26 (#55, pre-template).
//  Modified by Claude, Fast Five Products LLC, on 9/4/26.
//      Template v0.4.8 (updated) — Fast Five Products LLC's public AGPL template.
//
//  Copyright © 2026 Fast Five Products LLC. All rights reserved.
//
//  This file is part of a project licensed under the GNU Affero General Public License v3.0.
//  An exception applies: Fast Five Products LLC retains the right to use this code and
//  derivative works in proprietary software without being subject to the AGPL terms.
//  See the LICENSE and LICENSE-EXCEPTIONS.md files at the root of the template repository
//  (github.com/fastfiveproducts/template.ios) for full terms.
//
//  For licensing inquiries, contact: licenses@fastfiveproducts.com
//
//  Purpose:
//  The launch-argument hook `tools/generate-screenshots.sh` drives to capture
//  App Store screenshots — it launches the app with `<launchArgument> <name>`
//  to pick the screen to shoot.  Without that argument the app behaves
//  completely normally.
//
//  DEBUG-only, deliberately: screenshot scaffolding must not exist in a
//  shipped binary.  The Release strip is verifiable — grep the Release binary
//  for THIS APP's `launchArgument` value plus `ScreenshotMode`; each must
//  return zero hits.
//
//  iBanker wiring (differs from the template's four Firebase-coupled points —
//  see AGENTS.md → Testing): tools/generate-screenshots.sh seeds a demo game
//  through the app's own persistence (make-screenshot-seed.swift), and
//  MainTabView's launch .task reads `screen` to select the requested
//  tab/push/sheet.  There is no test-service substitution, LaunchView
//  injection, or ListableStore demo route here.
//

import Foundation

#if DEBUG
enum ScreenshotMode {

    // MARK: - App-Specific
    // Child projects rename this argument to their own prefix
    // (`-ffScreenshotScreen`, `-bgScreenshotScreen`, …) and MUST keep it
    // identical to the launch argument tools/generate-screenshots.sh passes —
    // in iBanker's #55 script that is the hardcoded `-ibScreenshotScreen`
    // literal (three sites); the template's two-class script names it
    // LAUNCH_ARG.  It lives here, alone and marked, so a reconcile treats it
    // as a merge point instead of copying the template's name back over it —
    // a silent mismatch disables every screenshot hook and still captures
    // and validates cleanly.
    static let launchArgument = "-ibScreenshotScreen"

    /// The screen requested via `launchArgument`, or nil in a normal launch.
    static var screen: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: launchArgument),
              index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    /// True while capturing — gates the demo data and the launch short-circuit.
    static var isActive: Bool { screen != nil }
}
#endif
