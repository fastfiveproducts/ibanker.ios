//
//  SettingsStore.swift
//
//  Created by Elizabeth Maiser, Fast Five Products LLC, on 7/5/25.
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


import Foundation
import SwiftUI

// Shared by the @AppStorage property and the play-time accessor below.
private let soundEffectsKey = "soundEffects"

class SettingsStore: ObservableObject {
    @AppStorage(soundEffectsKey) var soundEffects = true

    /// For callers outside the SwiftUI environment (e.g. SoundPlayer) that need
    /// the latest value at play time.
    static var soundEffectsEnabled: Bool {
        UserDefaults.standard.object(forKey: soundEffectsKey) as? Bool ?? true
    }

    // Game Mode settings.
    @AppStorage("selectedGameMode") var selectedGameMode: GameMode = .fifteenHundred
    @AppStorage("customInitialBalance") var customInitialBalance: Int = 0
    @AppStorage("customInitialSalary") var customInitialSalary: Int = 0

    /// Spin-to-Win spinner (#21): follows the mode default when the mode
    /// changes (see `setSelectedGameMode`), with a manual override Toggle in
    /// Settings.
    @AppStorage("enabledSpinner") var enabledSpinner = false

    /// Inject a store for tests (an ephemeral suite); production uses
    /// `.standard`, so `SettingsStore()` behaves exactly as before.
    init(store: UserDefaults = .standard) {
        _soundEffects = AppStorage(wrappedValue: true, soundEffectsKey, store: store)
        _selectedGameMode = AppStorage(wrappedValue: .fifteenHundred, "selectedGameMode", store: store)
        _customInitialBalance = AppStorage(wrappedValue: 0, "customInitialBalance", store: store)
        _customInitialSalary = AppStorage(wrappedValue: 0, "customInitialSalary", store: store)
        _enabledSpinner = AppStorage(wrappedValue: false, "enabledSpinner", store: store)
    }

    var effectiveDefaultBalance: Int {
        if let defaults = selectedGameMode.defaults {
            return defaults.initialBalance
        } else { // Custom mode
            return customInitialBalance
        }
    }

    var effectiveDefaultSalary: Int {
        if let defaults = selectedGameMode.defaults {
            return defaults.initialSalary
        } else { // Custom mode
            return customInitialSalary
        }
    }
    
    /// Set the game mode, following the mode's default spinner state on an
    /// actual change (the coupling formerly in GameModeSection.onChange).
    /// Re-selecting the current mode is a no-op, preserving a manual spinner
    /// override.
    func setSelectedGameMode(_ mode: GameMode) {
        guard mode != selectedGameMode else { return }
        selectedGameMode = mode
        enabledSpinner = mode.defaultSpinnerOn
    }

    func resetAllSettings() {
        soundEffects = true
        selectedGameMode = .fifteenHundred
        customInitialBalance = 0 // Reset custom values
        customInitialSalary = 0
        enabledSpinner = selectedGameMode.defaultSpinnerOn
    }
}
