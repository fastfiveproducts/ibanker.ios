//
//  GameSession.swift
//
//  Created by Elizabeth Maiser, Fast Five Products LLC, on 7/23/25.
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


import Foundation
import SwiftUI
import SwiftData

class GameSession: ObservableObject, DebugPrintable {
    private let defaults: UserDefaults

    @Published var players: [Player]
    @Published var transactions: [GameTransaction]

    /// The single shared SettingsStore (#13): created here and injected into
    /// the environment by iBankerApp, so session logic and views read the same
    /// instance. Previews may swap in their own.
    var settings: SettingsStore

    /// Sound side effects run through this seam (default `.shared`); tests
    /// inject a recording double. See `GameSoundPlaying`.
    let soundPlayer: GameSoundPlaying

    /// Optional ordered activity observer (default nil). Production feeds the
    /// Activity Log via `modelContext`; this hook lets tests capture the same
    /// human-readable strings in call order. Assignable after construction.
    var onActivity: ((String, Date) -> Void)?

    // SwiftData context for the Activity Log, injected from the view layer (see
    // MainTabView). Optional because GameSession is created before the SwiftData
    // container exists in the environment.
    var modelContext: ModelContext?

    var currentState: GameState {
        GameStateReducer.reduce(players: players, transactions: transactions)
    }
    
    @Published var currentPlayerID: String? // Future: pass-the-phone mode

    // Future: synced/cloud game sessions
    var gameSessionID: String?
    var isSyncedGame: Bool { gameSessionID != nil }
    
    init(defaults: UserDefaults = .standard,
         settings: SettingsStore = SettingsStore(),
         soundPlayer: GameSoundPlaying = SoundPlayer.shared) {
        self.defaults = defaults
        self.settings = settings
        self.soundPlayer = soundPlayer

        // Two-phase init: 'self' isn't available yet, so decode via the
        // injected store directly (production passes `.standard`).
        let initialPlayers = (try? JSONDecoder().decode([Player].self, from: defaults.data(forKey: "gamePlayers") ?? Data())) ?? []
        let initialTransactions = (try? JSONDecoder().decode([GameTransaction].self, from: defaults.data(forKey: "gameTransactions") ?? Data())) ?? []

        self.players = initialPlayers
        self.transactions = initialTransactions
    }
    
    func saveGame() {
        if let encodedPlayers = try? JSONEncoder().encode(players) {
            defaults.set(encodedPlayers, forKey: "gamePlayers")
            debugprint("Players saved successfully!")
        }

        if let encodedTransactions = try? JSONEncoder().encode(transactions) {
            defaults.set(encodedTransactions, forKey: "gameTransactions")
            debugprint("Transactions saved successfully!")
        }
    }
    
    // Add a transaction. An optional note is stored on the transaction and,
    // when present, replaces the generated Activity Log sentence (e.g. the
    // spinner's "won the spin!" line).
    func perform(_ action: GameAction, by playerID: String, note: String? = nil) {
        // Invalid and no-op actions do nothing — no transaction, no Activity
        // Log entry, no sound. Money movement with no dollars was creating
        // noisy zero-dollar transactions; a self-pay would replay as a lost
        // amount (#38 B2, unreachable from the UI); a negative salary — e.g.
        // a hardware-keyboard minus past the number pad (#38 E2) — would
        // persist invisibly (updateSalary is never logged); and salary
        // updates matching the stored salary (PlayerView re-commits the
        // seeded value on every visit, #36) were pure event-log growth.
        let stateBefore = currentState
        switch action {
        case .addMoney(let amount), .subtractMoney(let amount),
             .collectSalary(let amount):
            guard amount > 0 else { return }
        case .payPlayer(let recipientID, let amount):
            guard amount > 0, recipientID != playerID else { return }
        case .updateSalary(let newSalary):
            guard newSalary >= 0,
                  stateBefore.playerSalaries[playerID] != newSalary else { return }
        case .resetPlayer, .createPlayer, .custom:
            break
        }

        let balanceBefore = stateBefore.playerBalances[playerID] ?? 0
        let tx = GameTransaction(
            id: UUID().uuidString,
            timestamp: Date(),
            playerID: playerID,
            action: action,
            note: note
        )
        transactions.append(tx)
        logActivity(for: action, by: playerID, at: tx.timestamp, note: note)
        // Actions carrying a custom note are specialized flows (e.g. the
        // spinner award) whose caller owns the sound — otherwise the win
        // sound and the generic money sound would overlap.
        if note == nil {
            playSound(for: action, by: playerID, balanceBefore: balanceBefore)
        }
    }

