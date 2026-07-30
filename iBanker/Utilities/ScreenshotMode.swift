//
//  ScreenshotMode.swift
//
//  Created by Claude, Fast Five Products LLC, on 7/30/26.
//
//  Copyright © 2026 Fast Five Products LLC. All rights reserved.
//
//  This file is part of a project licensed under the GNU Affero General Public License v3.0.
//  See the LICENSE file at the root of this repository for full terms.
//
//  An exception applies: Fast Five Products LLC retains the right to use this code and
//  derivative works in proprietary software without being subject to the AGPL terms.
//  See LICENSE-EXCEPTIONS.md for details.
//


import Foundation

#if DEBUG
/// Screenshot-capture launch mode (#55). `tools/generate-screenshots.sh`
/// seeds a demo game through the app's own persistence, then launches with
/// `-ibScreenshotScreen <roster|player|activity|settings|spinner>` to select
/// the captured screen. DEBUG-only; without the argument the app behaves
/// normally.
enum ScreenshotMode {
    /// The screen requested via `-ibScreenshotScreen`, or nil in a normal launch.
    static var screen: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-ibScreenshotScreen"),
              index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }
}
#endif
