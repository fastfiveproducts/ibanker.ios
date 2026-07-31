//
//  SettingsStoreTests.swift
//
//  Created by Claude, Fast Five Products LLC, on 7/31/26.
//      Reverse-ported from ibanker.android SettingsStoreTest.kt (#51): locks the
//      mode/spinner coupling and persistence. Names/intent kept aligned with the
//      Android spec.
//
//      Port note: Android injects an InMemoryKeyValueStore; iOS injects an
//      ephemeral UserDefaults suite (the `@AppStorage` store seam added for #51),
//      one per test, so the parallel Swift Testing runner never collides on
//      `.standard`. The Android `setEnabledSpinner`/`setSoundEffects`/`set…`
//      setters map to iBanker's direct `@AppStorage` properties; the one method
//      that carries logic — the mode→spinner coupling — is `setSelectedGameMode`.
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

@MainActor
struct SettingsStoreTests {

    // A fresh, isolated defaults suite per call (parallel-safe); the caller
    // clears it on the way out.
    private func isolatedDefaults() -> (UserDefaults, String) {
        let suite = "test.ibanker.settings.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suite)!, suite)
    }

    @Test func spinnerFollowsModeDefaultOnModeChange() {
        let (defaults, suite) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(store: defaults)
        settings.setSelectedGameMode(.fourHundredK)
        #expect(settings.enabledSpinner == true)
        settings.setSelectedGameMode(.fifteenHundred)
        #expect(settings.enabledSpinner == false)
    }

    @Test func manualSpinnerOverrideSurvivesSameModeSet() {
        // The setter guards on same-value (iOS: the picker binding's guard +
        // onChange only firing on actual change), so re-picking the current mode
        // must not clobber a manual spinner override.
        let (defaults, suite) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(store: defaults)
        settings.setSelectedGameMode(.fourHundredK)
        settings.enabledSpinner = false
        settings.setSelectedGameMode(.fourHundredK)
        #expect(settings.enabledSpinner == false)
    }

    @Test func resetAllSettingsRestoresDefaults() {
        let (defaults, suite) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(store: defaults)
        settings.soundEffects = false
        settings.selectedGameMode = .custom
        settings.customInitialBalance = 777
        settings.customInitialSalary = 55
        settings.enabledSpinner = true

        settings.resetAllSettings()

        #expect(settings.soundEffects == true)
        #expect(settings.selectedGameMode == .fifteenHundred)
        #expect(settings.customInitialBalance == 0)
        #expect(settings.customInitialSalary == 0)
        #expect(settings.enabledSpinner == false)
    }

    @Test func effectiveDefaultsResolveCustomMode() {
        let (defaults, suite) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(store: defaults)
        settings.selectedGameMode = .custom
        settings.customInitialBalance = 2500
        settings.customInitialSalary = 300
        #expect(settings.effectiveDefaultBalance == 2500)
        #expect(settings.effectiveDefaultSalary == 300)

        settings.selectedGameMode = .fifteenHundred
        #expect(settings.effectiveDefaultBalance == 1500)
        #expect(settings.effectiveDefaultSalary == 200)
    }

    @Test func settingsSurviveAcrossInstances() {
        let (defaults, suite) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = SettingsStore(store: defaults)
        first.soundEffects = false
        first.selectedGameMode = .tenK

        let second = SettingsStore(store: defaults)
        #expect(second.soundEffects == false)
        #expect(second.selectedGameMode == .tenK)
    }
}
