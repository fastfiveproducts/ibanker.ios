//
//  GameStateReducerTests.swift
//
//  Created by Claude, Fast Five Products LLC, on 7/31/26.
//      Reverse-ported from ibanker.android GameStateReducerTest.kt (#51): the
//      Android suite is the parity-validated spec, so test names/intent are kept
//      aligned for side-by-side legibility. Locks the reducer's replay semantics.
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

struct GameStateReducerTests {

    private let alice = Player(id: "alice", name: "Alice", token: "dog", isLocalOnly: true, salary: 200)
    private let bob = Player(id: "bob", name: "Bob", token: "hat", isLocalOnly: true, salary: 0)

    // Ids/timestamps are irrelevant to the reducer (it replays in array order),
    // so a constant stamp keeps the fixtures terse — unlike the Android helper's
    // counter, which only existed to make unique ids.
    private func tx(_ action: GameAction, _ playerID: String) -> GameTransaction {
        GameTransaction(id: "t", timestamp: Date(timeIntervalSinceReferenceDate: 0), playerID: playerID, action: action)
    }

    @Test func playersStartAtZero() {
        let state = GameStateReducer.reduce(players: [alice, bob], transactions: [])
        #expect(state.playerBalances["alice"] == 0)
        #expect(state.playerBalances["bob"] == 0)
        #expect(state.playerSalaries["alice"] == 0)
    }

    @Test func collectSalaryAddsToBalance() {
        let state = GameStateReducer.reduce(
            players: [alice],
            transactions: [tx(.collectSalary(amount: 200), "alice"), tx(.collectSalary(amount: 200), "alice")]
        )
        #expect(state.playerBalances["alice"] == 400)
    }

    @Test func payPlayerTransfersBetweenPlayers() {
        let state = GameStateReducer.reduce(
            players: [alice, bob],
            transactions: [
                tx(.createPlayer(balance: 1500, salary: 200), "alice"),
                tx(.createPlayer(balance: 1500, salary: 200), "bob"),
                tx(.payPlayer("bob", amount: 150), "alice"),
            ]
        )
        #expect(state.playerBalances["alice"] == 1350)
        #expect(state.playerBalances["bob"] == 1650)
    }

    @Test func addAndSubtractMoney() {
        let state = GameStateReducer.reduce(
            players: [alice],
            transactions: [tx(.addMoney(amount: 100), "alice"), tx(.subtractMoney(amount: 30), "alice")]
        )
        #expect(state.playerBalances["alice"] == 70)
    }

    @Test func updateSalaryChangesSalaryOnly() {
        let state = GameStateReducer.reduce(
            players: [alice],
            transactions: [tx(.addMoney(amount: 100), "alice"), tx(.updateSalary(newSalary: 300), "alice")]
        )
        #expect(state.playerBalances["alice"] == 100)
        #expect(state.playerSalaries["alice"] == 300)
    }

    @Test func resetPlayerSetsBalanceAndSalary() {
        let state = GameStateReducer.reduce(
            players: [alice],
            transactions: [tx(.addMoney(amount: 9999), "alice"), tx(.resetPlayer(balance: 1500, salary: 200), "alice")]
        )
        #expect(state.playerBalances["alice"] == 1500)
        #expect(state.playerSalaries["alice"] == 200)
    }

    @Test func createPlayerSeedsBalanceAndSalary() {
        let state = GameStateReducer.reduce(
            players: [alice],
            transactions: [tx(.createPlayer(balance: 400_000, salary: 0), "alice")]
        )
        #expect(state.playerBalances["alice"] == 400_000)
        #expect(state.playerSalaries["alice"] == 0)
    }

    @Test func customActionHasNoStateEffect() {
        let state = GameStateReducer.reduce(
            players: [alice],
            transactions: [tx(.addMoney(amount: 100), "alice"), tx(.custom(description: "Alice won the spin!"), "alice")]
        )
        #expect(state.playerBalances["alice"] == 100)
    }

    @Test func transactionForUnknownPlayerCreatesEntry() {
        // Mirrors the reducer's tolerance: a transaction for a player id not in
        // the roster still gets a balance entry (deleted players' transactions
        // stay in the log so other balances remain correct).
        let state = GameStateReducer.reduce(
            players: [alice],
            transactions: [tx(.addMoney(amount: 50), "ghost")]
        )
        #expect(state.playerBalances["ghost"] == 50)
        #expect(state.playerBalances["alice"] == 0)
    }

    @Test func laterTransactionsWinInReplayOrder() {
        // The reducer replays in array order — resetPlayer/updateSalary are
        // last-writer-wins (order-sensitivity is a known #9 sync concern).
        let state = GameStateReducer.reduce(
            players: [alice],
            transactions: [
                tx(.resetPlayer(balance: 1500, salary: 200), "alice"),
                tx(.addMoney(amount: 100), "alice"),
                tx(.resetPlayer(balance: 0, salary: 0), "alice"),
            ]
        )
        #expect(state.playerBalances["alice"] == 0)
        #expect(state.playerSalaries["alice"] == 0)
    }
}
