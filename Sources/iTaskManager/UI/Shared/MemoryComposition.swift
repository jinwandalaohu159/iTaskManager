import SwiftUI

/// Used memory split by who holds it, shared by the overview card and the memory page.
/// Falls back to Activity Monitor's app/wired/compressed split until processes have been read.
enum MemoryBreakdown {
    struct Part: Identifiable {
        let id: String
        let label: String
        let color: Color
        let bytes: UInt64
        let help: String
    }

    static func parts(_ memory: MemoryStats, _ attribution: MemoryAttribution?) -> [Part] {
        let shade = { (opacity: Double) in Palette.memory.opacity(opacity) }
        guard let attribution else {
            return [
                Part(id: "app", label: L("App 内存"), color: shade(1), bytes: memory.app, help: L("各进程使用的内存")),
                Part(id: "kernel", label: L("联动内存"), color: shade(0.62), bytes: memory.wired, help: L("内核和驱动使用、不能被换出的内存")),
                Part(id: "compressed", label: L("被压缩"), color: shade(0.36), bytes: memory.compressed, help: L("被压缩以节省空间的内存")),
            ]
        }
        let parts = attribution.parts(of: memory)
        let apps = Part(id: "user", label: L("应用"), color: shade(1), bytes: parts.user,
                        help: L("你运行的应用和它们的辅助进程，即下方列表的合计"))
        let kernel = Part(id: "kernel", label: L("内核"), color: shade(0.46), bytes: parts.kernel,
                          help: L("内核和驱动使用、不能被换出的内存（联动内存）"))
        guard attribution.complete else {
            // Without the helper, system processes can't be read and land in the remainder.
            return [
                apps, kernel,
                Part(id: "other", label: L("系统及其他"), color: shade(0.26), bytes: parts.system + parts.other,
                     help: L("系统进程（授权后可单独读取），以及共享内存、图形缓冲区等不属于单个进程的内存")),
            ]
        }
        return [
            apps,
            Part(id: "system", label: L("系统进程"), color: shade(0.7), bytes: parts.system,
                 help: L("WindowServer 等系统和其他用户的进程")),
            kernel,
            Part(id: "other", label: L("共享及其他"), color: shade(0.26), bytes: parts.other,
                 help: L("不属于单个进程的内存，例如多个进程共享的内存和图形缓冲区")),
        ]
    }
}

/// The breakdown as a bar with a legend, plus file cache (which isn't counted as used).
struct MemoryComposition: View {
    let memory: MemoryStats
    let attribution: MemoryAttribution?

    var body: some View {
        let parts = MemoryBreakdown.parts(memory, attribution)
        VStack(alignment: .leading, spacing: 12) {
            SegmentedBar(
                segments: parts.map { Segment(id: $0.id, color: $0.color, value: Double($0.bytes)) },
                total: Double(memory.total)
            )
            VStack(spacing: 7) {
                ForEach(parts) { part in
                    LegendRow(color: part.color, label: part.label, value: Fmt.bytes(part.bytes), info: part.help)
                }
                LegendRow(color: Color.primary.opacity(0.12), label: L("已缓存文件"), value: Fmt.bytes(memory.cached),
                          info: L("最近读过的文件内容，不算在已使用里，需要时随时释放"))
            }
        }
    }
}
