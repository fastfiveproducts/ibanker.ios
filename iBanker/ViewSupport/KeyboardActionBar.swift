//
//  KeyboardActionBar.swift
//
//  Created by Claude, Fast Five Products LLC, on 7/9/26.
//  Modified by Claude, Fast Five Products LLC, on 9/7/26.
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

/// What the action bar shows and does for the focused field.
/// The trailing button always dismisses the keyboard; `apply` adds the
/// field's action (e.g. perform a money change) so accepting an amount is
/// one tap (#42). `cancel`, when present, adds a leading Cancel button that
/// discards the pending edit instead of applying it.
struct KeyboardAction {
    let label: String                // "Add" / "Subtract" / "Send" / "Done"
    var tint: Color? = nil           // e.g. Add green, Subtract red (#42)
    var isEnabled: Bool = true       // e.g. Send disabled until a player is picked
    var cancel: (() -> Void)? = nil  // nil → no Cancel button
    var apply: (() -> Void)? = nil   // nil → dismiss-only

    /// Dismiss-only, no Cancel — for fields whose value applies elsewhere
    /// (live-sync salary, Add Player's Save button).
    static let done = KeyboardAction(label: "Done")
}

/// A contextual action bar pinned above the keyboard — one-tap
/// Add/Subtract/Send with Cancel, or plain Done (#35/#42). (#6's K/M keys
/// were once sketched as bar buttons here; they landed as KEYS on the iPad
/// money pad instead — see MoneyField.swift. The bar itself is unchanged.)
///
/// This is a `safeAreaInset(edge: .bottom)` bar gated on the screen's
/// focused field — deliberately NOT a `.toolbar(placement: .keyboard)`
/// accessory. The v1 accessory (#35, in-cell placement rules #37) was
/// retired in #42 after device testing hit the known-broken plumbing behind
/// `placement: .keyboard`: items intermittently never render in tab-hosted
/// Forms (Apple-acknowledged, "no supported workaround" — FB13209435,
/// FB15205988), the accessory's height is missing from keyboard-avoidance
/// math so it covered the focused row (iOS 26 FB22938104), and collapsing
/// accessory content mid-dismissal fed a stuck keyboard-sized ghost panel
/// (iOS 26 FB20749624). A safe-area bar has none of those failure modes:
/// it is ordinary view content (always mounts), its height participates in
/// layout (the focused row scrolls above it by construction), and the
/// system number pad itself is untouched (still no custom keyboard, #6).
/// With a hardware keyboard (no software keyboard) the bar sits above the
/// tab bar — visible and tappable, unlike the old accessory.
///
/// Button ordering (empirical, from the in-row action buttons the bar
/// replaced): clear focus FIRST — ending editing commits the typed text to
/// the field's binding — then run `apply`/`cancel`, so `apply` reads the
/// just-committed value and `cancel`'s clear/restore can't be resurrected
/// by a late re-commit.
///
/// Attachment:
/// - A screen that owns its fields' `@FocusState` applies
///   `.keyboardActionBar(focus:action:)` once, on the screen's
///   Form/List/container itself.
/// - A shared child section (e.g. GameModeSection) publishes a
///   `KeyboardActionBarPreference` instead, and each HOST container applies
///   `.keyboardActionBarHost()` — see those declarations below.
/// Breathing room between the focused row and the bar: keyboard avoidance
/// otherwise seats the row flush against the inset, clipping the row's
/// bottom edge (tuned on device at the #42 gate — 8 still clipped slightly).
private let keyboardActionBarSpacing: CGFloat = 12

private struct KeyboardActionBarView: View {
    let action: KeyboardAction
    let dismiss: () -> Void

