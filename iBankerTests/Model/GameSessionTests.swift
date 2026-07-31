//
//  GameSessionTests.swift
//
//  Created by Claude, Fast Five Products LLC, on 7/31/26.
//      Reverse-ported from ibanker.android GameSessionTest.kt (#51): locks
//      GameSession's guards (incl. the #36 no-op updateSalary guard and the #38
//      self-pay / negative-salary / negative-reset guards), the side-effect
//      choreography (Activity Log strings + sound map), roster ops, and
//      persistence. Names/intent kept aligned with the Android spec.
//
//      Port notes (iOS seams the Android port took first, added here for #51):
//      • sounds are observed through the injected `GameSoundPlaying` seam
//        (`RecordingSoundPlayer`), not the `SoundPlayer.shared` singleton;
//      • activity strings are captured through the `onActivity` hook in call
//        order (the iOS analog of Android's onActivity), not SwiftData;
//      • persistence uses an injected ephemeral `UserDefaults` suite. iBanker
//        persists on scene-phase (not per mutation, unlike Android's store), so
//        the relaunch cases call `saveGame()` explicitly — the app's own
//        background-save analog;
//      • reorder is offset-based (`move(fromOffsets:toOffset:)`): the Android
//        integer `movePlayer(fromIndex:toIndex:)` maps to the SwiftUI-native
//        signature, so the out-of-range case exercises an out-of-range OFFSET
//        (a negative index isn't expressible as a non-negative IndexSet).
//      • Activity strings use `Int.formatted()` grouping; the gate sim
//        (iPhone_17_iBanker) is en_US, matching the Android suite's Locale.US pin.
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

private final class RecordingSoundPlayer: GameSoundPlaying {
    private(set) var played: [SoundEffect] = []
    private(set) var queued: [SoundEffect] = []
    func play(_ effect: SoundEffect, volume: Float) { played.append(effect) }
    func playQueued(_ effect: SoundEffect, volume: Float) { queued.append(effect) }
}

private final class ActivityRecorder {
    private(set) var events: [String] = []
    func record(_ event: String) { events.append(event) }
}

@MainActor
struct GameSessionTests {

    private let alice = Player(id: "alice", name: "Alice", token: "dog", isLocalOnly: true, salary: 200)
    private let bob = Player(id: "bob", name: "Bob", token: "hat", isLocalOnly: true, salary: 0)
    private let carol = Player(id: "carol", name: "Carol", token: "car", isLocalOnly: true, salary: 0)

    // Fresh per test (Swift Testing builds a new instance for each @Test); the
    // closure/seam captures these reference types so assertions read them back.
    private let events = ActivityRecorder()
    private let sounds = RecordingSoundPlayer()

    private func makeStore() -> (UserDefaults, String) {
        let suite = "test.ibanker.session.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suite)!, suite)
    }

    private func makeSession(_ store: UserDefaults) -> GameSession {
        let session = GameSession(defaults: store, settings: SettingsStore(store: store), soundPlayer: sounds)
        session.onActivity = { [events] event, _ in events.record(event) }
        return session
    }

    private func makeSessionWithRoster(_ store: UserDefaults) -> GameSession {
        let session = makeSession(store)
        for player in [alice, bob, carol] {
            session.players.append(player)
            session.perform(.createPlayer(balance: 1500, salary: 200), by: player.id)
        }
        return session
    }

    // MARK: - perform guards

    @Test func zeroAmountMoneyActionsAreIgnored() {
        let (store, suite) = makeStore(); defer { store.removePersistentDomain(forName: suite) }
        let session = makeSession(store)
        session.players.append(alice)
        session.perform(.addMoney(amount: 0), by: "alice")
        session.perform(.subtractMoney(amount: -5), by: "alice")
        session.perform(.collectSalary(amount: 0), by: "alice")
        session.perform(.payPlayer("bob", amount: 0), by: "alice")
        #expect(session.transactions.isEmpty)
        #expect(events.events.isEmpty)
        #expect(sounds.played.isEmpty)
    }

