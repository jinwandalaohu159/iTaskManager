import Foundation
import IOKit

final class BatterySampler {
    private let service: io_service_t

    init() {
        service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
    }

    deinit {
        if service != 0 { IOObjectRelease(service) }
    }

    var isAvailable: Bool { service != 0 }

    func sample() -> BatteryStats? {
        guard service != 0, let current = int("CurrentCapacity"), let max = int("MaxCapacity"), max > 0 else { return nil }

        let voltage = Double(int("Voltage") ?? 0)       // mV
        let amperage = Double(int("Amperage") ?? 0)     // mA, signed
        let remaining = int("TimeRemaining")
        let adapter = property("AdapterDetails") as? [String: Any]
        let design = int("DesignCapacity")
        let rawMax = int("AppleRawMaxCapacity")
        let isCharging = bool("IsCharging")

        return BatteryStats(
            percent: Double(current) / Double(max),
            isCharging: isCharging,
            isPluggedIn: bool("ExternalConnected"),
            isFullyCharged: bool("FullyCharged"),
            watts: voltage * amperage / 1_000_000,
            timeRemaining: remaining.flatMap { $0 > 0 && $0 < 65535 ? $0 : nil },
            remainingWattHours: int("AppleRawCurrentCapacity").map { Double($0) * voltage / 1_000_000 },
            adapterWatts: adapter?["Watts"] as? Int,
            cycleCount: int("CycleCount"),
            health: zip(rawMax, design).map { Double($0) / Double($1) },
            temperature: int("Temperature").map { Double($0) / 100 }
        )
    }

    private func property(_ key: String) -> Any? {
        IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }

    private func int(_ key: String) -> Int? { property(key) as? Int }
    private func bool(_ key: String) -> Bool { property(key) as? Bool ?? false }
}

private func zip(_ a: Int?, _ b: Int?) -> (Int, Int)? {
    guard let a, let b, b > 0 else { return nil }
    return (a, b)
}
