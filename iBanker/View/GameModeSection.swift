//
//  GameModeSection.swift
//
//  Created by Pete Maiser, Fast Five Products LLC, on 7/7/26.
//  Modified by Claude, Fast Five Products LLC, on 7/31/26.
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

import SwiftUI

/// The "Game Mode Defaults" section — mode picker plus the resulting (or
/// custom) starting balance/salary. Shared by SettingsView and the empty-state
/// "Game Mode" sheet (#31). Place inside a `Form`/`List`.
struct GameModeSection: View {
    // Shared SettingsStore from iBankerApp (#13); inherited by the sheet too.
    @EnvironmentObject private var settings: SettingsStore
    // For logging a mode change to the Activity Log (see the picker binding).
    @EnvironmentObject private var gameSession: GameSession

    // Keyboard focus (#35, reworked twice in #37, Done/Cancel bar in #42):
    // owned here, but a Section can't reach its host's container to pin a
    // bottom bar — so the section publishes the bar for the focused field
    // via KeyboardActionBarPreference, and each host Form (SettingsView and
    // HomeView's Game Mode sheet) renders it with .keyboardActionBarHost().
    private enum Field {
        case balance, salary
    }
    @FocusState private var focusedField: Field?

    // The stored value when a field gained focus — what the bar's Cancel
    // restores (#42). The fields write through to @AppStorage on
    // end-editing commit, so Cancel resigns focus (letting that commit fire)
    // and then puts this snapshot back. One snapshot suffices: only the
    // focused field can be cancelled, and moving focus re-snapshots.
    @State private var valueBeforeEditing: Int = 0

    // The custom values are stored as non-optional Ints (0 = unset), but the
    // fields bind optionals so an unset value shows the placeholder instead
    // of a stuck "0" — matching every other money field (#37). A deliberate
    // consequence: a stored 0 displays as empty, which is equivalent here.
    // (Clearing a field to empty commits nil and unsets it — device-verified
    // at the #42 gate, superseding an earlier note here that claimed the old
    // value redisplayed and 0 had to be typed to unset.)
    private var customBalanceBinding: Binding<Int?> {
        Binding(
            get: { settings.customInitialBalance == 0 ? nil : settings.customInitialBalance },
            set: { settings.customInitialBalance = $0 ?? 0 }
        )
    }
    private var customSalaryBinding: Binding<Int?> {
        Binding(
            get: { settings.customInitialSalary == 0 ? nil : settings.customInitialSalary },
            set: { settings.customInitialSalary = $0 ?? 0 }
        )
    }

    // The bar for the focused field: Done commits (write-through, via the
    // end-editing commit); Cancel restores the snapshot. The id encodes
    // everything the closures capture (field + snapshot), per the
    // preference's staleness contract.
    private var barPreference: KeyboardActionBarPreference? {
        guard let field = focusedField else { return nil }
        let action: KeyboardAction
        switch field {
        case .balance:
            action = KeyboardAction(label: "Done",
                                    cancel: { settings.customInitialBalance = valueBeforeEditing })
        case .salary:
            action = KeyboardAction(label: "Done",
                                    cancel: { settings.customInitialSalary = valueBeforeEditing })
        }
        return KeyboardActionBarPreference(id: "\(field)-\(valueBeforeEditing)",
                                           action: action,
                                           dismiss: { focusedField = nil })
    }

    var body: some View {
        Section("Game Mode Defaults") {
            // Log the mode change (#32) from the picker's set, not the onChange
            // below, so it fires once and only on a user pick: programmatic
            // changes (e.g. Reset Settings) write the store directly and bypass
            // this binding, and only the picker the user actually touched logs —
            // avoiding a duplicate from the other live GameModeSection (Settings
            // tab vs the empty-state sheet).
            Picker("Game Mode", selection: Binding(
                get: { settings.selectedGameMode },
                set: { newMode in
                    guard newMode != settings.selectedGameMode else { return }
                    settings.setSelectedGameMode(newMode)
                    gameSession.recordGameModeChange(newMode)
                }
            )) {
                ForEach(GameMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }

            // Show custom input fields only if "Custom" mode is selected
            if settings.selectedGameMode == .custom {
                HStack {
                    Text("Default Balance")
                    Spacer()
                    TextField("Initial Balance", value: customBalanceBinding, formatter: NumberFormatter.money)
                        .keyboardType(.numberPad)
                        .autocorrectionDisabled()
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .balance)
                }
                HStack {
                    Text("Default Salary")
                    Spacer()
                    TextField("Initial Salary", value: customSalaryBinding, formatter: NumberFormatter.money)
                        .keyboardType(.numberPad)
                        .autocorrectionDisabled()
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .salary)
                }
            } else {
                // Display the default values for the selected non-custom mode
                HStack {
                    Text("Default Balance")
                    Spacer()
                    Text("$\(settings.effectiveDefaultBalance.formatted())")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Default Salary")
                    Spacer()
                    Text("$\(settings.effectiveDefaultSalary.formatted())")
                        .foregroundColor(.secondary)
                }
            }
        }
        .preference(key: KeyboardActionBarPreferenceKey.self, value: barPreference)
        .onChange(of: focusedField) {
            // Snapshot the newly-focused field's stored value for Cancel (#42).
            switch focusedField {
            case .balance: valueBeforeEditing = settings.customInitialBalance
            case .salary: valueBeforeEditing = settings.customInitialSalary
            case nil: break
            }
        }
    }
}


#if DEBUG
#Preview {
    let sampleSettings = SettingsStore()
    let sampleGameSession = GameSession()
    Form {
        GameModeSection()
    }
    .keyboardActionBarHost()
    .environmentObject(sampleSettings)
    .environmentObject(sampleGameSession)
}
#endif