    @Test func selfPayIsIgnored() {
        // ibanker.ios#38 B2: a self-pay would replay as a lost amount — blocked
        // at the perform choke point.
        let (store, suite) = makeStore(); defer { store.removePersistentDomain(forName: suite) }
        let session = makeSession(store)
        session.players.append(alice)
        session.perform(.createPlayer(balance: 1500, salary: 200), by: "alice")
        session.perform(.payPlayer("alice", amount: 50), by: "alice")
        #expect(session.transactions.count == 1)
        #expect(session.currentState.playerBalances["alice"] == 1500)
        #expect(!sounds.played.contains(.happy))
    }

    @Test func negativeSalaryUpdateIsIgnored() {
        // ibanker.ios#38 E2: a negative salary would persist invisibly
        // (updateSalary is never logged).
        let (store, suite) = makeStore(); defer { store.removePersistentDomain(forName: suite) }
        let session = makeSession(store)
        session.players.append(alice)
        session.perform(.updateSalary(newSalary: -100), by: "alice")
        #expect(session.transactions.isEmpty)
    }

    @Test func resetPlayersClampsNegativeInputs() {
        // ibanker.ios#38 E1: a negative reset lands AFTER the log is cleared —
        // clamp to zero, same as AddNewPlayerView's Save guard.
        let (store, suite) = makeStore(); defer { store.removePersistentDomain(forName: suite) }
        let session = makeSessionWithRoster(store)
        session.resetPlayers(balance: -100, salary: -50)
        for id in ["alice", "bob", "carol"] {
            #expect(session.currentState.playerBalances[id] == 0)
            #expect(session.currentState.playerSalaries[id] == 0)
        }
    }

    @Test func updateSalaryMatchingStoredSalaryIsSkipped() {
        // The ibanker.ios#36 guard: PlayerView re-commits the seeded salary on a
        // focus->blur, so a matching value must append nothing.
        let (store, suite) = makeStore(); defer { store.removePersistentDomain(forName: suite) }
        let session = makeSession(store)
        session.players.append(alice)
        session.perform(.createPlayer(balance: 1500, salary: 200), by: "alice")
        #expect(session.transactions.count == 1)

        session.perform(.updateSalary(newSalary: 200), by: "alice")
        #expect(session.transactions.count == 1)

        session.perform(.updateSalary(newSalary: 300), by: "alice")
        #expect(session.transactions.count == 2)
        #expect(session.currentState.playerSalaries["alice"] == 300)
    }

    // MARK: - derived state and side effects

    @Test func performAppendsTransactionAndDerivesBalance() {
        let (store, suite) = makeStore(); defer { store.removePersistentDomain(forName: suite) }
        let session = makeSession(store)
        session.players.append(alice)
        session.perform(.createPlayer(balance: 1500, salary: 200), by: "alice")
        session.perform(.addMoney(amount: 50), by: "alice")
        #expect(session.currentState.playerBalances["alice"] == 1550)
    }

