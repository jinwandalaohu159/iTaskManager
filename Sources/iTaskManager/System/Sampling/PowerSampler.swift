import CSystem
import Foundation

/// Component power from the power manager's energy counters, with what's supplied and used as
/// a whole from `SupplySampler`.
///
/// macOS 27 stops updating the "Energy Model" CPU, memory and Neural Engine counters every
/// moment for ordinary apps; there the CPU, GPU, Neural Engine and, where its record is known,
/// memory come from the CPU performance controller instead, the CPU split between clusters by
/// the power management processor's per-cluster histograms. Elsewhere memory only has the
/// Energy Model counter, which macOS 27 updates in batches a couple of minutes apart;
/// `BatchedRate` turns each batch into the average over its own span.
final class PowerSampler {
    private let clpc = itm_clpc_create()
    private let clusters = itm_cluster_create()
    private let supply = SupplySampler()
    /// Opened only where the performance controller doesn't cover everything: the group has
    /// some 170 channels, all read and compared on every sample.
    private var energyModel: OpaquePointer?
    private var energyModelOpened = false
    private var memory = BatchedRate()

    deinit {
        itm_power_destroy(energyModel)
        itm_clpc_destroy(clpc)
        itm_cluster_destroy(clusters)
    }

    func sample() -> PowerStats? {
        var controller = ITMControllerEnergy()
        let hasController = clpc.map { itm_clpc_read($0, &controller) } ?? false

        var stats: PowerStats
        if hasController, controller.dram >= 0 {
            guard controller.elapsed > 0 else { return nil }
            stats = PowerStats(cpu: 0, ecpu: 0, pcpu: 0, gpu: 0, ane: 0, dram: nil, hasClusterSplit: false)
        } else {
            guard let energyModel = openEnergyModel() else { return nil }
            var energy = ITMEnergy()
            var elapsed = 0.0
            guard itm_power_read(energyModel, &energy, &elapsed), elapsed > 0 else { return nil }
            memory.add(energy.dram, at: Date())
            stats = PowerStats(
                cpu: energy.cpu / elapsed,
                ecpu: energy.ecpu / elapsed,
                pcpu: energy.pcpu / elapsed,
                gpu: energy.gpu / elapsed,
                ane: energy.ane / elapsed,
                dram: memory.watts,
                hasClusterSplit: energy.hasClusterSplit
            )
        }
        if hasController, controller.elapsed > 0 {
            apply(controller, to: &stats)
        }

        let supply = self.supply.sample()
        stats.system = supply.system
        stats.battery = supply.battery
        stats.adapterInput = supply.adapterInput
        return stats
    }

    private func openEnergyModel() -> OpaquePointer? {
        if !energyModelOpened {
            energyModel = itm_power_create()
            energyModelOpened = true
        }
        return energyModel
    }

    /// CPU, GPU, Neural Engine and (where known) memory from the performance controller, the CPU
    /// divided between the clusters in proportion to what each cluster's power histogram recorded.
    private func apply(_ controller: ITMControllerEnergy, to stats: inout PowerStats) {
        let elapsed = controller.elapsed
        stats.cpu = controller.cpu / elapsed
        stats.gpu = controller.gpu / elapsed
        stats.ane = controller.ane / elapsed
        if controller.dram >= 0 { stats.dram = controller.dram / elapsed }

        var efficiency = 0.0, performance = 0.0
        if let clusters, itm_cluster_read(clusters, &efficiency, &performance) {
            let share = efficiency / (efficiency + performance)
            stats.ecpu = stats.cpu * share
            stats.pcpu = stats.cpu - stats.ecpu
            stats.hasClusterSplit = true
        } else {
            stats.hasClusterSplit = false
        }
    }
}
