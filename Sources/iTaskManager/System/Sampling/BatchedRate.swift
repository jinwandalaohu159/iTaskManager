import Foundation

/// Average power from a counter that may only move in batches: each batch is spread over the
/// time since the previous one. A counter that moves on every sample simply gives that
/// sample's power.
struct BatchedRate {
    /// The first batch after launch includes energy from before it, so it only starts the clock.
    private var lastBatch: Date?
    private(set) var watts: Double?

    /// Longer than any batch interval seen; beyond it (e.g. across sleep) the clock restarts.
    private static let maximumSpan: TimeInterval = 15 * 60
    /// No memory draws this much; a larger figure is a counter that skipped, not a reading.
    private static let ceiling = 100.0

    mutating func add(_ joules: Double, at now: Date) {
        guard joules > 0 else {
            if let lastBatch, now.timeIntervalSince(lastBatch) > Self.maximumSpan {
                self.lastBatch = nil
                watts = nil
            }
            return
        }
        if let lastBatch {
            let rate = joules / now.timeIntervalSince(lastBatch)
            if rate <= Self.ceiling { watts = rate }
        }
        lastBatch = now
    }
}
