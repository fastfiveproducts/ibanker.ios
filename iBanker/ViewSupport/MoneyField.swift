//
//  MoneyField.swift
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

import SwiftUI
import UIKit

/// The app's one money-entry field (#68), used by every money input.
///
/// On iPhone this renders exactly the `TextField(value:formatter:)` +
/// `.numberPad` stack the app has always used — zero behavior change; the
/// #42 flow there is the product standard. On iPad it substitutes a UIKit
/// text field whose `inputView` is an app-supplied digit pad, because
/// iPadOS 26 presents the system `.numberPad` NONDETERMINISTICALLY — a
/// floating popover, a minimized pill, a docked layer, even full QWERTY —
/// and the popover forms neither raise the keyboard safe area (stranding
/// the KeyboardActionBar at the pane bottom) nor tolerate an outside tap
/// (the first tap on the bar is spent dismissing the popover). A custom
/// `inputView` always DOCKS full-width: the safe area rises and the bar
/// lands directly above the pad, restoring the iPhone behavior. Keyed on
/// the DEVICE idiom, not the #237 window-width tier, because that is what
/// the OS keys its keyboard choice on — a narrow iPad window still gets
/// the popover, so it must still get the pad.
///
/// Commit semantics — the part that keeps the bar's ordering contract
/// (clear focus FIRST, then run `apply`/`cancel`) safe with a UIKit field,
/// whose resign→end-editing commit can land a runloop late:
///  - `commitsContinuously: true` (default): every keypress writes the
///    binding, and end-editing does NOT re-commit — so a bar closure always
///    reads a current value, and a value it clears can never be resurrected
///    by the late commit.
///  - `commitsContinuously: false`: the classic end-editing commit, for a
///    field whose binding has a side-effectful `onChange` (PlayerView's
///    salary live-syncs `.updateSalary` — per-keystroke commits would spam
///    the event log, the #36 class). Only safe with a closure-free bar
///    (`.done`), which salary's is.
struct MoneyField<Field: Hashable>: View {
    let placeholder: String
    @Binding var value: Int?
    var focus: FocusState<Field?>.Binding
    let field: Field
    var commitsContinuously = true
    var prominent = false
    var alignment: TextAlignment = .trailing

    init(_ placeholder: String,
         value: Binding<Int?>,
         focus: FocusState<Field?>.Binding,
         equals field: Field,
         commitsContinuously: Bool = true,
         prominent: Bool = false,
         alignment: TextAlignment = .trailing) {
        self.placeholder = placeholder
        self._value = value
        self.focus = focus
        self.field = field
        self.commitsContinuously = commitsContinuously
        self.prominent = prominent
        self.alignment = alignment
    }

    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            PadMoneyTextField(placeholder: placeholder,
                              value: $value,
                              focus: focus,
                              field: field,
                              commitsContinuously: commitsContinuously,
                              prominent: prominent,
                              alignment: alignment)
                .frame(maxWidth: .infinity)
                // Registers the focus value with SwiftUI. Without this, the
                // delegate's FocusState writes are REJECTED (no view claims
                // the value) and the KeyboardActionBar never mounts; with it,
                // the iOS 17+ representable focus bridge also forwards
                // become/resignFirstResponder both ways.
                .focused(focus, equals: field)
        } else {
            let textField = TextField(placeholder, value: $value, formatter: NumberFormatter.money)
                .keyboardType(.numberPad)
                .autocorrectionDisabled(true)
                .multilineTextAlignment(alignment)
                .focused(focus, equals: field)
            if prominent {
                textField
                    .font(.title2)
                    .fontWeight(.bold)
            } else {
                textField
            }
        }
    }
}

// MARK: - Pad key engine (pure, unit-tested)

enum MoneyPadKey: Equatable {
    case digit(Int)
    case backspace
    /// #6 (iPad half): fast large-money entry for the big board-game
    /// denominations (GameMode goes to $400K and $15M). On integer digit
    /// strings, appending zeros IS multiplication — "15" then M reads
    /// 15,000,000, the issue's own example.
    case thousand   // K — appends 000 (×1,000)
    case million    // M — appends 000000 (×1,000,000)
}

enum MoneyPadEngine {
    /// Display/entry cap: keeps entries readable and leaves Int64 headroom
    /// (12 digits < 10^13, far under Int.max).
    static let maxDigits = 12

