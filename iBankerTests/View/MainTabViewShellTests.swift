//
//  MainTabViewShellTests.swift
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

//  App-only pin of the #61 shell decision seam:
//  MainTabView.usesSidebarAdaptableTabs(windowWidth:) — iBanker's stand-in
//  for the template's LaunchView.mainNavigationRootForm rows pinned by
//  LaunchViewNavigationTests (no LaunchView here — see TEMPLATE.md).  The
//  WINDOW-keyed half of the width doctrine; the container-keyed half is
//  HomeViewPaneLayoutTests.  Same shared fleet tier, same boundary
//  discipline, pure value assertions only.

import Testing
import CoreGraphics   // CGFloat
@testable import iBanker

@MainActor
struct MainTabViewShellTests {

    // Below the tier — including 0 (the pre-geometry initial value the shell
    // relies on as its conservative phone-shaped default) and the boundary's
    // near side.
    @Test(arguments: [CGFloat]([0, -1, 402, 744, 839]))
    func widthsBelowTheTierKeepThePlainTabBar(width: CGFloat) {
        #expect(MainTabView.usesSidebarAdaptableTabs(windowWidth: width) == false)
    }

    // At and above the tier — the closed lower bound (840), its far side
    // (841), and the 13" iPad's real widths (1032 portrait, 1376 landscape).
    @Test(arguments: [CGFloat]([840, 841, 1032, 1376]))
    func widthsAtOrAboveTheTierAdaptToTheSidebarStyle(width: CGFloat) {
        #expect(MainTabView.usesSidebarAdaptableTabs(windowWidth: width))
    }

    // The decision flips exactly at the shared constant, so the shell and
    // the Players split cannot drift onto different tiers.
    @Test
    func theTierIsTheSharedConstant() {
        #expect(MainTabView.usesSidebarAdaptableTabs(
            windowWidth: LayoutBreakpoint.largeFormatMinWidth))
        #expect(!MainTabView.usesSidebarAdaptableTabs(
            windowWidth: LayoutBreakpoint.largeFormatMinWidth - 1))
    }
}
