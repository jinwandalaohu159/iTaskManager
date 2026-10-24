import CSystem
import Foundation
import IOKit

final class GPUSampler {
    private let service: io_service_t
    /// Clock-aware activity; nil on Macs without the IOReport channel.
    private let activity = itm_gpu_create()

    init() {
        service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOAccelerator"))
    }

    deinit {
        if service != 0 { IOObjectRelease(service) }
        itm_gpu_destroy(activity)
    }

    /// Utilization is the share of the GPU's full-clock capacity in use. The driver's own
    /// "Device Utilization %" only counts busy time, and an idle-ish GPU runs at its lowest
    /// clock, so a light load like window animations reads 30–50% there while using about 5%
    /// of what the GPU can do. That figure is the fallback when residency isn't available.
    func sample() -> GPUStats? {
        let stats = service == 0 ? nil : IORegistryEntryCreateCFProperty(
            service, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0
        )?.takeRetainedValue() as? [String: Any]
        let memory = UInt64(stats?["In use system memory"] as? Int ?? 0)
        let renderer = Self.fraction(stats?["Renderer Utilization %"])
        let tiler = Self.fraction(stats?["Tiler Utilization %"])

        var reading = ITMGPUActivity()
        if let activity, itm_gpu_read(activity, &reading) {
            return GPUStats(
                utilization: min(max(reading.utilization, 0), 1),
                memoryInUse: memory,
                frequency: reading.averageFrequency > 0 ? reading.averageFrequency : nil,
                renderer: renderer,
                tiler: tiler
            )
        }
        guard let busy = Self.fraction(stats?["Device Utilization %"]) else { return nil }
        return GPUStats(utilization: busy, memoryInUse: memory, renderer: renderer, tiler: tiler)
    }

    private static func fraction(_ percent: Any?) -> Double? {
        (percent as? Int).map { Double(min(max($0, 0), 100)) / 100 }
    }
}
