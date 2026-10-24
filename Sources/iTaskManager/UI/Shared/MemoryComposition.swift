import SwiftUI

/// Used memory by what holds it, counted in physical pages exactly as macOS counts them;
/// shared by the overview card and the memory page.
enum MemoryBreakdown {
    struct Part: Identifiable {
        let id: String
        let label: String
        let color: Color
        let bytes: UInt64
        let help: String
    }

    /// One pink stepping lighter row by row: the parts of "used", then the GPU's share, then
    /// cached files.
    static let shades = [1.0, 0.74, 0.52, 0.34, 0.2].map { Palette.memory.opacity($0) }

    static func parts(_ memory: MemoryStats) -> [Part] {
        [
            Part(id: "process", label: L("进程内存"), color: shades[0], bytes: memory.app,
                 help: L("各进程自己的数据，可以被压缩或换出")),
            Part(id: "kernel", label: L("内核与驱动"), color: shades[1], bytes: memory.wired,
                 help: L("内核和驱动使用、不能被换出的内存")),
            Part(id: "compressed", label: L("被压缩"), color: shades[2], bytes: memory.compressed,
                 help: L("压缩后的数据实际占用的内存")),
        ]
    }
}

/// The breakdown as a bar with a legend, plus file cache (which isn't counted as used) and the
/// GPU's share, which overlaps the parts rather than adding to them.
struct MemoryComposition: View {
    let memory: MemoryStats
    var gpuMemory: UInt64?

    var body: some View {
        let parts = MemoryBreakdown.parts(memory)
        VStack(alignment: .leading, spacing: 12) {
            SegmentedBar(
                segments: parts.map { Segment(id: $0.id, color: $0.color, value: Double($0.bytes)) },
                total: Double(memory.total)
            )
            VStack(spacing: 7) {
                ForEach(parts) { part in
                    LegendRow(color: part.color, label: part.label, value: Fmt.bytes(part.bytes), info: part.help)
                }
                if let gpuMemory {
                    LegendRow(color: MemoryBreakdown.shades[3], label: L("GPU 占用", context: "memory"), value: Fmt.bytes(gpuMemory),
                              info: L("GPU 正在使用的内存。GPU 和 CPU 共用同一块统一内存，这部分已包含在上面各项中"))
                }
                LegendRow(color: MemoryBreakdown.shades[4], label: L("已缓存文件"), value: Fmt.bytes(memory.cached),
                          info: L("最近读过的文件内容，不算在已使用里，需要时随时释放"))
            }
        }
    }
}
