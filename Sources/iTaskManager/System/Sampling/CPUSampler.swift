import CSystem
import Darwin

final class CPUSampler {
    private struct Ticks {
        var user: UInt32
        var system: UInt32
        var idle: UInt32
        var nice: UInt32
    }

    private let host = itm_host_self()
    private let chip: ChipInfo
    private var previous: [Ticks] = []
    /// Per-core clock residency; nil on Macs without the IOReport channels.
    private let residency = itm_cpu_create()
    private var activity = [ITMCoreActivity](repeating: ITMCoreActivity(), count: 64)

    init(chip: ChipInfo) {
        self.chip = chip
        previous = readTicks()
    }

    deinit {
        itm_cpu_destroy(residency)
    }

    func sample() -> CPUStats {
        let current = readTicks()
        defer { previous = current }
        guard current.count == previous.count, !current.isEmpty else {
            return CPUStats(perCore: Array(repeating: 0, count: current.count), total: 0, user: 0, system: 0)
        }

        var perCore: [Double] = []
        perCore.reserveCapacity(current.count)
        var userSum = 0.0, systemSum = 0.0, allSum = 0.0
        for (a, b) in zip(previous, current) {
            // Wrapping subtraction: the 32-bit counters roll over on long uptimes.
            let user = Double(b.user &- a.user) + Double(b.nice &- a.nice)
            let system = Double(b.system &- a.system)
            let idle = Double(b.idle &- a.idle)
            let all = user + system + idle
            perCore.append(all > 0 ? (user + system) / all : 0)
            userSum += user
            systemSum += system
            allSum += all
        }
        var total = allSum > 0 ? (userSum + systemSum) / allSum : 0
        var frequency: [CoreKind: Double] = [:]
        if let clocked = clockWeighted() {
            perCore = clocked.perCore
            total = clocked.total
            frequency = clocked.frequency
        }
        // Busy time tells user from kernel; apply that split to the clock-weighted total.
        let busy = userSum + systemSum
        return CPUStats(
            perCore: perCore,
            total: total,
            user: busy > 0 ? total * userSum / busy : 0,
            system: busy > 0 ? total * systemSum / busy : 0,
            frequency: frequency
        )
    }

    /// Each core's busy time weighted by its clock against its top clock, the machine total
    /// weighted by each core's top clock, and each kind's average running clock. nil when the
    /// readings don't cover every core.
    private func clockWeighted() -> (perCore: [Double], total: Double, frequency: [CoreKind: Double])? {
        guard let residency else { return nil }
        let count = Int(itm_cpu_read(residency, &activity, Int32(activity.count)))
        let efficiency = chip.indices(of: .efficiency), performance = chip.indices(of: .performance)
        guard count == chip.coreKinds.count else { return nil }

        var perCore = [Double](repeating: 0, count: count)
        var used = 0.0, available = 0.0
        var busy: [CoreKind: Double] = [:], cycles: [CoreKind: Double] = [:]
        for core in activity.prefix(count) {
            let cluster = core.performance ? performance : efficiency
            guard let index = cluster[safe: Int(core.index)] else { return nil }
            perCore[index] = min(max(core.utilization, 0), 1)
            used += perCore[index] * core.maxFrequency
            available += core.maxFrequency
            let kind: CoreKind = core.performance ? .performance : .efficiency
            busy[kind, default: 0] += core.busy
            cycles[kind, default: 0] += core.busy * core.averageFrequency
        }
        let frequency = busy.reduce(into: [CoreKind: Double]()) { result, entry in
            if entry.value > 0.001 { result[entry.key] = (cycles[entry.key] ?? 0) / entry.value }
        }
        return (perCore, available > 0 ? used / available : 0, frequency)
    }

    private func readTicks() -> [Ticks] {
        var count: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &count, &info, &infoCount) == KERN_SUCCESS,
              let info
        else { return [] }
        defer {
            vm_deallocate(itm_task_self(), vm_address_t(bitPattern: info),
                          vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride))
        }
        return (0..<Int(count)).map { i in
            let base = i * Int(CPU_STATE_MAX)
            return Ticks(
                user: UInt32(bitPattern: info[base + Int(CPU_STATE_USER)]),
                system: UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)]),
                idle: UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)]),
                nice: UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)])
            )
        }
    }
}
