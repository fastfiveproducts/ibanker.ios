//
//  PlayerView.swift
//
//  Created by Elizabeth Maiser, Fast Five Products LLC, on 7/22/25.
//  Modified by Claude, Fast Five Products LLC, on 7/31/26.
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

struct PlayerView: View {
    @EnvironmentObject private var gameSession: GameSession

    let player: Player
    let playerIndex: Int
    
    @State private var salaryInput: Int? = nil
    @State private var addInput: Int? = nil
    @State private var subtractInput: Int? = nil
    @State private var sendInput: Int? = nil
    @State private var selectedPlayer: Player? = nil

    /// Keyboard focus (#35; actions moved onto the shared bar in #42): the
    /// number pad has no Return key, so the keyboardActionBar (attached
    /// below the Form) carries each field's action — one tap applies and
    /// dismisses; Cancel discards.
    private enum Field {
        case salary, add, subtract, send
    }
    @FocusState private var focusedField: Field?

    // Change/add/remove the player's photo (#20 follow-up). `player` is a
    // by-value copy, so the photo binding reads and writes the live player
    // in gameSession.players — the single source of truth for player
    // identity.
    @State private var showingPhotoDialog = false
    @State private var isLoadingPhoto = false

    private var photoBinding: Binding<Data?> {
        Binding(
            get: { gameSession.players.first(where: { $0.id == player.id })?.imageData },
            set: { newValue in
                gameSession.updatePlayerImage(player.id, newValue)
            }
        )
    }

    private var salaryAmount: Int {
        salaryInput ?? 0
    }
    private var addAmount: Int {
        addInput ?? 0
    }
    private var subtractAmount: Int {
        subtractInput ?? 0
    }
    private var sendAmount: Int {
        sendInput ?? 0
    }
    
    var body: some View {
        VStack {
            // Tappable photo opens the shared change/add/remove flow; the camera badge signals editability.
            Button {
                showingPhotoDialog = true
            } label: {
                if isLoadingPhoto {
                    ProgressView()
                        .frame(width: 60, height: 60)
                } else {
                    PlayerThumbnailView(imageData: photoBinding.wrappedValue, size: 60)
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "camera.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.white, Color.accentColor)
                                .offset(x: 4, y: 4)
                        }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Change player photo")
            .padding(.top, 5)

            Text(player.name)
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(5)
            
            Text("Token: \(player.token)")
                .font(.headline)
                .padding(.bottom, 20)
            
            // Money values stay large and bold (glanceable across the game
            // table); labels, entry fields, and buttons use standard Form
            // sizes (#35).
            Form {
                Section {
                        HStack {
                            Text("Balance:")
                                .accessibilityLabel("Text: Balance")

                            Spacer()

                            Text("$\((gameSession.currentState.playerBalances[player.id] ?? 0).formatted())")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(
                                    (gameSession.currentState.playerBalances[player.id] ?? 0) >= 0 ? .green : .red
                                )
                        }
                        HStack {
                            Text("Salary:")
                                .accessibilityLabel("Text: Salary")

                            Spacer()

                            TextField("Enter Salary", value: $salaryInput, formatter: NumberFormatter.money)
                                .font(.title2)
                                .fontWeight(.bold)
                                .keyboardType(.numberPad)
                                .autocorrectionDisabled(true)
                                .multilineTextAlignment(.trailing)
                                .focused($focusedField, equals: .salary)
                        }
                }
                
                Section {
                    Button("Collect $\(salaryAmount.formatted()) Salary") {
                        focusedField = nil
                        gameSession.perform(.collectSalary(amount: salaryAmount), by: player.id)
                    }
                }
                
                Section {
                    HStack {
                        Text("Add $:")
                        Spacer()
                        TextField("Enter Amount", value: $addInput, formatter: NumberFormatter.money)
                            .keyboardType(.numberPad)
                            .autocorrectionDisabled(true)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .add)
                    }
                    HStack {
                        Text("Subtract $:")
                        Spacer()
                        TextField("Enter Amount", value: $subtractInput, formatter: NumberFormatter.money)
                            .keyboardType(.numberPad)
                            .autocorrectionDisabled(true)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .subtract)
                    }
                    // Player-first send (#42): pick the recipient, focus jumps
                    // to the amount, and the bar's Send completes it.
                    VStack {
                        HStack {
                            Text("Send To:")
                            Spacer()
                            Menu {
                                ForEach(gameSession.players.filter { $0.id != player.id }) { otherPlayer in
                                    Button(action: {
                                        selectedPlayer = otherPlayer
                                        focusedField = .send
                                    }) {
                                        Text(otherPlayer.name)
                                    }
                                }
                            } label: {
                                Label(selectedPlayer?.name ?? "Select Player", systemImage: "chevron.down.circle.fill")
                            }
                            .buttonStyle(.bordered)
                        }
                        // No visible label — the placeholder carries it; the row
                        // reads as the amount for the pick above. VoiceOver
                        // still gets a distinct name (the visible label this
                        // replaced).
                        TextField("Enter Amount", value: $sendInput, formatter: NumberFormatter.money)
                            .keyboardType(.numberPad)
                            .autocorrectionDisabled(true)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .send)
                            .accessibilityLabel("Send amount")
                    }
                }
            }
            .keyboardActionBar(focus: $focusedField) { field in
                switch field {
                case .salary:
                    .done   // live-syncs via onChange below; nothing to apply
                case .add:
                    KeyboardAction(label: "Add",
                                   tint: .green,
                                   cancel: { addInput = nil },
                                   apply: {
                                       gameSession.perform(.addMoney(amount: addAmount), by: player.id)
                                       addInput = nil
                                   })
                case .subtract:
                    KeyboardAction(label: "Subtract",
                                   tint: .red,
                                   cancel: { subtractInput = nil },
                                   apply: {
                                       gameSession.perform(.subtractMoney(amount: subtractAmount), by: player.id)
                                       subtractInput = nil
                                   })
                case .send:
                    KeyboardAction(label: "Send",
                                   isEnabled: selectedPlayer != nil,
                                   cancel: { sendInput = nil },
                                   apply: {
                                       if let recipient = selectedPlayer {
                                           gameSession.perform(.payPlayer(recipient.id, amount: sendAmount), by: player.id)
                                           sendInput = nil
                                           // Fresh pick for the next send (owner gate feedback)
                                           selectedPlayer = nil
                                       }
                                   })
                }
            }
            .scrollDismissesKeyboard(.interactively)
            
