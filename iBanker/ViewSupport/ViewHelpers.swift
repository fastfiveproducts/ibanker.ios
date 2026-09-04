//
//  ViewHelpers.swift
//
//  Template file created by Pete Maiser, Fast Five Products LLC, on 2/10/26 (split from ViewConfig.swift, since renamed AppConfig.swift)
//  Modified by Claude, Fast Five Products LLC, on 9/4/26.
//      Template v0.5.0 (updated) — Fast Five Products LLC's public AGPL template.
//
//  Copyright © 2026 Fast Five Products LLC. All rights reserved.
//
//  This file is part of a project licensed under the GNU Affero General Public License v3.0.
//  An exception applies: Fast Five Products LLC retains the right to use this code and
//  derivative works in proprietary software without being subject to the AGPL terms.
//  See the LICENSE and LICENSE-EXCEPTIONS.md files at the root of the template repository
//  (github.com/fastfiveproducts/template.ios) for full terms.
//
//  For licensing inquiries, contact: licenses@fastfiveproducts.com
//


import SwiftUI

// iBanker (recorded divergence — template.ios#263): the template's file also
// carries four OverlayState/OverlayAnimation extensions here (entry/exit
// animation defaults, accessibility modality, swiftUIAnimation). They are
// omitted because their types live in the overlay subsystem this app does not
// carry (no LaunchView/OverlayView — see TEMPLATE.md). Retire this pruning
// when template.ios#263 lands in a released template.

extension View {
    func styledView() -> some View {
        self
            .dynamicTypeSize(...AppConfig.dynamicSizeMax)
            .environment(\.font, Font.body)
    }

    // Apply to a Form/List row that stacks MULTIPLE tappable controls
    // (Link/Button): without it, the row mishandles taps — a tap anywhere
    // can fire the FIRST control (Links) or every control (Buttons),
    // depending on control type/OS; borderless gives each control its own
    // discrete hit area. Do NOT apply to single-control rows — whole-row
    // tap is the intended iOS pattern there. Example: AppIdentityFooterView
    // (two Links stacked in one row), mounted in SettingsView's Form.
    func multiControlRow() -> some View {
        self.buttonStyle(.borderless)
    }

    // Reflow width discipline (#238) — the tablet "stretch class" fix.  A
    // phone layout does not BREAK at tablet width, it STRETCHES, and
    // readability pays: the survey on this template measured ~180-character
    // lines on Home, an announcement card truncating its first row, and a
    // two-row contact list floating in ~85% empty space.  Cap the content to a
    // comfortable measure and centre it in the window.
    //
    // PREFER applying it INSIDE a scroll container, so the scrollable keeps the
    // full width and a drag in the empty side margin still scrolls.  HomeView,
    // SupportView and ActivityLogView are the worked examples.
    //
    // ⚠️ For `Form` and `List` there is NO clean inside — the container IS the
    // layout — so the cap goes on the container and the side gutters do not
    // scroll or pull-to-refresh.  Same for a screen whose column mixes a
    // scrollable with sibling content (Comments, Messages, UserPosts): capping
    // the parts separately would leave dividers spanning wider than the text
    // they separate.  This is an accepted trade, recorded so it reads as a
    // decision rather than an oversight — the Android twin has a genuine
    // "inside" for these and iOS does not.
    //
    // BOTH steps are load-bearing:
    //   .frame(maxWidth: cap)        the cap itself
    //   .frame(maxWidth: .infinity)  takes the full width so the capped child
    //                                settles at `alignment` within it.  Without
    //                                it the result is placed by the PARENT, so
    //                                anything in a VStack(alignment: .leading) —
    //                                which is most of this template — would hug
    //                                the left edge with all the empty space on
    //                                one side.
    //
    // ⚠️ Apply to containers that already span the width, not to
    // content-hugging views.  Two different things go wrong there: the outer
    // .infinity makes a view greedy, so wrapping (say) a bare Text that used to
    // size to its content changes COMPACT rendering too — the one way this
    // modifier stops being phone-invisible; and at tablet width a hugging child
    // CENTRES as a block rather than filling the capped column, because
    // .frame(maxWidth:) only PROPOSES the cap.  (The Android twin's fourth step
    // re-fixes the child to the cap, which is why its modifier has one more
    // step than this one — a real behavioural delta for hugging content, not
    // just a Compose formality.)
    //
    // `alignment` is an iOS-only parameter and exists for exactly one shape:
    // chat bubbles, which must stay anchored trailing (sent) or leading
    // (received).  Centring those would erase the sent/received distinction,
    // so .bubble is always applied WITH an alignment.  Screen content takes
    // the .center default.  (The Android twin centres unconditionally; its
    // bubble layer solves this differently.)  This is an alignment axis, not a
    // width axis — the measures themselves stay call-site-immutable.
    func contentWidthCapped(_ mode: ContentWidthMode,
                            alignment: Alignment = .center
    ) -> some View {
        self
            .frame(maxWidth: mode.cap, alignment: alignment)
            .frame(maxWidth: .infinity, alignment: alignment)
    }
}

