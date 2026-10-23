import Foundation

enum CoreKind: Sendable, Hashable {
    case performance
    case efficiency
}

/// Static facts about the machine, read once at launch (see `ChipInfo.current()`).
struct ChipInfo: Sendable {
    let name: String
    let hostName: String
    let osVersion: String
    /// Indexed by logical CPU id, matching the order of `host_processor_info`.
    let coreKinds: [CoreKind]
    let gpuCores: Int
    let memoryBytes: UInt64
    let bootDate: Date
    /// Highest clock of each core kind in MHz; nil where the DVFS tables can't be read.
    let maxFrequency: [CoreKind: Double]?

    var performanceCount: Int { coreKinds.count { $0 == .performance } }
    var efficiencyCount: Int { coreKinds.count { $0 == .efficiency } }

    /// Cycles per second with every core at its top clock: "100% CPU" for the whole machine.
    var cycleCapacity: Double? {
        maxFrequency.map { table in coreKinds.reduce(0) { $0 + (table[$1] ?? 0) * 1e6 } }
    }

    func indices(of kind: CoreKind) -> [Int] {
        coreKinds.indices.filter { coreKinds[$0] == kind }
    }

    /// Mean usage of one cluster, given per-core usage in logical CPU order.
    func average(_ kind: CoreKind, in usage: [Double]) -> Double {
        let indices = indices(of: kind).filter(usage.indices.contains)
        return indices.isEmpty ? 0 : indices.reduce(0) { $0 + usage[$1] } / Double(indices.count)
    }
}
