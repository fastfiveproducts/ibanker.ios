//
//  ContentWidthTests.swift
//
//  Template file created by Claude, Fast Five Products LLC, on 8/31/26.
//      Template v0.5.0 — Fast Five Products LLC's public AGPL template.
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

//  Pins the #238 reflow-width contract.  Twin of template.android#86's
//  ContentWidthTest — same three modes, same numbers, deliberately.
//
//  The floor test is the load-bearing one and it is parameterized over
//  allCases ON PURPOSE: a mode added later inherits the >= 600 promise or turns
//  this red.  That is what makes it more than a restatement of the source —
//  the failure it catches is a FUTURE edit, not the current values.
//
//  ⚠️ These are frozen values, not preferences.  Changing one is a contract
//  decision — it changes appearance in wholesale files for every child app at
//  tablet widths, and it breaks congruence with the Android twin.  The numbers
//  are the size-class taxonomy's own breakpoints: forms cap at the
//  Compact/Medium line, reading content at the Medium/Expanded line.
//
//  ⚠️ WHAT THIS DOES NOT BUY, stated so the green is not over-read.  It pins
//  the VALUES.  It does not pin the MODIFIER or its application: deleting
//  `.contentWidthCapped` from every call site, dropping its terminal
//  .frame(maxWidth: .infinity) (screens then hug the leading edge on iPad), or
//  dropping `alignment:` from the inner frame (bubbles lose sent/received
//  anchoring) all leave every test below green.  The protections that DO exist
//  for those are the do-NOT-inline note on ContentWidthMode and the visual pass
//  on iPad_13_Template — not this file.  A dump-oracle test in the shape of
//  LaunchViewNavigationTests could close part of it and is deliberately not
//  attempted here; the layout itself would still need eyes.

import Testing
import SwiftUI
@testable import iBanker

struct ContentWidthTests {

    // THE contract: no cap may dip below the Compact/Medium boundary, because
    // that is the whole basis for "a portrait phone is pixel-unchanged".  A cap
    // under 600 would start binding on devices the modifier promises not to
    // touch.
    @Test("every content-width cap stays at or above the compact boundary",
          arguments: ContentWidthMode.allCases)
    func capsClearTheCompactBoundary(mode: ContentWidthMode) {
        #expect(mode.cap >= 600)
    }

    // The widest cap must still be narrower than the 13" iPad in portrait
    // (1024pt) — otherwise the cap never binds on the device the issue was
    // filed about and the whole change is inert there.
    @Test("the widest cap actually binds on a 13-inch iPad in portrait")
    func widestCapBindsOnTablet() {
        let widest = ContentWidthMode.allCases.map(\.cap).max()
        #expect(widest != nil)
        #expect(widest! < 1024)
    }

    // Frozen values, pinned individually so a silent retune is visible in the
    // diff as a test change — which is exactly the review conversation the
    // "contract decision, not a refactor" rule wants to force.
    @Test("the frozen measures match the Android twin")
    func frozenMeasures() {
        #expect(ContentWidthMode.form.cap == 600)
        #expect(ContentWidthMode.reading.cap == 840)
        #expect(ContentWidthMode.bubble.cap == 600)
    }

    // Reading content is the only mode that should exceed the form measure:
    // prose tolerates a longer line than a label+control row does.
    @Test("reading is the widest measure")
    func readingIsWidest() {
        #expect(ContentWidthMode.reading.cap > ContentWidthMode.form.cap)
        #expect(ContentWidthMode.reading.cap > ContentWidthMode.bubble.cap)
    }
}
