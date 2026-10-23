import SwiftUI

/// Where the watts go: a part-to-whole bar and a legend with each component's draw.
struct PowerBreakdown: View {
    let power: PowerStats
    var showsBar = true

    static func parts(of power: PowerStats) -> [(id: String, label: String, color: Color, watts: Double)] {
        var parts: [(String, String, Color, Double)] = []
        if power.hasClusterSplit {
            parts.append(("p", CoreKind.performance.title, Palette.pCore, power.pcpu))
            parts.append(("e", CoreKind.efficiency.title, Palette.eCore, power.ecpu))
        } else {
            parts.append(("cpu", "CPU", Palette.cpu, power.cpu))
        }
        parts.append(("gpu", "GPU", Palette.gpu, power.gpu))
        parts.append(("dram", "内存", Palette.memory, power.dram))
        if power.ane > 0.005 {
            parts.append(("ane", "神经网络引擎", Palette.power, power.ane))
        }
        if let system = power.system {
            let known = parts.reduce(0) { $0 + $1.3 }
            parts.append(("other", "屏幕及其他", Palette.other, max(system - known, 0)))
        }
        return parts.map { (id: $0.0, label: $0.1, color: $0.2, watts: $0.3) }
    }

    var body: some View {
        let parts = Self.parts(of: power)
        let total = max(power.system ?? 0, parts.reduce(0) { $0 + $1.watts })
        VStack(alignment: .leading, spacing: 12) {
            if showsBar {
                SegmentedBar(
                    segments: parts.map { Segment(id: $0.id, color: $0.color, value: $0.watts) },
                    total: max(total, 0.001)
                )
            }
            VStack(spacing: 7) {
                ForEach(parts, id: \.id) { part in
                    LegendRow(color: part.color, label: part.label, value: Fmt.watts(part.watts))
                }
            }
        }
    }
}
