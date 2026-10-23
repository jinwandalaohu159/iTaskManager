import CSystem
import Darwin

final class MemorySampler {
    private let host = itm_host_self()
    private let pageSize = UInt64(Sysctl.int("hw.pagesize") ?? 16384)
    private let total = UInt64(Sysctl.int("hw.memsize") ?? 0)

    func sample() -> MemoryStats {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        _ = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }

        let page = pageSize
        let anonymous = UInt64(stats.internal_page_count)
        let purgeable = UInt64(stats.purgeable_count)
        let swap = Sysctl.value("vm.swapusage", as: xsw_usage.self, initial: xsw_usage())

        let pressure: MemoryPressure = switch Sysctl.int("kern.memorystatus_vm_pressure_level") ?? 1 {
        case 4: .critical
        case 2: .warning
        default: .normal
        }

        return MemoryStats(
            total: total,
            app: (anonymous > purgeable ? anonymous - purgeable : 0) * page,
            wired: UInt64(stats.wire_count) * page,
            compressed: UInt64(stats.compressor_page_count) * page,
            cached: (UInt64(stats.external_page_count) + purgeable) * page,
            swapUsed: swap?.xsu_used ?? 0,
            swapTotal: swap?.xsu_total ?? 0,
            pressure: pressure
        )
    }
}
