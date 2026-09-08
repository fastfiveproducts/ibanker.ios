//
//  EditPlayerView.swift
//
//  Created by Claude, Fast Five Products LLC, on 9/7/26.
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

import SwiftUI

/// Post-creation Name/Token editing (#67), presented as a sheet from
/// PlayerView's pencil affordance. A sheet with an explicit Save was chosen
/// (matching the Android twin's dialog, ibanker.android#22) so the commit is
/// ONE-SHOT: no focus-loss or teardown path ever writes, which is what makes
/// the delete-out-from-under audit trivial — a Save for a vanished player
/// no-ops in the model (`updatePlayerIdentity` guards the id).
///
/// The field rows deliberately mirror AddNewPlayerView's Name/Token rows
/// (trim-at-save via the model, `.words` capitalization, autocorrection off,
/// Return advances Name → Token) so creation and edit cannot drift apart.
struct EditPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var gameSession: GameSession

    let player: Player

    @State private var playerName: String
    @State private var playerToken: String

    private enum Field {
        case name, token
    }
    @FocusState private var focusedField: Field?

    init(player: Player) {
        self.player = player
        _playerName = State(initialValue: player.name)
        _playerToken = State(initialValue: player.token)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Player Details") {
                    HStack {
                        Text("Name:")
                        TextField("Player Name", text: $playerName)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.words)
                            .focused($focusedField, equals: .name)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .token }
                    }

                    HStack {
                        Text("Token:")
                        TextField("Player Token", text: $playerToken)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.words)
                            .focused($focusedField, equals: .token)
                            .submitLabel(.done)
                            .onSubmit { focusedField = nil }
                    }
                }

                Section {
                    Button("Save") {
                        gameSession.updatePlayerIdentity(player.id,
                                                         name: playerName,
                                                         token: playerToken)
                        dismiss()
                    }
                    .disabled(playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Edit Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss() // Dismiss without saving
                    }
                }
            }
            .keyboardDoneBar(focus: $focusedField)
            // Stuck-guard (#42): a drag always dismisses the keyboard.
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                // Open ready to edit the name (the creation sheet's pattern)
                focusedField = .name
            }
        }
    }
}


#if DEBUG
#Preview {
    let sampleGameSession = GameSession()
    let samplePlayer = Player(id: "preview", name: "Maya", token: "Car",
                              isLocalOnly: true, salary: 200)
    sampleGameSession.players.append(samplePlayer)

    return EditPlayerView(player: samplePlayer)
        .environmentObject(sampleGameSession)
}
#endif
