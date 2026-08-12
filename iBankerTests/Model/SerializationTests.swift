//
//  SerializationTests.swift
//
//  Created by Claude, Fast Five Products LLC, on 7/31/26.
//      Reverse-ported from ibanker.android SerializationTest.kt (#51): golden
//      fixtures locking the event-log JSON schema that iBanker actually persists
//      (GameSession.saveGame / .init via Codable). Changing any golden here is a
//      schema change and needs a deliberate decision.
//
//      CROSS-PLATFORM NOTE (logged, ADVERSARIAL-FINDINGS / ibanker.ios#9): these
//      goldens are iOS's OWN wire format and deliberately DIVERGE from the
//      Android goldens. iOS uses Swift's synthesized enum Codable — an action
//      encodes as `{"collectSalary":{"amount":200}}` (case-name wrapper; the
//      unlabeled payPlayer id serializes as `"_0"`) and a timestamp as a Date
//      double (seconds since the 2001 reference date) — whereas the Android
//      suite pins the PROPOSED #9 interchange schema (`{"type":…}` discriminator,
//      epoch-millis). "iOS is the schema source" holds for the field NAMES and
//      model, not this concrete encoding. The encoder emits keys in an
//      unspecified order (no .sortedKeys in the app), so the golden ENCODE
//      assertions here pin `.sortedKeys` output for determinism; on-disk order is
//      unspecified but decodes identically (order-independent).
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

struct SerializationTests {

    // Deterministic encoder for the golden ENCODE assertions (the app's own
    // encoder leaves key order unspecified; sorting makes the goldens stable).
    private let sortedEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private func json(_ value: some Encodable) -> String {
        String(data: try! sortedEncoder.encode(value), encoding: .utf8)!
    }

    // MARK: - Golden fixtures (iOS-native schema)

    @Test func goldenTransactionCollectSalary() {
        let tx = GameTransaction(
            id: "t1",
            timestamp: Date(timeIntervalSinceReferenceDate: 0),
            playerID: "p1",
            action: .collectSalary(amount: 200)
        )
        #expect(json(tx) == #"{"action":{"collectSalary":{"amount":200}},"id":"t1","playerID":"p1","timestamp":0}"#)
    }

    @Test func goldenTransactionPayPlayerWithNote() {
        let tx = GameTransaction(
            id: "t2",
            timestamp: Date(timeIntervalSinceReferenceDate: 1),
            playerID: "p1",
            action: .payPlayer("p2", amount: 50),
            note: "rent"
        )
        #expect(json(tx) == #"{"action":{"payPlayer":{"_0":"p2","amount":50}},"id":"t2","note":"rent","playerID":"p1","timestamp":1}"#)
    }

    @Test func goldenPlayerMinimal() {
        // Nil optionals are omitted — players persisted before photos existed
        // decode unchanged, and the wire shape stays lean.
        let player = Player(id: "p1", name: "Alice", token: "dog", isLocalOnly: false, salary: 200)
        #expect(json(player) == #"{"id":"p1","isLocalOnly":false,"name":"Alice","salary":200,"token":"dog"}"#)
    }

    @Test func goldenPlayerWithImageData() {
        let player = Player(id: "p1", name: "Alice", token: "dog", isLocalOnly: false, salary: 200, imageData: Data([1, 2, 3]))
        #expect(json(player) == #"{"id":"p1","imageData":"AQID","isLocalOnly":false,"name":"Alice","salary":200,"token":"dog"}"#)
    }

    // MARK: - Round trips (through the app's own Codable)

    @Test func allActionTypesRoundTrip() {
        let actions: [GameAction] = [
            .collectSalary(amount: 200),
            .payPlayer("p2", amount: 50),
            .addMoney(amount: 100),
            .subtractMoney(amount: 30),
            .updateSalary(newSalary: 300),
            .resetPlayer(balance: 1500, salary: 200),
            .createPlayer(balance: 400_000, salary: 0),
            .custom(description: "Alice won the spin!"),
        ]
        let transactions = actions.enumerated().map { i, action in
            GameTransaction(id: "t\(i)", timestamp: Date(timeIntervalSinceReferenceDate: TimeInterval(i)), playerID: "p1", action: action)
        }
        let encoded = try! JSONEncoder().encode(transactions)
        let decoded = try! JSONDecoder().decode([GameTransaction].self, from: encoded)
        #expect(decoded == transactions)
    }

    @Test func playerWithImageDataRoundTrips() {
        let player = Player(
            id: "p1", name: "Alice", token: "dog", isLocalOnly: true,
            authProviderID: "google:123", sheetRowIndex: 4, salary: 200,
            imageData: Data((0..<64).map { UInt8($0) })
        )
        let encoded = try! JSONEncoder().encode(player)
        let decoded = try! JSONDecoder().decode(Player.self, from: encoded)
        #expect(decoded == player)
    }

    // MARK: - Forward compatibility

    @Test func decodeIgnoresUnknownKeys() {
        // A future schema revision (e.g. ibanker.ios#9's device-provenance field)
        // must not break older readers — JSONDecoder ignores unknown keys.
        let json = #"{"id":"t1","timestamp":1,"playerID":"p1","deviceID":"future","action":{"addMoney":{"amount":5}}}"#
        let decoded = try! JSONDecoder().decode(GameTransaction.self, from: Data(json.utf8))
        #expect(decoded.id == "t1")
        #expect(decoded.action == .addMoney(amount: 5))
    }

    @Test func omittedOptionalsDecodeToNil() {
        let json = #"{"id":"p1","name":"Alice","token":"dog","isLocalOnly":false,"salary":200}"#
        let decoded = try! JSONDecoder().decode(Player.self, from: Data(json.utf8))
        #expect(decoded.authProviderID == nil)
        #expect(decoded.sheetRowIndex == nil)
        #expect(decoded.imageData == nil)
    }
}