            Spacer()
        }
        .navigationTitle("Player #\(playerIndex)")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        // Shared photo change/add/remove flow (see PlayerPhotoPicker.swift)
        .playerPhotoPicker(isPresented: $showingPhotoDialog,
                           imageData: photoBinding,
                           isLoading: $isLoadingPhoto)
        .onAppear {
            // Seed the salary field from the stored salary (the reducer seeds
            // every roster player, so the 0 fallback is unreachable here).
            let currentSalary = gameSession.currentState.playerSalaries[player.id] ?? 0
            salaryInput = currentSalary
        }
        .onChange(of: salaryInput) {
            // Persist salary edits immediately so the Collect button label and collect logic stay in sync.
            gameSession.perform(.updateSalary(newSalary: salaryAmount), by: player.id)
        }
    }
}


#if DEBUG
#Preview("Player #1") {
    // GameSession is a class; build it outside the ViewBuilder scope, mutate in onAppear.
    let previewGameSession = GameSession()

    let playerAlice = Player(id: UUID().uuidString, name: "Alice", token: "car", isLocalOnly: true, salary: 200)
    let playerBob = Player(id: UUID().uuidString, name: "Bob", token: "top.hat.fill", isLocalOnly: true, salary: 200)

    NavigationStack {
        PlayerView(player: playerAlice, playerIndex: 1)
            .environmentObject(previewGameSession)
            .onAppear {
                previewGameSession.players.append(playerAlice)
                previewGameSession.players.append(playerBob)

                previewGameSession.perform(.addMoney(amount: 1500), by: playerAlice.id)
                previewGameSession.perform(.payPlayer(playerAlice.id, amount: 200), by: playerBob.id)
                previewGameSession.perform(.subtractMoney(amount: 2000), by: playerAlice.id)
                previewGameSession.perform(.collectSalary(amount: 200), by: playerBob.id)
            }
    }
}

#Preview("Player #2") {
    // GameSession is a class; build it outside the ViewBuilder scope, mutate in onAppear.
    let previewGameSession = GameSession()

    let playerAlice = Player(id: UUID().uuidString, name: "Alice", token: "red", isLocalOnly: true, salary: 200)
    let playerBob = Player(id: UUID().uuidString, name: "Bob", token: "green", isLocalOnly: true, salary: 200)

    NavigationStack {
        PlayerView(player: playerBob, playerIndex: 2)
            .environmentObject(previewGameSession)
            .onAppear {
                previewGameSession.players.append(playerAlice)
                previewGameSession.players.append(playerBob)

                previewGameSession.perform(.addMoney(amount: 1500), by: playerAlice.id)
                previewGameSession.perform(.payPlayer(playerAlice.id, amount: 200), by: playerBob.id)
                previewGameSession.perform(.subtractMoney(amount: 2000), by: playerAlice.id)
                previewGameSession.perform(.collectSalary(amount: 200), by: playerBob.id)
            }
    }
}
#endif
