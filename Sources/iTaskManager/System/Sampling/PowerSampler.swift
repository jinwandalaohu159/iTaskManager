import CSystem

final class PowerSampler {
    private let reader = itm_power_create()
    private let smc = itm_smc_open()

    deinit {
        itm_power_destroy(reader)
        itm_smc_close(smc)
    }

    func sample() -> PowerStats? {
        guard let reader else { return nil }
        var energy = ITMEnergy()
        var elapsed = 0.0
        guard itm_power_read(reader, &energy, &elapsed), elapsed > 0 else { return nil }

        var system: Float = 0
        let hasSystem = itm_smc_read_float(smc, "PSTR", &system) && system.isFinite && system >= 0
        var battery: Float = 0
        let hasBattery = itm_smc_read_float(smc, "PPBR", &battery) && battery.isFinite && battery >= 0

        return PowerStats(
            cpu: energy.cpu / elapsed,
            ecpu: energy.ecpu / elapsed,
            pcpu: energy.pcpu / elapsed,
            gpu: energy.gpu / elapsed,
            ane: energy.ane / elapsed,
            dram: energy.dram / elapsed,
            hasClusterSplit: energy.hasClusterSplit,
            system: hasSystem ? Double(system) : nil,
            battery: hasBattery ? Double(battery) : nil
        )
    }
}
