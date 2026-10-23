import AppKit

/// Turns raw per-process samples into table rows. With grouping on, helper processes are
/// folded under the app macOS holds responsible for them, like Windows Task Manager does.
@MainActor
struct ProcessGrouper {
    struct Options {
        var groupByApp = true
        var hideRestricted = false
        var cpuBasis = CPUBasis.time(fullScale: 1)
    }

    /// What a process's 100% CPU is.
    enum CPUBasis {
        /// Cycles per second, e.g. every core at its top clock. The default where clocks are known.
        case cycles(fullScale: Double)
        /// Busy cores, e.g. 1 for one core or the core count for the whole machine.
        case time(fullScale: Double)

        func percent(of process: ProcessStats) -> Double? {
            switch self {
            case .cycles(let full): process.cycleRate.map { $0 / full * 100 }
            case .time(let full): process.timeRate.map { $0 / full * 100 }
            }
        }

        /// Share of the group's CPU work done on performance cores.
        func performanceShare(of processes: [ProcessStats]) -> Double? {
            let (total, performance): (Double, Double) = switch self {
            case .cycles: (processes.reduce(0) { $0 + ($1.cycleRate ?? 0) }, processes.reduce(0) { $0 + ($1.pCycleRate ?? 0) })
            case .time: (processes.reduce(0) { $0 + ($1.timeRate ?? 0) }, processes.reduce(0) { $0 + ($1.pTimeRate ?? 0) })
            }
            // Below ~0.05% of a core there's too little work to say where it ran.
            let floor: Double = if case .cycles = self { 1e6 } else { 0.0005 }
            return total > floor ? min(performance / total, 1) : nil
        }
    }

    let icons: IconCache

    func tree(from processes: [ProcessStats], options: Options) -> ProcessTree {
        var tree = ProcessTree()
        tree.processCount = processes.count
        tree.restrictedCount = processes.count { $0.timeRate == nil }

        let visible = options.hideRestricted ? processes.filter { $0.timeRate != nil } : processes
        let byPID = Dictionary(visible.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let runningApps = icons.runningRegularApps()

        var members: [pid_t: [ProcessStats]] = [:]
        for process in visible {
            let owner = process.responsiblePID
            let root = options.groupByApp && owner > 1 && owner != process.id && byPID[owner] != nil
                ? owner : process.id
            members[root, default: []].append(process)
        }

        for (root, group) in members {
            guard let rootProcess = byPID[root] else { continue }
            let app = runningApps[root]
            let name = app?.localizedName ?? rootProcess.name
            let icon = icons.icon(for: root, path: rootProcess.path)

            var row = makeRow(id: .group(root), pid: root, name: name, icon: icon, isApp: app != nil,
                              group: group, basis: options.cpuBasis)
            if group.count > 1 {
                row.children = group.map { process in
                    makeRow(
                        id: .process(process.id), pid: process.id,
                        name: process.id == root ? name : process.name,
                        icon: process.id == root ? icon : .symbol("gearshape"),
                        isApp: false, group: [process], basis: options.cpuBasis
                    )
                }
            }
            if row.isApp { tree.apps.append(row) } else { tree.background.append(row) }
        }
        icons.prune(keeping: Set(processes.map(\.id)))
        return tree
    }

    /// Values are rounded to what the table displays, so a row only counts as changed
    /// when something visible changed.
    private func makeRow(id: ProcessRowID, pid: pid_t, name: String, icon: ProcessIcon, isApp: Bool,
                         group: [ProcessStats], basis: CPUBasis) -> ProcessRow {
        ProcessRow(
            id: id, pid: pid, name: name, icon: icon, isApp: isApp,
            cpu: Self.sum(group.map(basis.percent)).map { Self.round($0, to: 0.1) },
            memory: Self.sum(group.map(\.memory)).map { $0 / 1_048_576 * 1_048_576 },
            power: Self.sum(group.map(\.power)).map { Self.round($0, to: 0.001) },
            disk: Self.sum(group.map(\.disk)).map { Self.round($0, to: 104_857.6) },
            pShare: basis.performanceShare(of: group).map { Self.round($0, to: 0.01) }
        )
    }

    nonisolated private static func round(_ value: Double, to step: Double) -> Double {
        (value / step).rounded() * step
    }

    nonisolated private static func sum<T: AdditiveArithmetic>(_ values: [T?]) -> T? {
        let known = values.compactMap { $0 }
        return known.isEmpty ? nil : known.reduce(.zero, +)
    }
}

extension ProcessGrouper.Options {
    @MainActor
    init(settings: AppSettings, chip: ChipInfo) {
        let machine = settings.processCPUScale == .machine
        let basis: ProcessGrouper.CPUBasis
        // Whole machine: every core at its top clock. One core: a performance core at its top clock.
        if let capacity = chip.cycleCapacity, let top = chip.maxFrequency?[.performance] {
            basis = .cycles(fullScale: machine ? capacity : top * 1e6)
        } else {
            basis = .time(fullScale: machine ? Double(max(chip.coreKinds.count, 1)) : 1)
        }
        self.init(groupByApp: settings.groupProcessesByApp, hideRestricted: settings.hideRestrictedProcesses, cpuBasis: basis)
    }
}
