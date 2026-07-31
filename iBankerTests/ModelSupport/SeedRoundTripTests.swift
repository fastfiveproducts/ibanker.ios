//
//  SeedRoundTripTests.swift
//
//  Created by Claude, Fast Five Products LLC, on 7/31/26.
//      The #55 keeper: the executable seed round-trip proven in the screenshot
//      proof, promoted to a real Swift Testing case now that the #51 wave lands
//      Swift Testing. Locks the demo game shipped in the App Store screenshots
//      (tools/make-screenshot-seed.swift) against the persistence→state pipeline:
//      encode as saveGame does → decode as GameSession.init does → reduce.
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


import Foundation
import Testing
@testable import iBanker

struct SeedRoundTripTests {

    private func stamp(_ n: Int) -> Date { Date(timeIntervalSinceReferenceDate: TimeInterval(n)) }

    @Test func screenshotSeedDecodesAndReducesToDocumentedBalances() {
        // The #55 demo game: 4 players on the $1500/$200 mode — joins, two salary
        // collections, +$50, -$100, send $75 — with the balances documented in
        // make-screenshot-seed.swift: Maya 1,700 / Sam 1,550 / Jordan 1,475 / Ari 1,625.
        let maya = "DEMO-P1-MAYA", sam = "DEMO-P2-SAM", jordan = "DEMO-P3-JORDAN", ari = "DEMO-P4-ARI"
        let players = [
            Player(id: maya, name: "Maya", token: "Car", isLocalOnly: true, salary: 200),
            Player(id: sam, name: "Sam", token: "Dog", isLocalOnly: true, salary: 200),
            Player(id: jordan, name: "Jordan", token: "Wheelbarrow", isLocalOnly: true, salary: 200),
            Player(id: ari, name: "Ari", token: "Boot", isLocalOnly: true, salary: 200),
        ]
        let transactions = [
            GameTransaction(id: "DEMO-T1", timestamp: stamp(1), playerID: maya, action: .createPlayer(balance: 1500, salary: 200)),
            GameTransaction(id: "DEMO-T2", timestamp: stamp(2), playerID: sam, action: .createPlayer(balance: 1500, salary: 200)),
            GameTransaction(id: "DEMO-T3", timestamp: stamp(3), playerID: jordan, action: .createPlayer(balance: 1500, salary: 200)),
            GameTransaction(id: "DEMO-T4", timestamp: stamp(4), playerID: ari, action: .createPlayer(balance: 1500, salary: 200)),
            GameTransaction(id: "DEMO-T5", timestamp: stamp(5), playerID: maya, action: .collectSalary(amount: 200)),
            GameTransaction(id: "DEMO-T6", timestamp: stamp(6), playerID: ari, action: .collectSalary(amount: 200)),
            GameTransaction(id: "DEMO-T7", timestamp: stamp(7), playerID: sam, action: .addMoney(amount: 50)),
            GameTransaction(id: "DEMO-T8", timestamp: stamp(8), playerID: jordan, action: .subtractMoney(amount: 100)),
            GameTransaction(id: "DEMO-T9", timestamp: stamp(9), playerID: ari, action: .payPlayer(jordan, amount: 75)),
        ]

        // Round-trip through the app's own JSON exactly as persistence does
        // (encode like saveGame, decode like GameSession.init), then reduce.
        let playersData = try! JSONEncoder().encode(players)
        let transactionsData = try! JSONEncoder().encode(transactions)
        let decodedPlayers = try! JSONDecoder().decode([Player].self, from: playersData)
        let decodedTransactions = try! JSONDecoder().decode([GameTransaction].self, from: transactionsData)
        let state = GameStateReducer.reduce(players: decodedPlayers, transactions: decodedTransactions)

        #expect(state.playerBalances[maya] == 1_700)
        #expect(state.playerBalances[sam] == 1_550)
        #expect(state.playerBalances[jordan] == 1_475)
        #expect(state.playerBalances[ari] == 1_625)
        for id in [maya, sam, jordan, ari] {
            #expect(state.playerSalaries[id] == 200)
        }
    }
}
