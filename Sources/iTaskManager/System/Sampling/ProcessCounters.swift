import CSystem
import Darwin

/// One process's cumulative usage; the sampler turns two readings into rates.
struct ProcessCounters {
    var startTime: UInt64
    var cpuTime: UInt64
    var pCoreTime: UInt64
    var cycles: UInt64
    var pCycles: UInt64
    var energy: UInt64
    var diskBytes: UInt64
    var footprint: UInt64

    init(_ r: rusage_info_v6) {
        startTime = r.ri_proc_start_abstime
        cpuTime = r.ri_user_time + r.ri_system_time
        pCoreTime = r.ri_user_ptime + r.ri_system_ptime
        cycles = r.ri_cycles
        pCycles = r.ri_pcycles
        energy = r.ri_energy_nj
        diskBytes = r.ri_diskio_bytesread + r.ri_diskio_byteswritten
        footprint = r.ri_phys_footprint
    }

    init(_ c: ITMProcessCounters) {
        startTime = c.startTime
        cpuTime = c.userTime + c.systemTime
        pCoreTime = c.userPTime + c.systemPTime
        cycles = c.cycles
        pCycles = c.pCycles
        energy = c.energy
        diskBytes = c.diskRead + c.diskWritten
        footprint = c.footprint
    }

    /// Reads a process this user may inspect; nil for other users' and system processes.
    static func read(_ pid: pid_t) -> ProcessCounters? {
        var usage = rusage_info_v6()
        let ok = withUnsafeMutablePointer(to: &usage) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V6, $0) == 0
            }
        }
        return ok ? ProcessCounters(usage) : nil
    }
}