    /// Applies one pad key to the current raw-digit entry string.
    static func apply(_ key: MoneyPadKey, to digits: String) -> String {
        switch key {
        case .digit(let d):
            guard (0...9).contains(d), digits.count < maxDigits else { return digits }
            return digits + String(d)
        case .backspace:
            return String(digits.dropLast())
        case .thousand:
            return appendingZeros(3, to: digits)
        case .million:
            return appendingZeros(6, to: digits)
        }
    }

    /// No-op on an empty entry (multiply semantics — there is nothing to
    /// multiply) and when the result would burst the cap (whole-key no-op,
    /// never a partial append).
    private static func appendingZeros(_ count: Int, to digits: String) -> String {
        guard !digits.isEmpty, digits.count + count <= maxDigits else { return digits }
        return digits + String(repeating: "0", count: count)
    }
}

// MARK: - iPad implementation

private struct PadMoneyTextField<Field: Hashable>: UIViewRepresentable {
    let placeholder: String
    @Binding var value: Int?
    var focus: FocusState<Field?>.Binding
    let field: Field
    let commitsContinuously: Bool
    let prominent: Bool
    let alignment: TextAlignment

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        // Deliberately NOT .numberPad: iPadOS presents its floating keypad
        // chrome FOR the keyboard type, independent of the custom inputView —
        // declaring .numberPad here put BOTH keyboards on screen at once
        // (owner device report, 2026-09-07; reproduced on the walk sim). The
        // inputView IS the keyboard; .default gives the OS nothing to add.
        // Hardware keystrokes still route through the digits-only engine
        // below, so the type buys nothing.
        textField.delegate = context.coordinator
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        switch alignment {
        case .leading: textField.textAlignment = .natural
        case .center: textField.textAlignment = .center
        case .trailing: textField.textAlignment = .right
        }
        if prominent {
            textField.font = UIFont.preferredFont(forTextStyle: .title2).withWeight(.bold)
        } else {
            textField.font = UIFont.preferredFont(forTextStyle: .body)
        }
        textField.adjustsFontForContentSizeCategory = true
        // Parity with the app-wide Dynamic Type cap (AppConfig.dynamicSizeMax,
        // .xxxLarge) — the SwiftUI cap does not flow into UIKit on its own.
        textField.maximumContentSizeCategory = .extraExtraExtraLarge
        // No shortcut/assistant strip above the pad (undo/redo/paste chrome).
        textField.inputAssistantItem.leadingBarButtonGroups = []
        textField.inputAssistantItem.trailingBarButtonGroups = []
        textField.inputView = context.coordinator.makePadInputView()
        textField.text = Self.formatted(value)
        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        context.coordinator.parent = self
        if !textField.isFirstResponder {
            textField.text = Self.formatted(value)
        }
        // Focus itself is owned by the `.focused(_:equals:)` bridge on the
        // wrapper (see MoneyField.body): it forwards FocusState writes to
        // become/resignFirstResponder and reflects responder changes back.
        // A second, manual sync here FIGHTS the bridge — the first cut had
        // one, and the loser was dismissal: focus re-latched after the bar's
        // dismiss and the pad never went down.
    }

    static func formatted(_ value: Int?) -> String {
        value.flatMap { NumberFormatter.money.string(from: NSNumber(value: $0)) } ?? ""
    }

    static func rawDigits(_ value: Int?) -> String {
        value.map(String.init) ?? ""
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: PadMoneyTextField
        private var hostingController: UIHostingController<MoneyPadView>?
        private weak var textField: UITextField?

        init(_ parent: PadMoneyTextField) {
            self.parent = parent
        }

        /// The docked pad: a `.keyboard`-style `UIInputView` (system keyboard
        /// backdrop) hosting the SwiftUI pad. Fixed height; width follows the
        /// window, exactly like a docked keyboard.
        func makePadInputView() -> UIInputView {
            let inputView = UIInputView(frame: CGRect(x: 0, y: 0, width: 0, height: 300),
                                        inputViewStyle: .keyboard)
            inputView.allowsSelfSizing = true
            let host = UIHostingController(rootView: MoneyPadView { [weak self] key in
                self?.handle(key)
            })
            host.view.backgroundColor = .clear
            host.view.translatesAutoresizingMaskIntoConstraints = false
            inputView.addSubview(host.view)
            NSLayoutConstraint.activate([
                host.view.leadingAnchor.constraint(equalTo: inputView.leadingAnchor),
                host.view.trailingAnchor.constraint(equalTo: inputView.trailingAnchor),
                host.view.topAnchor.constraint(equalTo: inputView.topAnchor),
                host.view.bottomAnchor.constraint(equalTo: inputView.bottomAnchor),
                inputView.heightAnchor.constraint(equalToConstant: 300)
            ])
            hostingController = host
            return inputView
        }

        private func handle(_ key: MoneyPadKey) {
            guard let textField else { return }
            let next = MoneyPadEngine.apply(key, to: textField.text ?? "")
            textField.text = next
            if parent.commitsContinuously {
                parent.value = Int(next)
            }
        }

        // Hardware-keyboard input routes through the same engine: digits and
        // deletions only, self-applied (return false) so text and binding
        // can never drift.
        func textField(_ textField: UITextField,
                       shouldChangeCharactersIn range: NSRange,
                       replacementString string: String) -> Bool {
            if string.isEmpty {
                handle(.backspace)
            } else {
                for character in string {
                    if let digit = character.wholeNumberValue, (0...9).contains(digit) {
                        handle(.digit(digit))
                    }
                }
            }
            return false
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            self.textField = textField
            // Editing works on raw digits; the formatter dresses the value
            // back up at end-editing (the classic value:formatter: shape).
            textField.text = PadMoneyTextField.rawDigits(parent.value)
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            if !parent.commitsContinuously {
                parent.value = Int(textField.text ?? "")
            }
            textField.text = PadMoneyTextField.formatted(parent.value)
        }
    }
}

