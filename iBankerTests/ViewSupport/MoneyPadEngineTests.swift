//
//  MoneyPadEngineTests.swift
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

//  Pins the pure key engine behind the iPad money pad (#68): every key
//  reaching a field routes through MoneyPadEngine.apply — pad taps and
//  hardware keystrokes alike — so these transforms ARE the entry behavior.

import Testing
@testable import iBanker

struct MoneyPadEngineTests {

    @Test("digits append in order")
    func digitsAppend() {
        var digits = ""
        for d in [1, 5, 0] {
            digits = MoneyPadEngine.apply(.digit(d), to: digits)
        }
        #expect(digits == "150")
    }

    @Test("a leading zero is allowed and parses to the typed value")
    func leadingZeroParses() {
        let digits = MoneyPadEngine.apply(.digit(5), to: "0")
        #expect(digits == "05")
        #expect(Int(digits) == 5)
    }

    @Test("backspace drops the last digit; empty stays empty")
    func backspace() {
        #expect(MoneyPadEngine.apply(.backspace, to: "150") == "15")
        #expect(MoneyPadEngine.apply(.backspace, to: "") == "")
    }

    @Test("entry caps at maxDigits — a further digit is a no-op")
    func digitCap() {
        let atCap = String(repeating: "9", count: MoneyPadEngine.maxDigits)
        #expect(MoneyPadEngine.apply(.digit(1), to: atCap) == atCap)
    }

    @Test("the cap leaves Int parsing safe")
    func capParsesAsInt() {
        let atCap = String(repeating: "9", count: MoneyPadEngine.maxDigits)
        #expect(Int(atCap) != nil)
    }

    @Test("an out-of-range digit key is a no-op")
    func outOfRangeDigit() {
        #expect(MoneyPadEngine.apply(.digit(10), to: "5") == "5")
        #expect(MoneyPadEngine.apply(.digit(-1), to: "5") == "5")
    }

    // MARK: - #6 magnitude keys (iPad half)

    @Test("K appends three zeros — ×1,000 on integer digits")
    func thousandKey() {
        #expect(MoneyPadEngine.apply(.thousand, to: "15") == "15000")
    }

    @Test("M appends six zeros — '15' then M is the issue's 15,000,000")
    func millionKey() {
        let digits = MoneyPadEngine.apply(.million, to: "15")
        #expect(digits == "15000000")
        #expect(Int(digits) == 15_000_000)
    }

    @Test("K and M are no-ops on an empty entry — nothing to multiply")
    func magnitudeOnEmpty() {
        #expect(MoneyPadEngine.apply(.thousand, to: "") == "")
        #expect(MoneyPadEngine.apply(.million, to: "") == "")
    }

    @Test("a magnitude key that would burst the cap is a whole-key no-op")
    func magnitudeRespectsCap() {
        let nearCap = String(repeating: "9", count: MoneyPadEngine.maxDigits - 2)
        #expect(MoneyPadEngine.apply(.thousand, to: nearCap) == nearCap)
        #expect(MoneyPadEngine.apply(.million, to: nearCap) == nearCap)
        // And one that fits still lands: 6 digits + K = 9 digits, under 12.
        #expect(MoneyPadEngine.apply(.thousand, to: "123456") == "123456000")
    }
}
