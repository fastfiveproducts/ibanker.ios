//
//  SpinnerView.swift
//
//  Created by Pete Maiser, Fast Five Products LLC, on 7/7/26.
//  Modified by Claude, Fast Five Products LLC, on 7/30/26.
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
//  SwiftUI reimplementation of v1.3.0's SpinnerViewController ("Spin to
//  Win", The Game of Life $400K mode): a reel lands on one of four prize
//  values with uniform odds; the prize is awarded to a chosen player
//  through gameSession.perform so it hits the transaction log, balances,
//  and the Activity Log.
//

import SwiftUI

// Reel geometry, file-scope so @State defaults can reference it. Matches
// the original wheel: five groups of the four prize values, then a block of
// "resting" placeholder rows the reel parks on before any spin. Spins
// alternate landing between the second ("top") and fourth ("bottom") prize
// groups so consecutive spins visibly travel.
private let spinnerPrizes = [200_000, 300_000, 400_000, 500_000]
private let spinnerRestingRows = ["?", "??", "???", "??", "?"]
private let spinnerRestingIndex = spinnerPrizes.count * 5 + spinnerRestingRows.count / 2

struct SpinnerView: View {
    @EnvironmentObject private var gameSession: GameSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let rowHeight: CGFloat = 44

    @State private var reelIndex: Int = spinnerRestingIndex
    @State private var landedPrize: Int? = nil
    @State private var selectedPlayer: Player? = nil
    @State private var isSpinning = false

    private var reelRows: [String] {
        var rows: [String] = []
        for _ in 0..<5 {
            rows.append(contentsOf: spinnerPrizes.map { "$\($0.formatted())" })
        }
        rows.append(contentsOf: spinnerRestingRows)
        return rows
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                reel
                    .padding(.top, 20)

                Button {
                    spin()
                } label: {
                    Text("Spin")
                        .font(.title)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSpinning)

                VStack(spacing: 12) {
                    HStack {
                        Text("Send prize to:")
                            .font(.title3)
                        Spacer()
                        Menu {
                            ForEach(gameSession.players) { player in
                                Button(player.name) { selectedPlayer = player }
                            }
                        } label: {
                            Label(selectedPlayer?.name ?? "Select Player", systemImage: "chevron.down.circle.fill")
                        }
                        .buttonStyle(.bordered)
                    }

                    Button {
                        sendPrize()
                    } label: {
                        Text("Send Prize")
                            .font(.title2)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(landedPrize == nil || selectedPlayer == nil || isSpinning)
                }

                Spacer()
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Spin to Win")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            #if DEBUG
            .onAppear {
                // Screenshot-capture mode (#55): park the reel mid-prizes —
                // window $300K/$400K/$500K with $400K centered — instead of
                // the resting "?" rows, matching the published composition.
                if ScreenshotMode.screen == "spinner" {
                    reelIndex = spinnerPrizes.count + 2
                    landedPrize = spinnerPrizes[2]
                }
            }
            #endif
        }
    }

    // A clipped three-row window onto the reel strip, centered on reelIndex.
    private var reel: some View {
        VStack(spacing: 0) {
            ForEach(Array(reelRows.enumerated()), id: \.offset) { _, label in
                Text(label)
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .frame(height: rowHeight)
            }
        }
        .offset(y: CGFloat(1 - reelIndex) * rowHeight)
        .frame(height: rowHeight * 3, alignment: .top)
        .clipped()
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary, lineWidth: 1)
        )
        .overlay(
            Rectangle()
                .stroke(Color.accentColor, lineWidth: 2)
                .frame(height: rowHeight)
        )
        .accessibilityElement()
        .accessibilityLabel("Prize wheel")
        .accessibilityValue(landedPrize == nil ? "Not spun yet" : "$\(landedPrize!.formatted())")
    }

    /// Land on one of the four prizes with uniform odds, alternating between
    /// the top and bottom landing blocks. With Reduce Motion the reel
    /// reveals the result directly instead of animating.
    private func spin() {
        let randomPick = Int.random(in: 0..<spinnerPrizes.count)
        let newIndex: Int
        if reelIndex >= 2 * spinnerPrizes.count {
            newIndex = spinnerPrizes.count + randomPick          // land in the top block
        } else {
            newIndex = 3 * spinnerPrizes.count + randomPick      // land in the bottom block
        }
        landedPrize = spinnerPrizes[randomPick]
        SoundPlayer.shared.playSystemSound(.spinClick)
        if reduceMotion {
            reelIndex = newIndex
        } else {
            // Gate Spin/Send until the reel visually lands, so a prize can't
            // be awarded (or re-spun) while the wheel is still moving.
            isSpinning = true
            withAnimation(.easeInOut(duration: 1.0)) {
                reelIndex = newIndex
            } completion: {
                isSpinning = false
            }
        }
    }

    /// Award the prize through the event-sourced session — never mutate
    /// balances directly. The note carries the original win line into the
    /// transaction and the Activity Log.
    private func sendPrize() {
        guard let prize = landedPrize, let winner = selectedPlayer else { return }
        SoundPlayer.shared.play(.happy)
        gameSession.perform(.addMoney(amount: prize), by: winner.id,
                            note: "\(winner.name) won the spin! $\(prize.formatted()) added to account.")
        // Reset for the next spin
        landedPrize = nil
        selectedPlayer = nil
        reelIndex = spinnerRestingIndex
    }
}


#if DEBUG
#Preview {
    let previewGameSession = GameSession()
    let playerAlice = Player(id: UUID().uuidString, name: "Alice", token: "car", isLocalOnly: true, salary: 200)
    let playerBob = Player(id: UUID().uuidString, name: "Bob", token: "hat", isLocalOnly: true, salary: 200)

    SpinnerView()
        .environmentObject(previewGameSession)
        .onAppear {
            previewGameSession.players.append(playerAlice)
            previewGameSession.players.append(playerBob)
        }
}
#endif
