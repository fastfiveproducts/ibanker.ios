//
//  HomeViewPaneLayoutTests.swift
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

//  App-only pin of the #61 two-pane decision seam:
//  HomeView.usesTwoPane(containerWidth:) — iBanker's counterpart of the
//  template's MessagesPaneLayoutTests (the #239 exemplar the Players→Player
//  split copies): same shared fleet tier
//  (LayoutBreakpoint.largeFormatMinWidth), same 839/840/841 boundary
//  discipline, pure value assertions only.

import Testing
import CoreGraphics   // CGFloat
@testable import iBanker

@MainActor
struct HomeViewPaneLayoutTests {

    // Below the tier — including 0 and negative (the pre-geometry initial
    // value the surface relies on as its conservative default), a phone
    // width (402), iPad mini portrait (744), and the boundary's near side.
    @Test(arguments: [CGFloat]([0, -1, 402, 744, 839]))
    func widthsBelowTheTierAreSingleColumn(width: CGFloat) {
        #expect(HomeView.usesTwoPane(containerWidth: width) == false)
    }

    // At and above the tier — the closed lower bound (840), its far side
    // (841), and the 13" iPad's real widths (1032 portrait, 1376 landscape).
    @Test(arguments: [CGFloat]([840, 841, 1032, 1376]))
    func widthsAtOrAboveTheTierAreTwoPane(width: CGFloat) {
        #expect(HomeView.usesTwoPane(containerWidth: width))
    }

    // The decision flips exactly at the shared constant, so the surface and
    // the shell cannot drift onto different tiers.
    @Test
    func theTierIsTheSharedConstant() {
        #expect(HomeView.usesTwoPane(
            containerWidth: LayoutBreakpoint.largeFormatMinWidth))
        #expect(!HomeView.usesTwoPane(
            containerWidth: LayoutBreakpoint.largeFormatMinWidth - 1))
    }
}
