//
//  LayoutBreakpointTests.swift
//
//  Created by Claude, Fast Five Products LLC, on 9/4/26.
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

//  App-only pin (the template testing convention: what the template cannot
//  pin here, adopters owe).  The template pins LayoutBreakpoint's 840 via
//  LaunchViewNavigationTests, which iBanker cannot adopt (no LaunchView —
//  see TEMPLATE.md), so ViewHelpers' "frozen contract" claim would otherwise
//  be unpinned in this repo.  840 is the fleet's shared large-format tier,
//  the Android twin-match (WindowWidthSizeClass Expanded); the #61 tablet
//  leg builds on it.  Deliberately NOT aliased to ContentWidthMode.reading's
//  840 — the cap and the breakpoint coincide numerically and are stated
//  independently on purpose (see the note in ViewHelpers.swift).

import Testing
@testable import iBanker

struct LayoutBreakpointTests {

    @Test("the large-format tier is the fleet's shared 840, the Android twin-match")
    func largeFormatTierIsFrozen() {
        #expect(LayoutBreakpoint.largeFormatMinWidth == 840)
    }
}
