//
//  AppIdentityFooterViewTests.swift
//
//  Template file created by Claude, Fast Five Products LLC, on 8/30/26.
//      Template v0.4.9 — Fast Five Products LLC's public AGPL template.
//      Pins the app-identity footer's version-string composition (#225):
//      "X.Y.Z (build)". The BUILD number is the footer's reason to exist —
//      it is what a TestFlight/internal-testing loop reads on-device to
//      confirm which uploaded build is running — so the format is contract:
//      changing it is a contract decision, not a refactor.
//
//      The bundle-backed test runs against the HOSTED app bundle, which
//      always carries both keys, so it asserts the end-to-end string is
//      well-formed without pinning this target's own version values (a
//      child app inherits the file untouched at any version).
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


import Foundation
import Testing
@testable import iBanker

@MainActor
@Suite("AppIdentityFooterView version string")
struct AppIdentityFooterViewTests {

    @Test func composesVersionAndBuild() {
        #expect(AppIdentityFooterView.versionString(version: "0.4.9", build: "7") == "0.4.9 (7)")
    }

    @Test func missingValuesFallBackToEmDash() {
        #expect(AppIdentityFooterView.versionString(version: nil, build: nil) == "— (—)")
        #expect(AppIdentityFooterView.versionString(version: "1.0", build: nil) == "1.0 (—)")
        #expect(AppIdentityFooterView.versionString(version: nil, build: "3") == "— (3)")
    }

    @Test func bundleBackedStringIsWellFormed() {
        let composed = AppIdentityFooterView.appVersion
        #expect(composed.contains(" ("))
        #expect(composed.hasSuffix(")"))
        // The hosted app bundle always carries a marketing version and a
        // build number, so neither fallback may appear end-to-end.
        #expect(!composed.contains("—"))
    }
}
