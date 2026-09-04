//
//  ActivityLogEntry.swift
//
//  Template file created by Elizabeth Maiser, Fast Five Products LLC, on 7/5/25.
//  Modified by Claude, Fast Five Products LLC, on 8/31/26.
//      Template v0.4.9 (updated) — Fast Five Products LLC's public AGPL template.
//
//  Copyright © 2025, 2026 Fast Five Products LLC. All rights reserved.
//
//  This file is part of a project licensed under the GNU Affero General Public License v3.0.
//  An exception applies: Fast Five Products LLC retains the right to use this code and
//  derivative works in proprietary software without being subject to the AGPL terms.
//  See the LICENSE and LICENSE-EXCEPTIONS.md files at the root of the template repository
//  (github.com/fastfiveproducts/template.ios) for full terms.
//
//  For licensing inquiries, contact: licenses@fastfiveproducts.com
//


import Foundation
import SwiftData

@Model
final class ActivityLogEntry {
    var event: String
    var timestamp: Date
    
    init(_ event: String, timestamp: Date = Date()) {
        self.event = event
        self.timestamp = timestamp
    }
}


// MARK: - Retention
extension ActivityLogEntry {
    static let retentionCap = 1000

    // Trim the log to the retention cap, deleting the oldest entries and inserting
    // a marker entry noting the trim. The marker uses the newest DELETED entry's
    // timestamp so it sorts at the trim point (top of the surviving log) in this
    // timestamp-sorted model — adapts DTrol's append-at-end marker (LogStore.save())
    // to a sorted @Query. The marker counts toward the cap: one extra entry is
    // deleted so the post-marker total equals the cap exactly, and no further trim
    // runs until real growth pushes the count over the cap again (that next trim
    // deletes the prior marker along with the oldest real entries). Failure
    // handling is deliberately soft (try? + guard): log maintenance must never
    // crash launch; a skipped trim self-heals on the next load.
    @MainActor
    static func trimToCap(in context: ModelContext, cap: Int = retentionCap) {
        guard let count = try? context.fetchCount(FetchDescriptor<ActivityLogEntry>()), count > cap else { return }
        var descriptor = FetchDescriptor<ActivityLogEntry>(sortBy: [SortDescriptor(\.timestamp, order: .forward)])
        descriptor.fetchLimit = count - cap + 1
        guard let oldest = try? context.fetch(descriptor), !oldest.isEmpty else { return }
        let markerTimestamp = oldest.last?.timestamp ?? Date()
        for entry in oldest { context.delete(entry) }
        context.insert(ActivityLogEntry("Oldest \(oldest.count) entries deleted to limit log size", timestamp: markerTimestamp))
        try? context.save()
    }
}


#if DEBUG
extension ActivityLogEntry {
    // @MainActor because these are SwiftData @Model instances — reference
    // types the compiler cannot prove Sendable — held in a static.  Costs
    // nothing today (every consumer is already main-actor: the preview
    // container's injectPreviewData and the #Preview bodies), and it is what
    // the Swift 6 language mode requires (#244).
    @MainActor
    static let testObjects: [ActivityLogEntry] = [
        ActivityLogEntry("test event"),
        ActivityLogEntry("another test event")
    ]

    // Generator for large-log previews (windowing / "Show Earlier" behavior)
    static func makeTestObjects(count: Int) -> [ActivityLogEntry] {
        let now = Date()
        return (0..<count).map { i in
            ActivityLogEntry("test event #\(i + 1)", timestamp: now.addingTimeInterval(Double(i - count) * 60))
        }
    }
}
#endif