private extension UIFont {
    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        let descriptor = fontDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: weight]
        ])
        return UIFont(descriptor: descriptor, size: 0)
    }
}

// MARK: - The pad itself

private struct MoneyPadView: View {
    let onKey: (MoneyPadKey) -> Void

    // Digits keep the system pad's shape (⌫ bottom-right); the 4th column
    // carries #6's K/M magnitude keys.
    var body: some View {
        VStack(spacing: 7) {
            row([.digit(1), .digit(2), .digit(3), .thousand])
            row([.digit(4), .digit(5), .digit(6), .million])
            HStack(spacing: 7) {
                key(.digit(7))
                key(.digit(8))
                key(.digit(9))
                Color.clear.frame(maxWidth: .infinity)
            }
            HStack(spacing: 7) {
                Color.clear.frame(maxWidth: .infinity)
                key(.digit(0))
                Color.clear.frame(maxWidth: .infinity)
                key(.backspace)
            }
        }
        .padding(8)
    }

    private func row(_ keys: [MoneyPadKey]) -> some View {
        HStack(spacing: 7) {
            ForEach(keys, id: \.self) { key($0) }
        }
    }

    private func key(_ padKey: MoneyPadKey) -> some View {
        Button {
            onKey(padKey)
        } label: {
            Group {
                switch padKey {
                case .digit(let d):
                    Text("\(d)")
                        .font(.title2)
                case .backspace:
                    Image(systemName: "delete.left")
                        .font(.title3)
                        .accessibilityLabel("Delete")
                case .thousand:
                    Text("K")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                        .accessibilityLabel("Thousand — multiplies by one thousand")
                case .million:
                    Text("M")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                        .accessibilityLabel("Million — multiplies by one million")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.tertiarySystemBackground))
                    .shadow(color: .black.opacity(0.25), radius: 0, y: 1)
            )
            .foregroundStyle(Color(.label))
        }
        .buttonStyle(.plain)
    }
}

extension MoneyPadKey: Hashable {}


#if DEBUG
private struct MoneyFieldPreview: View {
    private enum Field { case amount, salary }
    @FocusState private var focusedField: Field?
    @State private var amount: Int? = nil
    @State private var salary: Int? = 200

    var body: some View {
        Form {
            HStack {
                Text("Amount:")
                Spacer()
                MoneyField("Enter Amount", value: $amount,
                           focus: $focusedField, equals: .amount)
            }
            HStack {
                Text("Salary:")
                Spacer()
                MoneyField("Enter Salary", value: $salary,
                           focus: $focusedField, equals: .salary,
                           commitsContinuously: false, prominent: true)
            }
        }
        .keyboardDoneBar(focus: $focusedField)
    }
}

#Preview {
    MoneyFieldPreview()
}
#endif
