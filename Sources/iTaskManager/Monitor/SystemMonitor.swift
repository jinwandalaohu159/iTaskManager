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
    private(set) var temperatures = Temperatures()

    // What this Mac can report; these change rarely, so page layouts can depend on them cheaply.
    private(set) var hasPowerReadings = false
    private(set) var hasBattery = false
    /// Plugged in with the adapter's input readable, i.e. there's a charge flow to show.
    private(set) var hasChargeFlow = false

    // Recent history, oldest first
    private(set) var cpuHistory = History()
    private(set) var coreHistories: [History]
    private(set) var memoryHistory = History()
    private(set) var gpuHistory = History()
    private(set) var rendererHistory = History()
    private(set) var tilerHistory = History()
    private(set) var gpuTemperatureHistory = History()
    private(set) var systemPowerHistory = History()
    private(set) var cpuPowerHistory = History()
    private(set) var gpuPowerHistory = History()
    /// While plugged in: what goes to the Mac and what goes into the battery.
    private(set) var chargeSystemHistory = History()
    private(set) var chargeBatteryHistory = History()

    /// Processes, only sampled while a window or the menu bar panel is open.
    let processes = ProcessStore()
    /// How many minutes back the apps' energy figures reach, up to an hour.
    private(set) var energyMinutes: Int?

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
        power.map { max($0.system ?? 0, $0.cpu + $0.gpu + $0.ane + ($0.dram ?? 0)) }
    }

    /// Where the adapter's power goes; nil on battery or when the adapter's input can't be read.
    var chargeFlow: ChargeFlow? {
        guard battery?.isPluggedIn == true, let input = power?.adapterInput else { return nil }
        return ChargeFlow(input: input, system: min(systemWatts ?? 0, input))
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

    /// `keepingData` leaves the last process list in place, for a
    /// window that is only hidden and will show them again when uncovered.
    func endForegroundUse(keepingData: Bool = false) {
        foregroundDemand = max(0, foregroundDemand - 1)
        if foregroundDemand == 0 {
            if !keepingData {
                processes.clear()
            }
            updatePowerMode()
        }
    }

    private var isForeground: Bool { foregroundDemand > 0 }

    /// A window or the panel is open, or the menu bar shows a temperature.
    private var showsTemperatures: Bool {
        isForeground || settings.menuBarCPUTemperature || settings.menuBarGPUTemperature
    }

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
                        includeProcesses: self.isForeground,
                        includeTemperatures: self.showsTemperatures,
                        privileged: self.helper.isOn
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
        publishReadings(snapshot)
        recordHistory(snapshot)
        if let sampled = snapshot.processes, isForeground {
            publishProcesses(sampled, snapshot: snapshot)
        }
    }

    /// The latest readings, and what this Mac turns out to report. The capability flags only
    /// change when they flip, so layouts that depend on them don't redraw every sample.
    private func publishReadings(_ snapshot: Snapshot) {
        cpu = snapshot.cpu
        memory = snapshot.memory
        gpu = snapshot.gpu
        power = snapshot.power
        if let sampled = snapshot.temperatures { temperatures = sampled }
        battery = snapshot.battery.map {
            liveBattery.adjust($0, power: snapshot.power, systemWatts: systemWatts, at: snapshot.date)
        }
        if hasPowerReadings != (snapshot.power != nil) { hasPowerReadings = snapshot.power != nil }
        if hasBattery != (snapshot.battery != nil) { hasBattery = snapshot.battery != nil }
        if hasChargeFlow != (chargeFlow != nil) { hasChargeFlow = chargeFlow != nil }
    }

    /// One more point on every chart.
    private func recordHistory(_ snapshot: Snapshot) {
        cpuHistory.append(snapshot.cpu.total)
        for (index, usage) in snapshot.cpu.perCore.enumerated() where index < coreHistories.count {
            coreHistories[index].append(usage)
        }
        memoryHistory.append(snapshot.memory.usedFraction)
        gpuHistory.append(snapshot.gpu?.utilization ?? 0)
        rendererHistory.append(snapshot.gpu?.renderer ?? 0)
        tilerHistory.append(snapshot.gpu?.tiler ?? 0)
        if let gpu = snapshot.temperatures?.gpu { gpuTemperatureHistory.append(gpu.average) }
        if let power = snapshot.power, let watts = systemWatts {
            systemPowerHistory.append(watts)
            cpuPowerHistory.append(power.cpu)
            gpuPowerHistory.append(power.gpu)
        }
        if let flow = chargeFlow {
            chargeSystemHistory.append(flow.system)
            chargeBatteryHistory.append(flow.battery)
        }
    }

    private func publishProcesses(_ sampled: [ProcessStats], snapshot: Snapshot) {
        let options = ProcessGrouper.Options(settings: settings, chip: chip, clockScale: snapshot.cpu.clockScale)
        processes.update(with: sampled, options: options)
        let minutes = snapshot.processEnergySpan.map { min(Int($0 / 60), 60) }
        if minutes != energyMinutes { energyMinutes = minutes }
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
