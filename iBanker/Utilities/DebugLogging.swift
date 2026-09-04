//
//  DebugLogging.swift
//
//  Template created by Pete Maiser, July 2024 through May 2025
//  Modified by Pete Maiser, Fast Five Products LLC, on 2/26/26.
//      Template v0.3.4 (updated) — Fast Five Products LLC's public AGPL template.
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


import Foundation
import os.log

protocol DebugPrintable {}

extension DebugPrintable {
    static var debug: Bool {
        #if DEBUG
            return true
        #else
            return false
        #endif
    }
    
    func debugprint(_ str: String) {
        if Self.debug {
            print("\(String(describing: type(of: self))) \(str)")
        }
    }
}

func deviceLog(_ message: String, category: String = "General", error: Error? = nil) {
    let bundleIdentifier: String = Bundle.main.bundleIdentifier ?? "unknownBundleId"
    let log = OSLog(subsystem: bundleIdentifier, category: category)

    if let error = error {
        os_log(.error, log: log, "%{public}@ %@", message, error.localizedDescription)
    } else {
        os_log(.error, log: log, "%{public}@", message)
    }
}
