import AppKit

enum ProcessRowID: Hashable {
    case group(pid_t)
    case process(pid_t)
}

enum ProcessIcon {
    case image(NSImage)
    case symbol(String)
}

/// One row of the process table: an app (with its helpers as children) or a single process.
/// Equatable so the table can skip rows whose displayed values didn't change.
struct ProcessRow: Identifiable, Equatable {
    let id: ProcessRowID
    let pid: pid_t
    let name: String
    let icon: ProcessIcon
    let isApp: Bool
    var cpu: Double?
    var memory: UInt64?
    var power: Double?
    /// Joules over the last hour.
    var energy: Double?
    var disk: Double?
    /// Share of recent CPU time spent on performance cores; nil when the process was idle.
    var pShare: Double?
    var children: [ProcessRow]?

    // Non-optional keys for Table sorting; unreadable values sort last.
    var cpuKey: Double { cpu ?? -1 }
    var memoryKey: UInt64 { memory ?? 0 }
    var powerKey: Double { power ?? -1 }
    var diskKey: Double { disk ?? -1 }
    var pShareKey: Double { pShare ?? -1 }
    var pidKey: Int { Int(pid) }

    static func == (a: ProcessRow, b: ProcessRow) -> Bool {
        a.id == b.id && a.name == b.name && a.isApp == b.isApp && a.icon == b.icon
            && a.cpu == b.cpu && a.memory == b.memory && a.power == b.power && a.energy == b.energy && a.disk == b.disk
            && a.pShare == b.pShare && a.children == b.children
    }
}

extension ProcessIcon: Equatable {
    static func == (a: ProcessIcon, b: ProcessIcon) -> Bool {
        switch (a, b) {
        case let (.image(x), .image(y)): x === y
        case let (.symbol(x), .symbol(y)): x == y
        default: false
        }
    }
}

extension [ProcessRow] {
    /// Rows whose name contains `query`; an app also matches through its helpers, and then
    /// keeps only the helpers that match. An empty query matches everything.
    func matching(_ query: String) -> [ProcessRow] {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return self }
        return compactMap { row in
            if row.name.localizedCaseInsensitiveContains(query) { return row }
            let matches = row.children?.filter { $0.name.localizedCaseInsensitiveContains(query) } ?? []
            guard !matches.isEmpty else { return nil }
            var copy = row
            copy.children = matches
            return copy
        }
    }

    /// Sorts the rows, and each row's helpers the same way.
    func sortedTree(using order: [KeyPathComparator<ProcessRow>]) -> [ProcessRow] {
        sorted(using: order).map { row in
            var copy = row
            copy.children = copy.children?.sorted(using: order)
            return copy
        }
    }
}

/// The grouped process list published by the monitor.
struct ProcessTree {
    var apps: [ProcessRow] = []
    var background: [ProcessRow] = []
    var processCount = 0
    var restrictedCount = 0

    var allRows: [ProcessRow] { apps + background }

    func row(for id: ProcessRowID) -> ProcessRow? {
        for row in allRows {
            if row.id == id { return row }
            if let child = row.children?.first(where: { $0.id == id }) { return child }
        }
        return nil
    }
}

/// What a "top apps" list ranks by.
enum ProcessMetric: CaseIterable {
    case cpu, memory, power
    /// Energy used over the last hour, rather than power right now.
    case energy

    func value(of row: ProcessRow) -> Double {
        switch self {
        case .cpu: row.cpu ?? 0
        case .memory: Double(row.memory ?? 0)
        case .power: row.power ?? 0
        case .energy: row.energy ?? 0
        }
    }
}