    var body: some View {
        HStack {
            if let cancel = action.cancel {
                Button("Cancel") {
                    dismiss()
                    cancel()
                }
            }
            Spacer()
            Button(action.label) {
                dismiss()
                action.apply?()
            }
            .fontWeight(.semibold)
            .tint(action.tint)
            .disabled(!action.isEnabled)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

private struct KeyboardActionBarModifier<Field: Hashable>: ViewModifier {
    var focus: FocusState<Field?>.Binding
    // The focused field is passed explicitly rather than read from `focus`
    // here: the host's body re-evaluates on every focus change and rebuilds
    // this modifier, guaranteeing the bar tracks the field.
    let field: Field?
    let action: (Field) -> KeyboardAction

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: keyboardActionBarSpacing) {
                if let field {
                    KeyboardActionBarView(action: action(field)) {
                        focus.wrappedValue = nil
                    }
                }
            }
    }
}

extension View {
    /// Attach the contextual action bar to a screen's Form/List/container
    /// (see KeyboardActionBarView's notes).
    func keyboardActionBar<Field: Hashable>(
        focus: FocusState<Field?>.Binding,
        action: @escaping (Field) -> KeyboardAction
    ) -> some View {
        modifier(KeyboardActionBarModifier(focus: focus,
                                           field: focus.wrappedValue,
                                           action: action))
    }

    /// Dismiss-only convenience: a plain Done bar for every field
    /// (#35's original behavior).
    func keyboardDoneBar<Field: Hashable>(focus: FocusState<Field?>.Binding) -> some View {
        keyboardActionBar(focus: focus) { _ in .done }
    }
}

// MARK: - Preference bridge for shared child sections

/// Published by a child section that owns its own `@FocusState` (e.g.
/// GameModeSection, shared by two host Forms) so the HOST can render the
/// bar: `safeAreaInset` only works on the screen's container, which the
/// section cannot reach. Equality is by `id` — the publisher must encode
/// every semantic its closures capture (focused field, snapshot values,
/// enabled state) so a stale bar is never kept.
struct KeyboardActionBarPreference: Equatable {
    let id: String
    let action: KeyboardAction
    let dismiss: () -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

struct KeyboardActionBarPreferenceKey: PreferenceKey {
    static let defaultValue: KeyboardActionBarPreference? = nil
    static func reduce(value: inout KeyboardActionBarPreference?,
                       nextValue: () -> KeyboardActionBarPreference?) {
        value = value ?? nextValue()
    }
}

private struct KeyboardActionBarHost: ViewModifier {
    @State private var bar: KeyboardActionBarPreference? = nil

    func body(content: Content) -> some View {
        content
            .onPreferenceChange(KeyboardActionBarPreferenceKey.self) { bar = $0 }
            .safeAreaInset(edge: .bottom, spacing: keyboardActionBarSpacing) {
                if let bar {
                    KeyboardActionBarView(action: bar.action, dismiss: bar.dismiss)
                }
            }
    }
}

extension View {
    /// Render the action bar published by a child section via
    /// `KeyboardActionBarPreferenceKey`. Apply once, on the host's
    /// Form/List/container.
    func keyboardActionBarHost() -> some View {
        modifier(KeyboardActionBarHost())
    }
}


#if DEBUG
private struct KeyboardActionBarPreview: View {
    private enum Field { case amount, other }
    @FocusState private var focusedField: Field?
    @State private var amount: Int? = nil
    @State private var other: Int? = nil
    @State private var applied = 0

    var body: some View {
        Form {
            LabeledContent("Applied") { Text("$\(applied)") }
            TextField("Enter Amount", value: $amount, format: .number)
                .keyboardType(.numberPad)
                .focused($focusedField, equals: .amount)
            TextField("Done-only field", value: $other, format: .number)
                .keyboardType(.numberPad)
                .focused($focusedField, equals: .other)
        }
        .keyboardActionBar(focus: $focusedField) { field in
            switch field {
            case .amount:
                KeyboardAction(label: "Add",
                               tint: .green,
                               cancel: { amount = nil },
                               apply: {
                                   applied += amount ?? 0
                                   amount = nil
                               })
            case .other:
                .done
            }
        }
    }
}

#Preview {
    KeyboardActionBarPreview()
}
#endif
