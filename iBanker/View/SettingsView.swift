//
//  SettingsView.swift
//
//  Template file created by Elizabeth Maiser, Fast Five Products LLC, on 7/4/25.
//  Modified by Claude, Fast Five Products LLC, on 9/4/26.
//      Template v0.5.0 (updated) — Fast Five Products LLC's public AGPL template.
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

struct SettingsView: View {
    // The single shared SettingsStore, injected from iBankerApp (#13) —
    // do not create additional SettingsStore instances in app code.
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var gameSession: GameSession
    @State private var showingResetPlayersAlert = false
    @State private var showingResetSettingsAlert = false
    @State private var showingDeleteAllPlayersAlert = false

    // Owned by MainTabView (#35): the player-reset actions land back on the
    // Players tab, where their outcome is visible. Reset Settings stays here.
    @Binding var selectedTab: Tab

    var showTitle: Bool = false

    // MARK: - App-Specific
    // iBanker's settings are game configuration: sound/spinner preferences,
    // game-mode defaults (via the shared SettingsStore), and player reset.

    var body: some View {
        VStack {
            if showTitle {
                HStack {
                    Text("Settings")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding(.bottom)
                .contentWidthCapped(.form)   // #238 — align the title with the Form below
            }
            Form {
                Section("Preferences") {
                    Toggle("Sound effects", isOn: $settings.soundEffects)
                    Toggle("Spin-to-Win Spinner", isOn: $settings.enabledSpinner)
                }
                // Shared with the empty-state "Game Mode" sheet (#31); the
                // mode → spinner reset (and the custom fields' Done/Cancel
                // bar publication, #37/#42) live inside GameModeSection.
                GameModeSection()
                // Destructive-settings section (#28, extended #30), mirroring
                // iOS Settings > General > Reset: red buttons, each confirmed,
                // ordered least- to most-destructive. No footer — the confirm
                // alerts carry the explanation.
                Section {
                    Button("Reset Settings", role: .destructive) {
                        showingResetSettingsAlert = true
                    }

                    Button("Reset Players", role: .destructive) {
                        showingResetPlayersAlert = true
                    }
                    .disabled(gameSession.players.isEmpty)

                    Button("Delete All Players", role: .destructive) {
                        showingDeleteAllPlayersAlert = true
                    }
                    .disabled(gameSession.players.isEmpty)
                } header: {
                    Text("Reset")
                }
                .alert("Reset Settings?", isPresented: $showingResetSettingsAlert) {
                    Button("Reset", role: .destructive) {
                        withAnimation {
                            settings.resetAllSettings()
                        }
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("iBanker's settings will return to their defaults.")
                }
                .alert("Reset Players?", isPresented: $showingResetPlayersAlert) {
                    Button("Reset", role: .destructive) {
                        resetPlayers()
                        selectedTab = .home
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Each player's balance and salary will return to the current Mode's defaults.")
                }
                .alert("Delete All Players?", isPresented: $showingDeleteAllPlayersAlert) {
                    Button("Delete All", role: .destructive) {
                        withAnimation {
                            gameSession.deleteAllPlayers()
                        }
                        selectedTab = .home
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Every player will be removed and the game reset. The Activity Log is kept. This can't be undone.")
                }

                // App-identity footer (template #225): logo, brand name,
                // version (build), support/privacy links, copyright — all
                // AppConfig-driven. Replaced the bespoke aboutSection at the
                // v0.5.0 reconcile (#62).
                Section {
                    AppIdentityFooterView()
                        .listRowBackground(Color.clear)
                }
            }
            // #238 cap before the bar host attaches, so the Form caps while
            // the published Done/Cancel bar still spans the full width.
            .contentWidthCapped(.form)
            // Renders the Done/Cancel bar GameModeSection publishes for its
            // custom fields (#42) — a Section can't pin a bottom bar itself.
            .keyboardActionBarHost()
            // Stuck-guard (#42): belt-and-braces dismissal path — a drag
            // always dismisses the keyboard.
            .scrollDismissesKeyboard(.interactively)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
    
    private func resetPlayers() {
        gameSession.resetPlayers(balance: settings.effectiveDefaultBalance, salary: settings.effectiveDefaultSalary)
        // One shake for the whole reset (not per player)
        SoundPlayer.shared.playSystemSound(.shake)
    }

}


#if DEBUG
#Preview {
    let sampleGameSession = GameSession()
    SettingsView(selectedTab: .constant(.settings), showTitle: true)
        .environmentObject(sampleGameSession)
        .environmentObject(sampleGameSession.settings)
}
#endif

