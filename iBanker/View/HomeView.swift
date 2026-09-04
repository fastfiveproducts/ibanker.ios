//
//  HomeView.swift
//
//  Template created by Pete Maiser, July 2024 through May 2025
//  Split from MenuView ~restored by Pete Maiser, Fast Five Products LLC, on 10/23/25.
//  App-specific content created by Elizabeth Maiser, Fast Five Products LLC, on 7/16/25.
//  Modified by Claude, Fast Five Products LLC, on 7/31/26.
//
//  Template v0.4.2 (updated) — Fast Five Products LLC's public AGPL template.
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

struct HomeView: View {
    @EnvironmentObject private var gameSession: GameSession

    // Owned by MainTabView's toolbar; this binding lets the empty state present it too.
    @Binding var showingAddPlayerSheet: Bool

    // Owned by MainTabView's toolbar; attached at the List level here — the only
    // place it reliably activates a tab-hosted List (#30).
    @Binding var editMode: EditMode

    // Delete goes through a confirmation. Capture players (not offsets) so it
    // stays valid if the roster shifts underneath.
    @State private var pendingDeletePlayers: [Player] = []
    @State private var showingDeleteConfirm = false

    // Empty-state "Game Mode" detour as a sheet (#31) — return-able, not a tab
    // switch. Local since it's triggered only here.
    @State private var showingGameModeSheet = false

    // MARK: - App-Specific
    // Child projects typically replace the entire body with their own
    // home screen composition. iBanker's home screen is the player roster;
    // the enclosing NavigationStack, navigation title, and toolbar are
    // provided by MainTabView (template pattern).

    var body: some View {
        contentView
    }
    
    /// Determines whether to show the empty state or the list of players.
    @ViewBuilder
    private var contentView: some View {
        if gameSession.players.isEmpty {
            emptyPlayersView
        } else {
            playersListView
        }
    }

    /// The view displayed when no players have been added.
    private var emptyPlayersView: some View {
        VStack(spacing: 20) {
            Text("No players added")
                .font(.headline)
                .foregroundColor(.gray)

            Divider()

            Text("Welcome to iBanker!")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            // Tagline carried forward from the original app's first-launch screen
            Text("iBanker takes the place of paper money in board games!")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Divider()

            // Return-able sheet, not a tab switch (#31).
            Button(action: {
                showingGameModeSheet = true
            }) {
                VStack(spacing: 4) {
                    Text("Tap here to choose your game mode!")
                        .font(.subheadline)
                    Text("You can change it later in the Settings tab.")
                        .font(.footnote)
                }
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)

            Divider()

            Button(action: {
                showingAddPlayerSheet = true
            }) {
                Text("Tap here or press the + button to create your first player!")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)

            Divider()

            // Plain hint, not a tappable teleport — the Activity Log is empty at launch (#31).
            Text("Throughout the game, the Activity tab records every action.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showingGameModeSheet) {
            gameModeSheet
        }
    }

    /// Empty-state "Game Mode" sheet (#31): Done/grabber returns to Players.
    /// Reuses GameModeSection, so it writes through to the shared SettingsStore.
    private var gameModeSheet: some View {
        NavigationStack {
            Form {
                GameModeSection()
            }
            // Renders the Done/Cancel bar GameModeSection publishes for its
            // custom fields (#42) — a Section can't pin a bottom bar itself.
            .keyboardActionBarHost()
            // Stuck-guard (#42): belt-and-braces dismissal path — a drag
            // always dismisses the keyboard.
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Game Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingGameModeSheet = false }
                }
            }
        }
    }

    /// The view displaying the list of players.
    private var playersListView: some View {
        VStack(spacing: 0) {
            List {
                ForEach(Array(gameSession.players.enumerated()), id: \.element.id) { index, player in
                    // In Edit mode the row shows one Delete button (unless the
                    // player has exchanged money — see hasExchangedMoney) and does
                    // not navigate; otherwise it's a tappable row that pushes
                    // PlayerView. Reorder handles come from .onMove. One Delete tap
                    // replaces the native minus + slide-in Delete two-step.
                    if editMode.isEditing {
                        HStack {
                            playerRow(player)
                            if !gameSession.hasExchangedMoney(player.id) {
                                Button("Delete", role: .destructive) {
                                    requestDelete(player)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        NavigationLink(destination: PlayerView(player: player, playerIndex: index + 1)) {
                            playerRow(player)
                                .padding(.vertical, 4)
                        }
                    }
                }
                .onMove(perform: gameSession.movePlayer)
            }
            // editMode at the List level — TabView-level injection doesn't
            // activate a tab-hosted List (#30).
            .environment(\.editMode, $editMode)

            // While editing, explain why some rows have no delete control.
            if editMode.isEditing
                && gameSession.players.contains(where: { gameSession.hasExchangedMoney($0.id) }) {
                Text("Players who've exchanged money can't be removed individually. Use Reset Players or Delete All Players in Settings.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            }
        }
        .background(Color(.systemGroupedBackground))
        .alert("Delete Player?", isPresented: $showingDeleteConfirm) {
            Button("Delete", role: .destructive) {
                gameSession.deletePlayers(pendingDeletePlayers)
                pendingDeletePlayers = []
            }
            Button("Cancel", role: .cancel) {
                pendingDeletePlayers = []
            }
        } message: {
            if pendingDeletePlayers.count == 1 {
                Text("\(pendingDeletePlayers[0].name) will be removed from the game. This can't be undone.")
            } else {
                Text("The selected players will be removed from the game. This can't be undone.")
            }
        }
    }

    // MARK: - Helper Functions

    /// One roster row's content (thumbnail, name/token, balance) — shared by the
    /// navigating row and the Edit-mode row.
    private func playerRow(_ player: Player) -> some View {
        HStack {
            PlayerThumbnailView(imageData: player.imageData, size: 44)

            VStack(alignment: .leading) {
                Text(player.name)
                    .font(.headline)
                    .accessibilityLabel("Player name: \(player.name)")

                if !player.token.isEmpty {
                    Text("Token: \(player.token)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .accessibilityLabel("Player token name: \(player.token)")
                }
            }
            .frame(minHeight: 40)

            Spacer()

            // Shrink to fit rather than wrap: big-money modes ($15M) at the
            // largest allowed Dynamic Type size were wrapping mid-number.
            Text("$\((gameSession.currentState.playerBalances[player.id] ?? 0).formatted())")
                .font(.title2)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundColor(
                    (gameSession.currentState.playerBalances[player.id] ?? 0) >= 0 ? .green : .red
                )
        }
    }

    // Confirm before deleting (destructive, no undo). Deletion goes through
    // GameSession, which logs a marker and keeps the transaction log.
    private func requestDelete(_ player: Player) {
        pendingDeletePlayers = [player]
        showingDeleteConfirm = true
    }
}


#if DEBUG
#Preview {
    let sampleGameSession = GameSession()
    // HomeView no longer owns a NavigationStack (MainTabView provides it),
    // so the preview supplies one for the navigation links.
    NavigationStack {
        HomeView(showingAddPlayerSheet: .constant(false),
                 editMode: .constant(.inactive))
    }
    .environmentObject(sampleGameSession)
    .environmentObject(sampleGameSession.settings)
}
#endif
