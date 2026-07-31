//
//  ActivityLogView.swift
//
//  Template file created by Elizabeth Maiser, Fast Five Products LLC, on 7/5/25.
//  Modified by Claude, Fast Five Products LLC, on 7/31/26.
//      Template v0.4.4 (updated) — Fast Five Products LLC's public AGPL template.
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
//  For licensing inquiries, contact: licenses@fastfiveproducts.com
//


import SwiftUI
import SwiftData

struct ActivityLogView: View, DebugPrintable {
    @Query(sort: \ActivityLogEntry.timestamp) var logEntries: [ActivityLogEntry]

    var showTitle: Bool = false

    // Windowed display: render only the most recent entries so the screen opens instantly with large logs
    private static let pageSize = 200
    @State private var visibleCount = ActivityLogView.pageSize
    @State private var scrollPosition = ScrollPosition(edge: .bottom)
    @State private var isNearBottom = true
    private var visibleEntries: [ActivityLogEntry] { Array(logEntries.suffix(visibleCount)) }
    private var hasEarlier: Bool { logEntries.count > visibleCount }

    var body: some View {
        VStack {
            if showTitle {
                HStack {
                    Text("Activity Log")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding(.bottom)
            }

            ScrollView {
                // Plain VStack, not lazy: the visible window is capped, and non-lazy layout
                // makes bottom-anchored positioning deterministic (lazy row-height estimation breaks it)
                VStack(alignment: .leading, spacing: 0) {
                    if logEntries.isEmpty {
                        Text("No activity logged yet.")
                    } else {
                        if hasEarlier {
                            Button("Show Earlier") { visibleCount += Self.pageSize }
                                .font(.caption)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        ForEach(visibleEntries) { entry in
                            HStack {
                                Text(entry.event)
                                Spacer()
                                Text(entry.timestamp, style: .time)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
            // Open at the bottom (newest) and follow appends while the user is there;
            // scrolling up suspends following. Top alignment anchors separately so a
            // log shorter than the screen reads from the top.
            // No debounce: @Query delivers one update per SwiftData transaction, and
            // writes are single user-action inserts (unlike DTrol's bursty stream reloads).
            .scrollPosition($scrollPosition)
            .defaultScrollAnchor(.top, for: .alignment)
            .defaultScrollAnchor(.bottom, for: .initialOffset)
            .defaultScrollAnchor(.bottom, for: .sizeChanges)
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.containerSize.height >= geometry.contentSize.height - 60
            } action: { _, nearBottom in
                isNearBottom = nearBottom
            }
            .onAppear {
                isNearBottom = true
                scrollPosition.scrollTo(edge: .bottom)
            }
            .onChange(of: logEntries.count) {
                if isNearBottom {
                    scrollPosition.scrollTo(edge: .bottom)
                }
            }

            Spacer()
            // No "Clear All Logs" button — the log is the game's audit trail
            // (one tap shouldn't erase it mid-game) and its size is already
            // bounded by the retention cap (ActivityLogEntry.trimToCap). Once an
            // iBanker divergence (#28); template.ios#167 removed it upstream in
            // v0.4.4, so the two now agree.
        }
        .padding()
    }
}


#if DEBUG
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: ActivityLogEntry.self, configurations: config)
    
    for task in ActivityLogEntry.testObjects {
        container.mainContext.insert(task)
    }
    
    return ActivityLogView()
        .modelContainer(container)
}

#Preview("large log") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: ActivityLogEntry.self, configurations: config)

    for entry in ActivityLogEntry.makeTestObjects(count: 450) {
        container.mainContext.insert(entry)
    }

    return ActivityLogView()
        .modelContainer(container)
}
#endif
