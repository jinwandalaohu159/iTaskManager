import Darwin

enum Sysctl {
    static func string(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(decoding: buffer.prefix { $0 != 0 }.map(UInt8.init), as: UTF8.self)
    }

    static func int(_ name: String) -> Int? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0 else { return nil }
        switch size {
        case 4:
            var value: Int32 = 0
            return sysctlbyname(name, &value, &size, nil, 0) == 0 ? Int(value) : nil
        case 8:
            var value: Int64 = 0
            return sysctlbyname(name, &value, &size, nil, 0) == 0 ? Int(value) : nil
        default:
            return nil
        }
    }

    static func value<T: BitwiseCopyable>(_ name: String, as type: T.Type, initial: T) -> T? {
        var value = initial
        var size = MemoryLayout<T>.size
        let ok = withUnsafeMutableBytes(of: &value) { sysctlbyname(name, $0.baseAddress, &size, nil, 0) == 0 }
        return ok ? value : nil
    }
}
