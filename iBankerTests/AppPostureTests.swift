//
//  AppPostureTests.swift
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

//  App-only pin of the #61 orientation posture, asserted against the BUILT
//  product: hosted unit tests run inside the app bundle, and the plist is
//  read RAW from disk — the same artifact `plutil -p` proves at the gate.
//  (Bundle's infoDictionary is the wrong instrument here: it applies
//  device-variant resolution and strips the non-matching `~ipad` key on an
//  iPhone destination.)  The posture lives in the checked-in Info.plist and
//  ONLY there (#39: `INFOPLIST_KEY_*` build settings are inert in this
//  target shape).

import Foundation
import Testing

struct AppPostureTests {

    // The built app's Info.plist, deserialized raw — no variant resolution.
    private var builtInfoPlist: [String: Any] {
        let url = Bundle.main.bundleURL.appendingPathComponent("Info.plist")
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(
                  from: data, options: [], format: nil) as? [String: Any]
        else { return [:] }
        return plist
    }

    @Test("iPhone is Portrait-only")
    func iphonePortraitOnly() {
        let orientations = builtInfoPlist["UISupportedInterfaceOrientations"] as? [String]
        #expect(orientations == ["UIInterfaceOrientationPortrait"])
    }

    @Test("iPad keeps all four orientations")
    func ipadKeepsAllFour() {
        let orientations = builtInfoPlist["UISupportedInterfaceOrientations~ipad"] as? [String]
        #expect(orientations?.count == 4)
        #expect(Set(orientations ?? []) == [
            "UIInterfaceOrientationPortrait",
            "UIInterfaceOrientationPortraitUpsideDown",
            "UIInterfaceOrientationLandscapeLeft",
            "UIInterfaceOrientationLandscapeRight",
        ])
    }
}
