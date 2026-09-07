//
//  iBankerApp.swift
//
//  Created by Elizabeth Maiser, Fast Five Products LLC, on 7/16/25.
//  Modified by Claude, Fast Five Products LLC, on 9/7/26.
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

    // Launch linger (#66): ONE-SHOT by construction — `isLingering` starts
    // true at process launch, goes false once, and nothing can set it true
    // again, so the template's splash-repaints-over-live-content class
    // (template.ios#274) is structurally impossible here. The exit animates
    // OPACITY (state-driven every frame) and only removes the view once it
    // is invisible — never an insertion/removal transition, whose exit can
    // be dropped by a parent invalidation on the committing frame (the
    // ff.ios/bg.ios ghost, 2026-09-05/06).
    @State private var isLingering = true
    @State private var lingerOpacity = 1.0

    private var showsLaunchLinger: Bool {
        #if DEBUG
        // Never in a capture (the ti#256 class) — and referenced only inside
        // DEBUG, because ScreenshotMode does not exist in a Release build.
        if ScreenshotMode.isActive { return false }
        #endif
        return isLingering
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
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

                // Near-identical continuation of the launch screen (same
                // backdrop color set, same image at intrinsic size, centered)
                // so the pawn simply stays a beat longer. Hidden from taps
                // AND assistive tech: transient launch chrome (the #208
                // rule's sanctioned option).
                //
                // Known cosmetic, OWNER-ACCEPTED 2026-09-07: on iPad the
                // launch-screen → this-frame handoff can show a slight jump
                // (the OS's launch-screen centering and this ZStack's are not
                // byte-identical there). Deliberately NOT hand-tuned against
                // the OS's private layout — revisit when ti#274's splash
                // rework rolls through, which may replace this shim outright.
                if showsLaunchLinger {
                    ZStack {
                        Color("LaunchBackdrop").ignoresSafeArea()
                        Image("iBankerLaunchLogo")
                    }
                    .opacity(lingerOpacity)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .task {
                        try? await Task.sleep(for: .seconds(AppConfig.launchLingerHold))
                        withAnimation(.easeOut(duration: AppConfig.launchLingerFade)) {
                            lingerOpacity = 0
                        }
                        try? await Task.sleep(for: .seconds(AppConfig.launchLingerFade))
                        isLingering = false
                    }
                }
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