    // MARK: - Sound Effects
    // Like the Activity Log, sounds are a derived side effect of perform —
    // the sound-to-event map matches v1.3.0 (see SoundPlayer.swift).
    // Reset-players plays its (single) shake sound at the Settings level, not
    // here, so resetting N players doesn't play N sounds.
    private func playSound(for action: GameAction, by playerID: String, balanceBefore: Int) {
        switch action {
        case .addMoney, .collectSalary:
            soundPlayer.play(.cashRegister)
        case .subtractMoney:
            soundPlayer.play(.coinDrop)
        case .payPlayer:
            soundPlayer.play(.happy)
        case .updateSalary, .resetPlayer, .createPlayer, .custom:
            break
        }

        // When a money-out action takes the acting player's balance from
        // non-negative to negative, follow with the sad sound (queued so it
        // plays after the action's own sound).
        switch action {
        case .subtractMoney, .payPlayer:
            let balanceAfter = currentState.playerBalances[playerID] ?? 0
            if balanceBefore >= 0 && balanceAfter < 0 {
                soundPlayer.playQueued(.sad)
            }
        default:
            break
        }
    }

    // MARK: - Activity Log
    // The Activity Log is a derived side effect of the transaction log: each
    // performed action is also recorded as a human-readable ActivityLogEntry in
    // SwiftData. `perform` stays the single source of truth — the log is never a
    // second source of state.
    private func logActivity(for action: GameAction, by playerID: String, at timestamp: Date, note: String?) {
        guard let description = note ?? activityDescription(for: action, by: playerID) else { return }
        onActivity?(description, timestamp)
        modelContext?.insert(ActivityLogEntry(description, timestamp: timestamp))
    }

    private func playerName(for id: String) -> String {
        players.first(where: { $0.id == id })?.name ?? "A player"
    }

    // Returns a human-readable sentence for the action, or nil to skip logging.
    // `updateSalary` is intentionally not logged: the salary field syncs on every
    // keystroke, which would flood the log.
    private func activityDescription(for action: GameAction, by playerID: String) -> String? {
        let name = playerName(for: playerID)
        switch action {
        case .collectSalary(let amount):
            return "\(name) collected $\(amount.formatted()) salary."
        case .payPlayer(let recipientID, let amount):
            return "\(name) sent $\(amount.formatted()) to \(playerName(for: recipientID))."
        case .addMoney(let amount):
            return "\(name) added $\(amount.formatted())."
        case .subtractMoney(let amount):
            return "\(name) subtracted $\(amount.formatted())."
        case .resetPlayer(let balance, let salary):
            return "\(name) was reset to $\(balance.formatted()) and $\(salary.formatted()) salary."
        case .createPlayer(let balance, let salary):
            return salary > 0
                ? "\(name) joined the game with $\(balance.formatted()) and a $\(salary.formatted()) salary."
                : "\(name) joined the game with $\(balance.formatted())."
        case .updateSalary:
            return nil
        case .custom(let description):
            return description
        }
    }
    
    // MARK: - Roster Management
    // Single-delete keeps the transaction log intact (so other balances stay
    // correct) and appends an Activity Log marker. The whole-roster resets —
    // Reset Players (clear + re-seed to defaults) and Delete All Players (clear,
    // no players) — clear the log, since no surviving balance depends on it.

    /// True if the player has sent or received a transfer. Locks single-delete
    /// once a player is active — a deliberate guard, not an integrity requirement
    /// (deletion keeps all transactions either way). Reset Players clears the
    /// log, so a reset naturally unlocks everyone.
    func hasExchangedMoney(_ playerID: String) -> Bool {
        transactions.contains { tx in
            if case .payPlayer(let recipientID, _) = tx.action {
                return tx.playerID == playerID || recipientID == playerID
            }
            return false
        }
    }

    /// Remove players (matched by id), appending a deletion marker per player.
    /// Transactions are left untouched so remaining balances stay correct.
    func deletePlayers(_ playersToDelete: [Player]) {
        let ids = Set(playersToDelete.map { $0.id })
        guard !ids.isEmpty else { return }
        let removedNames = players.filter { ids.contains($0.id) }.map { $0.name }
        players.removeAll { ids.contains($0.id) }
        for name in removedNames {
            recordActivity("\(name.isEmpty ? "A player" : name) was deleted.")
        }
    }

    /// Reorder the roster (drives HomeView's edit-mode `.onMove`). Out-of-range
    /// offsets are ignored so a stale index can't trap; persistence follows the
    /// scene-phase save, like every roster mutation.
    func movePlayer(fromOffsets source: IndexSet, toOffset destination: Int) {
        guard source.allSatisfy({ players.indices.contains($0) }),
              (0...players.count).contains(destination) else { return }
        players.move(fromOffsets: source, toOffset: destination)
    }