    @Test func activityDescriptionsMatchIOS() {
        let (store, suite) = makeStore(); defer { store.removePersistentDomain(forName: suite) }
        let session = makeSession(store)
        session.players.append(alice)
        session.players.append(bob)
        session.perform(.createPlayer(balance: 1500, salary: 200), by: "alice")
        session.perform(.createPlayer(balance: 1500, salary: 0), by: "bob")
        session.perform(.collectSalary(amount: 200), by: "alice")
        session.perform(.payPlayer("bob", amount: 150), by: "alice")
        session.perform(.addMoney(amount: 500), by: "alice")
        session.perform(.subtractMoney(amount: 75), by: "bob")
        session.perform(.resetPlayer(balance: 1500, salary: 200), by: "alice")

        #expect(events.events == [
            "Alice joined the game with $1,500 and a $200 salary.",
            "Bob joined the game with $1,500.",
            "Alice collected $200 salary.",
            "Alice sent $150 to Bob.",
            "Alice added $500.",
            "Bob subtracted $75.",
            "Alice was reset to $1,500 and $200 salary.",
        ])
    }

    @Test func updateSalaryIsNotLogged() {
        let (store, suite) = makeStore(); defer { store.removePersistentDomain(forName: suite) }
        let session = makeSession(store)
        session.players.append(alice)
        session.perform(.updateSalary(newSalary: 300), by: "alice")
        #expect(session.transactions.count == 1)
        #expect(events.events.isEmpty)
    }

    @Test func noteReplacesDescriptionAndSuppressesSound() {
        let (store, suite) = makeStore(); defer { store.removePersistentDomain(forName: suite) }
        let session = makeSession(store)
        session.players.append(alice)
        session.perform(.addMoney(amount: 300_000), by: "alice", note: "Alice won the spin!")
        #expect(events.events == ["Alice won the spin!"])
        #expect(sounds.played.isEmpty)
    }

    @Test func soundMapMatchesIOS() {
        let (store, suite) = makeStore(); defer { store.removePersistentDomain(forName: suite) }
        let session = makeSession(store)
        session.players.append(alice)
        session.players.append(bob)
        session.perform(.addMoney(amount: 100), by: "alice")
        session.perform(.collectSalary(amount: 200), by: "alice")
        session.perform(.subtractMoney(amount: 50), by: "alice")
        session.perform(.payPlayer("bob", amount: 25), by: "alice")
        session.perform(.createPlayer(balance: 1500, salary: 200), by: "carol")
        #expect(sounds.played == [.cashRegister, .cashRegister, .coinDrop, .happy])
    }

    @Test func sadSoundQueuedWhenBalanceGoesNegative() {
        let (store, suite) = makeStore(); defer { store.removePersistentDomain(forName: suite) }
        let session = makeSession(store)
        session.players.append(alice)
        session.perform(.createPlayer(balance: 100, salary: 0), by: "alice")
        session.perform(.subtractMoney(amount: 150), by: "alice")
        #expect(sounds.queued == [.sad])
    }

    @Test func sadSoundNotQueuedWhileBalanceStaysNonNegative() {
        let (store, suite) = makeStore(); defer { store.removePersistentDomain(forName: suite) }
        let session = makeSession(store)
        session.players.append(alice)
        session.perform(.createPlayer(balance: 100, salary: 0), by: "alice")
        session.perform(.subtractMoney(amount: 100), by: "alice")
        #expect(sounds.queued.isEmpty)
    }

    // MARK: - roster management

    @Test func hasExchangedMoneyOnlyForTransferParticipants() {
        let (store, suite) = makeStore(); defer { store.removePersistentDomain(forName: suite) }
        let session = makeSessionWithRoster(store)
        session.perform(.payPlayer("bob", amount: 50), by: "alice")
        #expect(session.hasExchangedMoney("alice"))
        #expect(session.hasExchangedMoney("bob"))
        #expect(!session.hasExchangedMoney("carol"))
    }

    @Test func resetPlayersClearsLogAndReseeds() {
        let (store, suite) = makeStore(); defer { store.removePersistentDomain(forName: suite) }
        let session = makeSessionWithRoster(store)
        session.perform(.addMoney(amount: 999), by: "alice")
        session.resetPlayers(balance: 1500, salary: 200)

        #expect(session.transactions.count == 3)
        #expect(session.transactions.allSatisfy { if case .resetPlayer = $0.action { return true } else { return false } })
        for id in ["alice", "bob", "carol"] {
            #expect(session.currentState.playerBalances[id] == 1500)
            #expect(session.currentState.playerSalaries[id] == 200)
        }
        #expect(!session.hasExchangedMoney("alice"))
    }

    @Test func deletePlayersKeepsTransactionsAndRecordsMarker() {
        let (store, suite) = makeStore(); defer { store.removePersistentDomain(forName: suite) }
        let session = makeSessionWithRoster(store)
        session.perform(.payPlayer("bob", amount: 50), by: "alice")
        let transactionCount = session.transactions.count

        session.deletePlayers([carol])

        #expect(session.players.map(\.id) == ["alice", "bob"])
        #expect(session.transactions.count == transactionCount)
        #expect(events.events.last == "Carol was deleted.")
        // Remaining balances stay correct because the log is intact.
        #expect(session.currentState.playerBalances["alice"] == 1450)
        #expect(session.currentState.playerBalances["bob"] == 1550)
    }

    @Test func deleteAllPlayersClearsEverything() {
        let (store, suite) = makeStore(); defer { store.removePersistentDomain(forName: suite) }
        let session = makeSessionWithRoster(store)
        session.deleteAllPlayers()
        #expect(session.players.isEmpty)
        #expect(session.transactions.isEmpty)
        #expect(events.events.last == "All players deleted.")
    }

    @Test func recordGameModeChangeAppendsMarker() {
        let (store, suite) = makeStore(); defer { store.removePersistentDomain(forName: suite) }
        let session = makeSession(store)
        session.recordGameModeChange(.fifteenHundred)
        #expect(events.events == ["Game mode changed to $1500 Balance."])
    }

    @Test func undoLastTransactionRemovesNewest() {
        let (store, suite) = makeStore(); defer { store.removePersistentDomain(forName: suite) }
        let session = makeSession(store)
        session.players.append(alice)
        session.perform(.addMoney(amount: 100), by: "alice")
        session.perform(.addMoney(amount: 50), by: "alice")
        session.undoLastTransaction()
        #expect(session.currentState.playerBalances["alice"] == 100)
    }

    @Test func movePlayerReordersRosterAndPersists() {
        let (store, suite) = makeStore(); defer { store.removePersistentDomain(forName: suite) }
        let session = makeSessionWithRoster(store)
        session.movePlayer(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        #expect(session.players.map(\.id) == ["bob", "carol", "alice"])

        session.saveGame() // iOS persists on scene-phase; the test triggers it
        let relaunched = makeSession(store)
        #expect(relaunched.players.map(\.id) == ["bob", "carol", "alice"])
    }

    @Test func updatePlayerImageSetsClearsAndPersists() {
        let (store, suite) = makeStore(); defer { store.removePersistentDomain(forName: suite) }
        let session = makeSessionWithRoster(store)
        let jpeg = Data([1, 2, 3, 4])

        session.updatePlayerImage("alice", jpeg)
        #expect(session.players.first { $0.id == "alice" }?.imageData == jpeg)

        session.saveGame()
        let relaunched = makeSession(store)
        #expect(relaunched.players.first { $0.id == "alice" }?.imageData == jpeg)

        session.updatePlayerImage("alice", nil)
        #expect(session.players.first { $0.id == "alice" }?.imageData == nil)
    }

    @Test func movePlayerIgnoresOutOfRangeIndices() {
        let (store, suite) = makeStore(); defer { store.removePersistentDomain(forName: suite) }
        let session = makeSessionWithRoster(store)
        session.movePlayer(fromOffsets: IndexSet(integer: 0), toOffset: 5) // toOffset past the end
        session.movePlayer(fromOffsets: IndexSet(integer: 3), toOffset: 1) // fromOffset past the end
        #expect(session.players.map(\.id) == ["alice", "bob", "carol"])
    }

    @Test func onActivitySinkAssignableAfterConstruction() {
        // The Activity Log sink is wired at launch (iOS: modelContext assigned
        // from MainTabView) — assignment must take effect for later performs.
        let (store, suite) = makeStore(); defer { store.removePersistentDomain(forName: suite) }
        let session = GameSession(defaults: store, settings: SettingsStore(store: store), soundPlayer: sounds)
        session.players.append(alice)
        session.perform(.addMoney(amount: 100), by: "alice")
        let lateEvents = ActivityRecorder()
        session.onActivity = { [lateEvents] event, _ in lateEvents.record(event) }
        session.perform(.addMoney(amount: 50), by: "alice")
        #expect(lateEvents.events == ["Alice added $50."])
    }

    // MARK: - persistence

    @Test func gameStateSurvivesAcrossSessions() {
        let (store, suite) = makeStore(); defer { store.removePersistentDomain(forName: suite) }
        let first = makeSessionWithRoster(store)
        first.perform(.addMoney(amount: 50), by: "alice")
        first.saveGame() // iOS persists on scene-phase; the test triggers it

        let second = makeSession(store)
        #expect(second.players == first.players)
        #expect(second.transactions == first.transactions)
        #expect(second.currentState.playerBalances["alice"] == 1550)
    }

    @Test func corruptPersistedDataFallsBackToEmpty() {
        let (store, suite) = makeStore(); defer { store.removePersistentDomain(forName: suite) }
        store.set(Data("not json".utf8), forKey: "gamePlayers")
        store.set(Data("{broken".utf8), forKey: "gameTransactions")
        let session = makeSession(store)
        #expect(session.players.isEmpty)
        #expect(session.transactions.isEmpty)
    }
}
