//
//  AddNewPlayerView.swift
//
//  Created by Elizabeth Maiser, Fast Five Products LLC, on 7/22/25.
//  Modified by Claude, Fast Five Products LLC, on 9/7/26.
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

import SwiftUI

struct AddNewPlayerView: View {
    // @Environment(\.dismiss) property to dismiss the sheet.
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var gameSession: GameSession
    // The single shared SettingsStore, injected from iBankerApp (#13)
    @EnvironmentObject private var settings: SettingsStore

    // @State properties to hold the input values from the form.
    @State private var playerName: String = ""
    @State private var playerToken: String = ""
    @State private var playerBalance: Int? = nil
    @State private var playerSalary: Int? = nil

    /// Keyboard focus (#35): Return advances Name → Token; the numeric fields
    /// dismiss via the shared keyboardDoneBar.
    private enum Field {
        case name, token, balance, salary
    }
    @FocusState private var focusedField: Field?

    // Player photo capture (#20) — flow provided by .playerPhotoPicker
    @State private var playerImageData: Data? = nil
    @State private var showingPhotoDialog = false
    @State private var isLoadingPhoto = false

    // A closure to pass the new Player object back to the HomeView.
    var onSave: (Player) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Player Details") {
                    HStack {
                        Text("Name:")
                        TextField("Player Name", text: $playerName)
                            .autocorrectionDisabled() // Disable autocorrection for names
                            .textInputAutocapitalization(.words) // Capitalize first letter of each word
                            .focused($focusedField, equals: .name)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .token }
                    }

                    HStack {
                        Text("Token:")
                        TextField("Player Token", text: $playerToken)
                            .autocorrectionDisabled() // Disable autocorrection for names
                            .textInputAutocapitalization(.words) // Capitalize first letter of each word
                            .focused($focusedField, equals: .token)
                            .submitLabel(.done)
                            .onSubmit { focusedField = nil }
                    }

                    HStack {
                        Text("Photo:")
                        Spacer()
                        if isLoadingPhoto {
                            ProgressView()
                                .frame(width: 44, height: 44)
                        } else {
                            PlayerThumbnailView(imageData: playerImageData, size: 44)
                        }
                        Button(playerImageData == nil ? "Add Photo" : "Change") {
                            showingPhotoDialog = true
                        }
                    }

                    HStack {
                        Text("Balance:")
                        // The money formatter renders the committed value's $
                        // itself, replacing the old Text("$") prefix shims.
                        MoneyField("Initial Balance", value: $playerBalance,
                                   focus: $focusedField, equals: .balance,
                                   alignment: .leading)
                    }

                    HStack {
                        Text("Salary:")
                        MoneyField("Initial Salary", value: $playerSalary,
                                   focus: $focusedField, equals: .salary,
                                   alignment: .leading)
                    }
                }

                Section {
                    Button("Save Player") {
                        // Parse, defaulting to 0. Clamp to >= 0 so an accidental
                        // negative (e.g. an iPad hardware-keyboard minus) can't seed a
                        // negative starting balance — .createPlayer (#32) isn't guarded.
                        let finalBalance = max(0, playerBalance ?? 0)
                        let finalSalary = max(0, playerSalary ?? 0)

                        let newPlayer = Player(id: UUID().uuidString,
                                               name: playerName.trimmingCharacters(in: .whitespacesAndNewlines),
                                               token: playerToken.trimmingCharacters(in: .whitespacesAndNewlines),
                                               isLocalOnly: true,
                                               salary: finalSalary,
                                               imageData: playerImageData)

                        // Add the player first, so it's in the roster before the
                        // creation transaction (the Activity Log looks up the name by id).
                        onSave(newPlayer)

                        // Seed balance and salary as one creation event (#32).
                        // Unconditional, so a $0/$0 player still logs "joined the game".
                        gameSession.perform(.createPlayer(balance: finalBalance, salary: finalSalary),
                                            by: newPlayer.id)

                        dismiss() // Dismiss the sheet
                    }
                    .disabled(playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              || isLoadingPhoto) // Disable save if name is empty or a photo load is in flight
                }
            }
            .navigationTitle("Add New Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss() // Dismiss the sheet without saving
                    }
                }
            }
            // Photo capture: the shared flow — confirmation dialog, camera
            // (front-facing first) when available, library via PhotosPicker.
            // See PlayerPhotoPicker.swift.
            .playerPhotoPicker(isPresented: $showingPhotoDialog,
                               imageData: $playerImageData,
                               isLoading: $isLoadingPhoto)
            .keyboardDoneBar(focus: $focusedField)
            // Stuck-guard (#42): belt-and-braces dismissal path — a drag
            // always dismisses the keyboard.
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                // Set default values from the shared settings when the view appears (#13)
                if playerName.isEmpty { // Only set defaults if player name is empty (new player)
                    if playerBalance == nil {
                        playerBalance = settings.effectiveDefaultBalance
                    }
                    if playerSalary == nil {
                        playerSalary = settings.effectiveDefaultSalary
                    }
                }
                // Open ready to type the name (#37 rider)
                focusedField = .name
            }
        }
    }
    
}


#if DEBUG
#Preview {
    // For preview, you still need a GameSession with a SettingsStore
    let sampleSettings = SettingsStore()
    sampleSettings.selectedGameMode = .zero // Or .custom for testing custom fields

    let sampleGameSession = GameSession() // Add player data if needed for preview
    sampleGameSession.settings = sampleSettings // Inject the sample settings

    return AddNewPlayerView(onSave: { player in
        print("Preview: Player saved: \(player.name)")
    })
    .environmentObject(sampleGameSession) // Provide the environment object for the preview
    .environmentObject(sampleSettings)
}
#endif
