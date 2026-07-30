//
//  MainTabView.swift
//
//  Template created by Pete Maiser, July 2024 through May 2025
//  Renamed from HomeView by Pete Maiser, Fast Five Products LLC, on 10/23/25.
//  App-specific content created by Elizabeth Maiser, Fast Five Products LLC, on 7/22/25.
//  Modified by Claude, Fast Five Products LLC, on 7/30/26.
//
//  Template v0.4.2 (updated) — Fast Five Products LLC's public AGPL template.
//
//  Copyright © 2025, 2026 Fast Five Products LLC. All rights reserved.
//
//  This file is part of a project licensed under the GNU Affero General Public License v3.0.
//  See the LICENSE file at the root of this repository for full terms.
//
//  An exception applies: Fast Five Products LLC retains the right to use this code and
//  derivative works in proprietary software without being subject to the AGPL terms.
//  See LICENSE-EXCEPTIONS.md for details.
//
//  For licensing inquiries, contact: licenses@fastfiveproducts.com
//


import SwiftUI
import SwiftData

struct MainTabView: View {
    @EnvironmentObject private var gameSession: GameSession
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.modelContext) private var modelContext

    @State private var selectedTabItem: Tab = .home
    @State private var showingAddPlayerSheet = false
    @State private var showingSpinnerSheet = false
    @State private var editMode: EditMode = .inactive

    // MARK: - App-Specific
    // Child projects add or remove tabs for their own navigation values below,
    // and customize the mainToolbar extension. Template tabs (.home,
    // .activity, .settings, etc.) should be updated from the template;
    // app-specific tabs should be preserved.
    //
    // iBanker (local-only) diverges from the template here until cloud
    // features are adopted: a local Tab enum stands in for the template's
    // NavigationItem (which is feature-flag/store driven), and the template's
    // store/auth parameters and OverlayManager calls are omitted. Per the
    // template pattern, the toolbar lives here (per-tab toolbar preferences
    // do not propagate through a TabView to the enclosing NavigationStack).

    #if DEBUG
    // Screenshot-capture mode (#55): drives the value-less player push below.
    // Demo data is pre-seeded through the app's own persistence by
    // tools/generate-screenshots.sh; this hook only navigates.
    @State private var screenshotShowPlayer = false
    #endif

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTabItem) {
                HomeView(showingAddPlayerSheet: $showingAddPlayerSheet,
                         editMode: $editMode)
                    .tabItem { Label("Players", systemImage: "person.3.fill") }
                    .tag(Tab.home)

                ActivityLogView()
                    .tabItem { Label("Activity", systemImage: "list.bullet.clipboard.fill") }
                    .tag(Tab.activityLog)

                // selectedTab binding lets the destructive reset actions return
                // to the Players tab (#35), mirroring the editMode pattern above.
                SettingsView(selectedTab: $selectedTabItem)
                    .tabItem { Label("Settings", systemImage: "gear.circle.fill") }
                    .tag(Tab.settings)
            }
            // editMode is owned here (Edit/Done button in mainToolbar) but
            // injected at the List level in HomeView — TabView-level injection
            // doesn't activate a tab-hosted List (#30). Reset it on tab switch.
            .onChange(of: selectedTabItem) {
                editMode = .inactive
            }
            // Also exit Edit mode when the roster empties — the Edit button is
            // hidden with no players, so otherwise a re-added player would render
            // in a stuck Edit mode (#30).
            .onChange(of: gameSession.players.isEmpty) {
                if gameSession.players.isEmpty { editMode = .inactive }
            }
            #if DEBUG
            // Screenshot-capture mode (#55): a programmatic push for the
            // player-banking capture; the stack is otherwise driven by
            // HomeView's NavigationLinks.
            .navigationDestination(isPresented: $screenshotShowPlayer) {
                if let first = gameSession.players.first {
                    PlayerView(player: first, playerIndex: 1)
                }
            }
            #endif
            .navigationTitle(AppConfig.brandName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { mainToolbar }
            // Player-creation and spinner sheets are presented from here so
            // their toolbar entry points and content share one owner.
            .sheet(isPresented: $showingAddPlayerSheet) {
                AddNewPlayerView { newPlayer in
                    gameSession.players.append(newPlayer)
                }
            }
            .sheet(isPresented: $showingSpinnerSheet) {
                SpinnerView()
            }
        }
        // Hand the shared GameSession the SwiftData context so performed actions
        // are recorded to the Activity Log (see GameSession.perform), and run
        // log retention (template v0.4.0): trim to the cap at launch.
        .task {
            gameSession.modelContext = modelContext
            ActivityLogEntry.trimToCap(in: modelContext)
            #if DEBUG
            // Screenshot-capture mode (#55): derive the Activity Log from the
            // seeded transactions (after the modelContext handoff above), then
            // select the requested screen. Inert without the launch argument.
            if let screen = ScreenshotMode.screen {
                gameSession.seedActivityLogFromTransactions()
                switch screen {
                case "player": screenshotShowPlayer = !gameSession.players.isEmpty // no blank push on an unseeded roster
                case "activity": selectedTabItem = .activityLog
                case "settings": selectedTabItem = .settings
                case "spinner": showingSpinnerSheet = true
                default: break // "roster" — the Home tab as launched
                }
            }
            #endif
        }
    }
}

extension MainTabView {
    // Home-tab actions (template mainToolbar pattern: the toolbar is owned by
    // MainTabView and gates items on the selected tab / app state)
    @ToolbarContentBuilder
    var mainToolbar: some ToolbarContent {
        // Brand mark: the principal item replaces the plain inline title with
        // a bold, brand-colored wordmark (navigationTitle remains set for
        // back-button labels and accessibility).
        ToolbarItem(placement: .principal) {
            Text(AppConfig.brandName)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(AppConfig.brandColor)
        }

        ToolbarItem(placement: .topBarLeading) {
            if selectedTabItem == .home && !gameSession.players.isEmpty {
                // Custom edit toggle bound to the injected editMode (see the
                // TabView environment note) — a plain EditButton here binds to
                // the toolbar's own scope and may never reach the tab's List.
                Button(editMode.isEditing ? "Done" : "Edit") {
                    withAnimation {
                        editMode = editMode.isEditing ? .inactive : .active
                    }
                }
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            // Spin-to-Win entry point, shown only when the spinner is
            // enabled (auto-on for the $400K mode).
            if selectedTabItem == .home && settings.enabledSpinner {
                Button(action: {
                    showingSpinnerSheet = true
                }) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .accessibilityLabel("Spin to Win")
                }
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            if selectedTabItem == .home {
                Button(action: {
                    showingAddPlayerSheet = true
                }) {
                    Image(systemName: "plus")
                        .accessibilityLabel("Add New Player")
                }
            }
        }
    }
}

// MARK: - Enum for Tabs
// Define an enum to clearly represent each tab (stands in for the template's
// NavigationItem until cloud features are adopted)
enum Tab {
    case home
    case settings
    case activityLog
}


#if DEBUG
#Preview {
    let previewGameSession = GameSession()
    MainTabView()
        .environmentObject(previewGameSession)
        .environmentObject(previewGameSession.settings)
        .modelContainer(for: ActivityLogEntry.self, inMemory: true)
}
#endif
