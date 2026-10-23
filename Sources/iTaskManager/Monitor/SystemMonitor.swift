import Foundation
import Observation

/// Schedules sampling and publishes the results. Each kind of reading is its own observable
/// property, so a view only refreshes when the data it actually shows changes.
@MainActor
@Observable
final class SystemMonitor {
    let chip = ChipInfo.current()

    // Latest readings
    private(set) var cpu: CPUStats?
    private(set) var memory: MemoryStats?
    private(set) var gpu: GPUStats?
    private(set) var power: PowerStats?
    private(set) var battery: BatteryStats?

    // What this Mac can report; these change rarely, so page layouts can depend on them cheaply.
    private(set) var hasPowerReadings = false
    private(set) var hasBattery = false

    // Recent history, oldest first
    private(set) var cpuHistory = History()
    private(set) var coreHistories: [History]
    private(set) var memoryHistory = History()
    private(set) var gpuHistory = History()
    private(set) var systemPowerHistory = History()
    private(set) var cpuPowerHistory = History()
    private(set) var gpuPowerHistory = History()

    /// Processes, only sampled while a window or the menu bar panel is open.
    let processes = ProcessStore()
    /// Who holds the used memory, from the same process sample; nil while processes aren't sampled.
    private(set) var memoryAttribution: MemoryAttribution?

    /// When the latest sample landed and the spacing between samples; charts glide on this clock.
    private(set) var lastSampleDate = Date()
    private(set) var interval: Double = 1

    @ObservationIgnored let settings: AppSettings
    /// Reads system processes once the user has allowed it.
    let helper = PrivilegedHelper()
    @ObservationIgnored private let engine: SamplerEngine
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var foregroundDemand = 0
    @ObservationIgnored private var screensAsleep = false
    @ObservationIgnored private var inBackgroundMode: Bool?
    @ObservationIgnored private var liveBattery = LiveBattery()
    @ObservationIgnored private let events = SystemEvents()

    init(settings: AppSettings) {
        self.settings = settings
        coreHistories = Array(repeating: History(), count: chip.coreKinds.count)
        engine = SamplerEngine(chip: chip)
        observeEvents()
        updatePowerMode()
        restart()
    }

    /// Whole-system power: the SMC reading, but never less than the sum of the parts. The SMC
    /// value is smoothed and lags a sudden load, while the parts are measured per interval.
    var systemWatts: Double? {
        power.map { max($0.system ?? 0, $0.cpu + $0.gpu + $0.ane + $0.dram) }
    }

    // MARK: Foreground use

    /// The main window and the menu bar panel call this while visible: processes are sampled,
    /// refresh runs at full rate and the app leaves background mode so animations stay smooth.
    func beginForegroundUse() {
        foregroundDemand += 1
        if foregroundDemand == 1 {
            updatePowerMode()
            restart()
        }
    }

    func endForegroundUse() {
        foregroundDemand = max(0, foregroundDemand - 1)
        if foregroundDemand == 0 {
            processes.clear()
            memoryAttribution = nil
            updatePowerMode()
        }
    }

    private var isForeground: Bool { foregroundDemand > 0 }

    // MARK: Sampling loop

    /// Takes a sample now and restarts the schedule, e.g. after the refresh rate changes.
    func restart() {
        loop?.cancel()
        // Background priority keeps sampling on the efficiency cores even with a window open.
        loop = Task(priority: .background) { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if !self.screensAsleep {
                    let snapshot = await self.engine.sample(
                        includeProcesses: self.isForeground, privileged: self.helper.isOn
                    )
                    guard !Task.isCancelled else { return }
                    self.apply(snapshot)
                }
                self.updatePowerMode()
                let interval = self.effectiveInterval
                try? await Task.sleep(for: .seconds(interval), tolerance: .seconds(interval * 0.1))
            }
        }
    }

    private var effectiveInterval: Double {
        let base = settings.refreshInterval
        return !isForeground && settings.slowRefreshInBackground ? base * 2 : base
    }

    private func updatePowerMode() {
        let background = !isForeground && settings.efficiencyCoresInBackground
        guard background != inBackgroundMode else { return }
        inBackgroundMode = background
        PowerMode.setBackground(background)
    }

    private func apply(_ snapshot: Snapshot) {
        interval = effectiveInterval
        lastSampleDate = snapshot.date

        cpu = snapshot.cpu
        memory = snapshot.memory
        gpu = snapshot.gpu
        power = snapshot.power
        battery = snapshot.battery.map {
            liveBattery.adjust($0, power: snapshot.power, systemWatts: systemWatts, at: snapshot.date)
        }
        if hasPowerReadings != (snapshot.power != nil) { hasPowerReadings = snapshot.power != nil }
        if hasBattery != (snapshot.battery != nil) { hasBattery = snapshot.battery != nil }

        cpuHistory.append(snapshot.cpu.total)
        for (index, usage) in snapshot.cpu.perCore.enumerated() where index < coreHistories.count {
            coreHistories[index].append(usage)
        }
        memoryHistory.append(snapshot.memory.usedFraction)
        gpuHistory.append(snapshot.gpu?.utilization ?? 0)
        if let power = snapshot.power, let watts = systemWatts {
            systemPowerHistory.append(watts)
            cpuPowerHistory.append(power.cpu)
            gpuPowerHistory.append(power.gpu)
        }

        if let sampled = snapshot.processes, isForeground {
            processes.update(with: sampled, options: ProcessGrouper.Options(settings: settings, chip: chip))
            let attribution = MemoryAttribution(processes: sampled, complete: snapshot.processesPrivileged)
            if attribution != memoryAttribution { memoryAttribution = attribution }
        }
    }

    private func observeEvents() {
        events.onScreensSleep = { [weak self] in self?.screensAsleep = true }
        events.onScreensWake = { [weak self] in
            self?.screensAsleep = false
            self?.restart()
        }
        // Plugging in or out: read the battery now rather than at its next scheduled read.
        events.onPowerSourceChange = { [weak self] in
            guard let self else { return }
            Task {
                await self.engine.expediteBattery()
                self.restart()
            }
        }
    }
}
