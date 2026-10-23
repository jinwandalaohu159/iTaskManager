import Foundation

/// Keeps a "top N" list from reshuffling every second. Values still update live, but the
/// order only changes every few seconds — or at once when something leaps to the top or a
/// listed process exits. Each reorder is animated, so this also keeps that animation rare.
struct StableRanking {
    var holdInterval: TimeInterval = 4
    var limit = 8

    private(set) var order: [ProcessRowID] = []
    private var lastChange = Date.distantPast

    mutating func update(rows: [ProcessRow], metric: ProcessMetric, now: Date = .now) {
        let values = Dictionary(rows.map { ($0.id, metric.value(of: $0)) }, uniquingKeysWith: { a, _ in a })
        let desired = rows.sorted { metric.value(of: $0) > metric.value(of: $1) }.prefix(limit).map(\.id)
        guard desired != order else { return }

        let someoneLeft = order.contains { values[$0] == nil }
        let newLeader = desired.first.flatMap { leader -> Bool? in
            guard let current = order.first, leader != current else { return nil }
            return (values[leader] ?? 0) >= 2 * (values[current] ?? 0) + 0.001
        } ?? false

        if order.isEmpty || someoneLeft || newLeader || now.timeIntervalSince(lastChange) >= holdInterval {
            order = desired
            lastChange = now
        }
    }
}
