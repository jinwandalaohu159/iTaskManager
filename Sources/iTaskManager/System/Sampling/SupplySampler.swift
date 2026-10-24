import CSystem

/// The SMC's live power readings: what the Mac uses as a whole, what the battery puts out and
/// what comes in from the adapter. Each is nil where the SMC doesn't report it.
struct SupplyReading {
    var system: Double?
    /// Conversion losses included, so a little more than `system` while on battery. Not the
    /// charging power: while charging it stays near 1 W.
    var battery: Double?
    /// Only while an adapter is connected and supplying.
    var adapterInput: Double?
}

final class SupplySampler {
    private let smc = itm_smc_open()
    /// The keys this SMC has as floats, checked once so reads skip the lookup.
    private let keys: [String: UInt32]

    init() {
        var keys: [String: UInt32] = [:]
        for key in ["PSTR", "PPBR", "PDTR"] {
            var value: Float = 0
            if itm_smc_read_float(smc, key, &value) { keys[key] = itm_smc_key_code(key) }
        }
        self.keys = keys
    }

    deinit {
        itm_smc_close(smc)
    }

    func sample() -> SupplyReading {
        var reading = SupplyReading()
        reading.battery = read("PPBR").flatMap { $0 >= 0 ? $0 : nil }
        reading.adapterInput = read("PDTR").flatMap { $0 > 0.05 ? $0 : nil }
        // For a moment around plugging in or out the system reading swings wildly (seen:
        // −28 W, and 51 W from an 8 W battery). The Mac can't use more than is supplied, where
        // the supply can be read.
        let supplied = reading.adapterInput == nil && reading.battery == nil
            ? Double.infinity : (reading.adapterInput ?? 0) + (reading.battery ?? 0)
        reading.system = read("PSTR").flatMap { $0 >= 0 && $0 <= supplied + 2 ? $0 : nil }
        return reading
    }

    private func read(_ key: String) -> Double? {
        guard let code = keys[key] else { return nil }
        var value: Float = 0
        return itm_smc_read_known_float(smc, code, &value) && value.isFinite ? Double(value) : nil
    }
}
