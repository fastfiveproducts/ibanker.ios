//
//  make-screenshot-seed.swift — demo-game seed generator for screenshot capture (#55)
//
//  Created by Claude, Fast Five Products LLC, on 7/30/26.
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
//  Compiled BY tools/generate-screenshots.sh together with the app's own model
//  sources (Player, GameAction, GameTransaction), so the emitted JSON is
//  byte-compatible with what GameSession.init() decodes — format fidelity by
//  construction, never by hand-maintained JSON.
//
//  Demo content mirrors the ibanker.android generated sets (the fleet content
//  model, owner directive 2026-07-30): players Maya/Sam/Jordan/Ari on the
//  $1500/$200 mode; joins, two salary collections, add $50, subtract $100,
//  send $75 — derived balances $1,700 / $1,550 / $1,475 / $1,625. Token names
//  (Car/Dog/Wheelbarrow/Boot) are the one carry from the v2.0.0 published
//  sets: PlayerView always renders the "Token:" line, and tokens showcase a
//  real app feature. Timestamps are 9:31–9:40 AM today so the Activity Log
//  reads consistently under the 9:41 status-bar override.
//
//  Output: two shell-assignable lines, hex-encoded for `defaults write -data`:
//    GAMEPLAYERS_HEX=<hex of the players JSON>
//    GAMETRANSACTIONS_HEX=<hex of the transactions JSON>
//

import Foundation

let calendar = Calendar.current
let today = calendar.startOfDay(for: Date())

func at(_ hour: Int, _ minute: Int) -> Date {
    guard let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) else {
        fatalError("could not compose demo timestamp \(hour):\(minute)")
    }
    return date
}

let maya   = "DEMO-P1-MAYA"
let sam    = "DEMO-P2-SAM"
let jordan = "DEMO-P3-JORDAN"
let ari    = "DEMO-P4-ARI"

let players = [
    Player(id: maya,   name: "Maya",   token: "Car",         isLocalOnly: true, salary: 200),
    Player(id: sam,    name: "Sam",    token: "Dog",         isLocalOnly: true, salary: 200),
    Player(id: jordan, name: "Jordan", token: "Wheelbarrow", isLocalOnly: true, salary: 200),
    Player(id: ari,    name: "Ari",    token: "Boot",        isLocalOnly: true, salary: 200),
]

let transactions = [
    GameTransaction(id: "DEMO-T1", timestamp: at(9, 31), playerID: maya,
                    action: .createPlayer(balance: 1500, salary: 200)),
    GameTransaction(id: "DEMO-T2", timestamp: at(9, 32), playerID: sam,
                    action: .createPlayer(balance: 1500, salary: 200)),
    GameTransaction(id: "DEMO-T3", timestamp: at(9, 33), playerID: jordan,
                    action: .createPlayer(balance: 1500, salary: 200)),
    GameTransaction(id: "DEMO-T4", timestamp: at(9, 34), playerID: ari,
                    action: .createPlayer(balance: 1500, salary: 200)),
    GameTransaction(id: "DEMO-T5", timestamp: at(9, 36), playerID: maya,
                    action: .collectSalary(amount: 200)),
    GameTransaction(id: "DEMO-T6", timestamp: at(9, 37), playerID: ari,
                    action: .collectSalary(amount: 200)),
    GameTransaction(id: "DEMO-T7", timestamp: at(9, 38), playerID: sam,
                    action: .addMoney(amount: 50)),
    GameTransaction(id: "DEMO-T8", timestamp: at(9, 39), playerID: jordan,
                    action: .subtractMoney(amount: 100)),
    GameTransaction(id: "DEMO-T9", timestamp: at(9, 40), playerID: ari,
                    action: .payPlayer(jordan, amount: 75)),
]

let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return encoder
}()

func hex(_ data: Data) -> String {
    data.map { String(format: "%02x", $0) }.joined()
}

// Compiled alongside the model sources (not as `main.swift`), so top-level
// statements are unavailable — @main carries the entry point instead.
@main
enum MakeScreenshotSeed {
    static func main() {
        do {
            let playersData = try encoder.encode(players)
            let transactionsData = try encoder.encode(transactions)
            print("GAMEPLAYERS_HEX=\(hex(playersData))")
            print("GAMETRANSACTIONS_HEX=\(hex(transactionsData))")
        } catch {
            FileHandle.standardError.write(Data("seed encoding failed: \(error)\n".utf8))
            exit(1)
        }
    }
}
