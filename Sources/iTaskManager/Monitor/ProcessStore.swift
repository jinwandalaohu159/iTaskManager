import Observation

/// The grouped process list and the "top apps" rankings built from it. Fed by
/// `SystemMonitor` only while a window or the menu bar panel is open.
@MainActor
@Observable
final class ProcessStore {
    private(set) var tree = ProcessTree()
    private var rankings: [ProcessMetric: StableRanking] = [:]

    @ObservationIgnored private lazy var grouper = ProcessGrouper(icons: IconCache())

    func update(with processes: [ProcessStats], options: ProcessGrouper.Options) {
        tree = grouper.tree(from: processes, options: options)
        updateRankings()
    }

    /// Drops everything when nothing on screen shows processes any more.
    func clear() {
        tree = ProcessTree()
        rankings = [:]
    }

    /// The busiest rows for a metric, in a stable order (see `StableRanking`).
    func top(_ metric: ProcessMetric, limit: Int) -> [ProcessRow] {
        let rows = Dictionary(tree.allRows.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return (rankings[metric]?.order ?? []).prefix(limit).compactMap { rows[$0] }
    }

    private func updateRankings() {
        let rows = tree.allRows
        for metric in ProcessMetric.allCases {
            var ranking = rankings[metric] ?? StableRanking()
            let before = ranking.order
            ranking.update(rows: rows, metric: metric)
            // Only publish when the order moved, so unchanged lists aren't invalidated.
            if ranking.order != before || rankings[metric] == nil {
                rankings[metric] = ranking
            }
        }
    }
}
