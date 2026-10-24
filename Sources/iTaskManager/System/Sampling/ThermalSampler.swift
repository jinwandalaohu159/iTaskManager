import CSystem

/// Temperatures from the SMC's sensor families, found once by key prefix. On Apple Silicon
/// "Tp" sensors sit on the performance cores, "Te" on the efficiency cores and "Tg" across the
/// GPU (checked on an M5 by loading each in turn); "TBnT" are the battery cells. The counts
/// don't match the cores, so each family is reported as a whole.
final class ThermalSampler {
    private let smc = itm_smc_open()
    /// Key codes of the float sensors in each family, checked once so reads skip the lookup.
    private let families: [Family: [UInt32]]

    enum Family: CaseIterable {
        case performance, efficiency, gpu, battery

        func matches(_ key: String) -> Bool {
            let c = Array(key)
            switch self {
            case .performance: return key.hasPrefix("Tp")
            case .efficiency: return key.hasPrefix("Te")
            case .gpu: return key.hasPrefix("Tg")
            case .battery: return c.count == 4 && c[0] == "T" && c[1] == "B" && c[2].isNumber && c[3] == "T"
            }
        }
    }

    init() {
        var found: [Family: [UInt32]] = [:]
        var name = [CChar](repeating: 0, count: 5)
        for index in 0..<itm_smc_key_count(smc) where itm_smc_key_at(smc, index, &name) {
            let key = String(decoding: name.prefix(4).map { UInt8(bitPattern: $0) }, as: UTF8.self)
            guard key.hasPrefix("T"), let family = Family.allCases.first(where: { $0.matches(key) }) else { continue }
            // Only sensors that read as a plausible temperature now; some keys are other types.
            var value: Float = 0
            guard itm_smc_read_float(smc, key, &value), Self.isPlausible(value) else { continue }
            found[family, default: []].append(itm_smc_key_code(key))
        }
        families = found
    }

    deinit {
        itm_smc_close(smc)
    }

    func sample() -> Temperatures {
        let performance = read(.performance), efficiency = read(.efficiency)
        return Temperatures(
            cpu: group(performance + efficiency),
            performance: group(performance),
            efficiency: group(efficiency),
            gpu: group(read(.gpu)),
            battery: group(read(.battery))
        )
    }

    private func read(_ family: Family) -> [Double] {
        (families[family] ?? []).compactMap { key -> Double? in
            var value: Float = 0
            return itm_smc_read_known_float(smc, key, &value) && Self.isPlausible(value) ? Double(value) : nil
        }
    }

    private func group(_ values: [Double]) -> SensorGroup? {
        guard let maximum = values.max() else { return nil }
        return SensorGroup(average: values.reduce(0, +) / Double(values.count), maximum: maximum)
    }

    private static func isPlausible(_ celsius: Float) -> Bool {
        celsius.isFinite && celsius > 5 && celsius < 130
    }
}
