import Foundation

/// Owns every sampler and runs them off the main thread.
actor SamplerEngine {
    private let cpu: CPUSampler
    private let memory = MemorySampler()
    private let gpu = GPUSampler()
    private let power = PowerSampler()
    private let battery = BatterySampler()
    private let processes = ProcessSampler()

    private var lastBattery: BatteryStats?
    private var lastBatteryDate = Date.distantPast
    /// Until then the battery is read on every sample, e.g. right after the charger is plugged
    /// in, while charging state settles.
    private var batteryUrgentUntil = Date.distantPast

    init(chip: ChipInfo) {
        cpu = CPUSampler(chip: chip)
    }

    /// Reads the battery on every sample for the next few seconds.
    func expediteBattery(for seconds: TimeInterval = 10) {
        batteryUrgentUntil = Date().addingTimeInterval(seconds)
    }

    /// `privileged`: read processes through the root helper, so system ones are included.
    func sample(includeProcesses: Bool, privileged: Bool) async -> Snapshot {
        var processStats: [ProcessStats]?
        if includeProcesses {
            if processes.isStale(after: 5) {
                // Prime the counters so the first visible frame already has rates.
                _ = processes.sample(privileged: privileged)
                try? await Task.sleep(for: .milliseconds(250))
            }
            processStats = processes.sample(privileged: privileged)
        } else {
            processes.checkpointEnergyIfDue(privileged: privileged)
        }

        // The battery changes slowly and its IORegistry node is comparatively expensive.
        let now = Date()
        if battery.isAvailable, now.timeIntervalSince(lastBatteryDate) >= 5 || now < batteryUrgentUntil {
            lastBattery = battery.sample()
            lastBatteryDate = now
        }

        return Snapshot(
            date: now,
            cpu: cpu.sample(),
            memory: memory.sample(),
            gpu: gpu.sample(),
            power: power.sample(),
            battery: lastBattery,
            processes: processStats,
            processesPrivileged: processStats != nil && processes.lastSampleWasPrivileged,
            processEnergySpan: processes.energySpan
        )
    }
}
