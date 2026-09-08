//
//  AppIdentityFooterView.swift
//
//  Template file created by Claude, Fast Five Products LLC, on 8/30/26.
//      Template v0.4.9 — Fast Five Products LLC's public AGPL template.
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


import SwiftUI

// App-identity footer (#225, generalized from the ibanker/dtrol Settings
// footers): logo (optional), brand name, "Version X.Y.Z (build)", the
// support and privacy links, and the copyright line — all AppConfig-driven.
//
// The BUILD number is the point: builds in a TestFlight or internal-testing
// loop often differ ONLY by CFBundleVersion, and this footer is the one
// on-device way to confirm which uploaded build is actually running.
//
// The template mounts this in BOTH SettingsView (its template-owned frame)
// and SupportView (its sample body). A child that keeps one of those
// surfaces prunes the other mount — that is the sanctioned pick, not a
// divergence, the same doctrine as the navigation-style case set (#193).
// Keeping both is equally fine; the two mounts render identically.
struct AppIdentityFooterView: View {
    var body: some View {
        VStack(spacing: 6) {
            if let assetName = AppConfig.brandLogoAssetName {
                // Decorative: the brand-name text follows, so per the
                // accessibility rule (#208) the image is hidden rather
                // than announcing a raw asset file name.
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .accessibilityHidden(true)
            }
            Text(AppConfig.brandName)
                .font(.headline)
            Text("Version \(Self.appVersion)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Link(AppConfig.supportText, destination: AppConfig.supportURL)
                .font(.caption)
            Link(AppConfig.privacyText, destination: AppConfig.privacyURL)
                .font(.caption)
            Text(AppConfig.copyrightText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        // Two Links stack here: in a Form/List mount the row would
        // otherwise forward any tap to the FIRST control, so each needs
        // its own discrete hit area (see ViewHelpers.multiControlRow).
        // Harmless in a plain ScrollView mount like SupportView's.
        .multiControlRow()
    }

    /// e.g. "0.4.9 (1)" — marketing version and build from the bundle,
    /// never hand-maintained.
    static var appVersion: String {
        versionString(
            version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            build: Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        )
    }

    /// Pure composition, pinned by the suite: "X.Y.Z (build)", an em dash
    /// standing in for a value the bundle omits.
    static func versionString(version: String?, build: String?) -> String {
        "\(version ?? "—") (\(build ?? "—"))"
    }
}


#if DEBUG
#Preview {
    AppIdentityFooterView()
}
#Preview ("in a Form") {
    Form {
        Section {
            AppIdentityFooterView()
                .listRowBackground(Color.clear)
        }
    }
}
#endif