    /// Set or clear a player's photo (drives PlayerView's photo picker); a
    /// no-op if the id isn't in the roster.
    func updatePlayerImage(_ playerID: String, _ imageData: Data?) {
        guard let idx = players.firstIndex(where: { $0.id == playerID }) else { return }
        players[idx].imageData = imageData
    }

    /// Edit a player's name/token after first save (drives PlayerView's edit
    /// sheet, #67) — a DIRECT attribute update per the photo precedent above:
    /// identity is stored Player state, only money is derived by replaying
    /// the log, so an identity edit stays out of the event log (shape adopted
    /// from the Android twin, ibanker.android#22). Guards, in order: unknown
    /// id no-ops (a Save for a player deleted out from under the detail pane
    /// must not resurrect them), a blank name is refused here in the model so
    /// no caller can bypass the creation rule, and an edit that changes
    /// nothing neither saves nor logs. A RENAME appends an Activity marker
    /// (older entries materialized the old name at write time — the marker
    /// keeps the log readable across the change); a token-only edit stays
    /// silent, like a photo.
    func updatePlayerIdentity(_ playerID: String, name: String, token: String) {
        guard let idx = players.firstIndex(where: { $0.id == playerID }) else { return }
        let newName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let newToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty else { return }
        let oldName = players[idx].name
        let nameChanged = newName != oldName
        let tokenChanged = newToken != players[idx].token
        guard nameChanged || tokenChanged else { return }
        players[idx].name = newName
        players[idx].token = newToken
        if nameChanged {
            recordActivity("\(oldName.isEmpty ? "A player" : oldName) is now \(newName).")
        }
    }

    /// Reset every player to the given defaults. Clears the transaction log and
    /// re-seeds each player, so a reset is a genuine fresh start (and a natural
    /// compaction point) — safe because every balance is being reset anyway. The
    /// Activity Log keeps the per-player reset entries. Inputs are clamped to
    /// >= 0 (#38 E1): Custom-mode defaults accept a hardware-keyboard/paste
    /// negative, and a negative reset lands AFTER the log is cleared — no way
    /// back. Same guard AddNewPlayerView applies at Save.
    func resetPlayers(balance: Int, salary: Int) {
        let balance = max(0, balance)
        let salary = max(0, salary)
        transactions.removeAll()
        for player in players {
            perform(.resetPlayer(balance: balance, salary: salary), by: player.id)
        }
    }

    /// Remove every player and clear the transaction log for a fresh start
    /// (safe — no players remain to corrupt). The Activity Log is kept, with a
    /// marker appended.
    func deleteAllPlayers() {
        guard !players.isEmpty else { return }
        players.removeAll()
        transactions.removeAll()
        recordActivity("All players deleted.")
    }

    /// Append an Activity Log entry not backed by a transaction (e.g. a roster
    /// deletion marker) — presentation only, never a source of derived state.
    private func recordActivity(_ description: String) {
        let timestamp = Date()
        onActivity?(description, timestamp)
        modelContext?.insert(ActivityLogEntry(description, timestamp: timestamp))
    }

    /// Record a game-mode change to the Activity Log (#32) — a settings change,
    /// not a transaction, so it's a standalone marker like a roster deletion.
    func recordGameModeChange(_ mode: GameMode) {
        recordActivity("Game mode changed to \(mode.rawValue).")
    }

    /// Future: undo — unwired (no callers yet). A real implementation must
    /// also reconcile the Activity Log, which this does not.
    func undoLastTransaction() {
        if !transactions.isEmpty {
            transactions.removeLast()
        }
    }
}


#if DEBUG
// MARK: - Screenshot-Capture Support
extension GameSession {
    /// Screenshot-capture mode (#55): derive the Activity Log from a
    /// pre-seeded transaction log. Capture runs seed `gamePlayers` /
    /// `gameTransactions` through the app's own persistence (see
    /// tools/generate-screenshots.sh), bypassing `perform(...)` — so the log
    /// rows it would have inserted as a side effect are replayed here once,
    /// with each transaction's own timestamp. No-ops unless the log is empty,
    /// keeping relaunches between captures idempotent.
    func seedActivityLogFromTransactions() {
        guard let modelContext else { return }
        let count = (try? modelContext.fetchCount(FetchDescriptor<ActivityLogEntry>())) ?? 0
        guard count == 0 else { return }
        for transaction in transactions {
            guard let description = transaction.note
                    ?? activityDescription(for: transaction.action, by: transaction.playerID)
            else { continue }
            modelContext.insert(ActivityLogEntry(description, timestamp: transaction.timestamp))
        }
    }
}
#endif
