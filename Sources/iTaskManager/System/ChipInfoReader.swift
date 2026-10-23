import CSystem
import Foundation
import IOKit
import SystemConfiguration

extension ChipInfo {
    static func current() -> ChipInfo {
        let ncpu = Sysctl.int("hw.ncpu") ?? ProcessInfo.processInfo.processorCount
        return ChipInfo(
            name: Sysctl.string("machdep.cpu.brand_string") ?? "Mac",
            hostName: SCDynamicStoreCopyComputerName(nil, nil) as String? ?? "Mac",
            osVersion: {
                let v = ProcessInfo.processInfo.operatingSystemVersion
                return v.patchVersion > 0 ? "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)" : "\(v.majorVersion).\(v.minorVersion)"
            }(),
            coreKinds: readCoreKinds(count: ncpu),
            gpuCores: readGPUCores(),
            memoryBytes: UInt64(Sysctl.int("hw.memsize") ?? 0),
            bootDate: Sysctl.value("kern.boottime", as: timeval.self, initial: timeval())
                .map { Date(timeIntervalSince1970: TimeInterval($0.tv_sec)) } ?? .now,
            maxFrequency: readMaxFrequencies()
        )
    }

    /// Core order differs between chips (M5 lists E cores first), so read each
    /// CPU's cluster type from the IORegistry instead of guessing.
    private static func readCoreKinds(count: Int) -> [CoreKind] {
        var kinds = [CoreKind?](repeating: nil, count: count)
        var iterator: io_iterator_t = 0
        if IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOPlatformDevice"), &iterator) == KERN_SUCCESS {
            defer { IOObjectRelease(iterator) }
            while case let entry = IOIteratorNext(iterator), entry != 0 {
                defer { IOObjectRelease(entry) }
                guard
                    let type = IORegistryEntryCreateCFProperty(entry, "cluster-type" as CFString, kCFAllocatorDefault, 0)?
                        .takeRetainedValue() as? Data,
                    let id = IORegistryEntryCreateCFProperty(entry, "logical-cpu-id" as CFString, kCFAllocatorDefault, 0)?
                        .takeRetainedValue() as? Int,
                    id < count
                else { continue }
                kinds[id] = type.first == UInt8(ascii: "E") ? .efficiency : .performance
            }
        }
        if kinds.allSatisfy({ $0 != nil }) {
            return kinds.compactMap { $0 }
        }
        // Fallback: efficiency cores first, which matches most Apple Silicon parts.
        let eCount = Sysctl.int("hw.perflevel1.logicalcpu") ?? 0
        return (0..<count).map { $0 < eCount ? .efficiency : .performance }
    }

    private static func readMaxFrequencies() -> [CoreKind: Double]? {
        var efficiency = 0.0, performance = 0.0
        guard itm_cpu_max_frequencies(&efficiency, &performance) else { return nil }
        return [.efficiency: efficiency, .performance: performance]
    }

    private static func readGPUCores() -> Int {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AGXAccelerator"))
        guard service != 0 else { return 0 }
        defer { IOObjectRelease(service) }
        return IORegistryEntryCreateCFProperty(service, "gpu-core-count" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? Int ?? 0
    }
}
