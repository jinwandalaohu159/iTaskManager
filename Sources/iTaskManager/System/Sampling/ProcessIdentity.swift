import Darwin

/// Who a process is: name, executable path and owner. These work for every process, system
/// ones included, without special rights.
enum ProcessIdentity {
    static func name(of pid: pid_t) -> String {
        var buffer = [CChar](repeating: 0, count: 256)
        guard proc_name(pid, &buffer, UInt32(buffer.count)) > 0 else { return "" }
        return String(decoding: buffer.prefix { $0 != 0 }.map(UInt8.init), as: UTF8.self)
    }

    static func owner(of pid: pid_t) -> uid_t? {
        var info = proc_bsdshortinfo()
        let size = Int32(MemoryLayout<proc_bsdshortinfo>.size)
        return proc_pidinfo(pid, PROC_PIDT_SHORTBSDINFO, 0, &info, size) == size ? info.pbsi_uid : nil
    }

    static func path(of pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return String(decoding: buffer.prefix { $0 != 0 }.map(UInt8.init), as: UTF8.self)
    }
}