// The measures, converged with the Android twin (template.android#86) — same
// three modes, same numbers, so the two templates state one contract.
//
// FROZEN CONTRACT: every cap is >= 600, the Compact/Medium boundary of the
// size-class taxonomy.  The floor is what keeps a phone in PORTRAIT (widest
// ~440pt) — and a narrow multi-window slice on a tablet, ~507pt for a half
// split on a 1024pt iPad, which this app supports since it sets no
// UIRequiresFullScreen — below every cap.  That is what makes the modifier
// safe for children to take wholesale.  Changing a value is a contract
// decision, not a refactor; ContentWidthTests pins the >= 600 floor for EVERY
// mode, so a mode added here inherits the promise or turns the suite red.
//
// ⚠️ Do NOT inline these numbers into contentWidthCapped above — the test
// reaches them ONLY through `cap`, so an inlined literal is unpinned.
//
// ⚠️ Do NOT restate this as "every phone is unchanged" — that is the Android
// comment's phrasing and it is false on iOS.  In LANDSCAPE both caps bind on
// current iPhones: .reading (840) below every landscape width except SE (667)
// and mini (812), and .form (600) below all of them.  This template is
// portrait-only on phones (#218) so nothing of its own changes, but a child
// app that permits phone rotation WILL see the caps engage — the desirable
// behaviour, not a defect.  Know which it is before you go looking.
//
// Measured, portrait, this template's screens: four of six bit-identical
// before/after, the other two differing only in edge/corner antialiasing
// (max channel delta 13, no layout shift — a translation test fits dy=0).
// So: visually unchanged, not bit-identical everywhere.  Say the accurate one.
enum ContentWidthMode: CaseIterable {
    case form       // label + control rows: settings, account forms, contact edit
    case reading    // prose, cards, lists: support, home, activity log, comments
    case bubble     // a single chat bubble inside a .reading-capped conversation

    var cap: CGFloat {
        switch self {
        case .form: return 600
        case .reading: return 840
        case .bubble: return 600
        }
    }
}

// The large-format boundary (#237) — the fleet's shared width tier, decided by
// the owner at the R2 convergence checkpoint (template.ios#237, 2026-09-01,
// superseding the tablet round's "iOS regular" D5 language).  A window — or,
// for a leaf that owns an internal list-detail split, a container — at or
// above this width is LARGE-FORMAT; below it, phone-shaped.  Android binds
// identically (WindowWidthSizeClass Expanded, >= 840dp), so the two templates
// state one contract.
//
// Deliberately a WIDTH, not the horizontal size class: every full-screen iPad
// reports `.regular` horizontally in BOTH orientations, so the class cannot
// distinguish an iPad mini in portrait (~744pt — phone-shaped here) from a
// 13" Pro in landscape (~1376pt — large-format).  The rule is "windows
// narrower than 840 act like a phone", orientation- and device-agnostic.
// Accepted consequence, decided knowingly: 11" iPads in portrait (~820-834pt)
// are phone-shaped — the same call the Android twin made for Pixel Tablet
// portrait (800dp).  Do not "fix" it.
//
// FROZEN CONTRACT: LaunchViewNavigationTests pins the boundary numerically
// (839/840/841) and the value itself as the Android twin-match.  Related to
// but DISTINCT from ContentWidthMode.reading's 840 above — that is a content
// CAP, this is a layout BREAKPOINT; they coincide numerically and are stated
// independently on purpose (do not alias one to the other).  The fleet's
// full width taxonomy consolidates in the #240 doctrine docs.
enum LayoutBreakpoint {
    /// Windows/containers at or above this width present large-format layout.
    static let largeFormatMinWidth: CGFloat = 840
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}

// Used by MainTabView to signal tab-style safe area background
extension EnvironmentValues {
    var tabSafeAreaBackground: Bool {
        get { self[TabSafeAreaBackgroundKey.self] }
        set { self[TabSafeAreaBackgroundKey.self] = newValue }
    }
}
private struct TabSafeAreaBackgroundKey: EnvironmentKey {
    static let defaultValue: Bool = false
}
