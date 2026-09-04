//
//  iBankerApp.swift
//
//  Created by Elizabeth Maiser, Fast Five Products LLC, on 7/16/25.
//  Modified by Pete Maiser, Fast Five Products LLC, on 7/11/26.
//
//  Template v0.2.0 (updated) — Fast Five Products LLC's public AGPL template.
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

import SwiftUI
import SwiftData

@main
struct iBankerApp: App {

    @StateObject private var gameSession = GameSession()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(gameSession)
                .environmentObject(gameSession.settings) // Single shared SettingsStore (#13)
                // Cap Dynamic Type app-wide (template pattern; #35). #14 owns
                // raising the cap for the accessibility (AX) sizes.
                .dynamicTypeSize(...AppConfig.dynamicSizeMax)
                .onDisappear {
                    // Save if the root view is ever torn down (belt-and-braces;
                    // scenePhase below is the deterministic save).
                    gameSession.saveGame()
                }
        }
        // Provide the SwiftData container for the Activity Log. Without this the
        // Activity tab's @Query has no container and crashes at runtime.
        .modelContainer(for: ActivityLogEntry.self)
        // Save whenever the scene leaves the foreground (#38 B1): onDisappear
        // alone never fires on backgrounding or termination — the root view
        // outlives both — so game state was only ever persisted by accidental
        // scene teardown. This restores v1.3.0's deterministic
        // save-on-background (applicationDidEnterBackground) behavior.
        .onChange(of: scenePhase) {
            if scenePhase == .background || scenePhase == .inactive {
                gameSession.saveGame()
            }
        }
    }
}
