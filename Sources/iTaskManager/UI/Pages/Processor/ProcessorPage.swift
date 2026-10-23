import SwiftUI

struct ProcessorPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CPUCard().reveal(0)
                PerCoreCard().reveal(1)
                GPUCard().reveal(2)
            }
            .padding(24)
        }
    }
}

private struct CPUCard: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        let chip = monitor.chip
        let cpu = monitor.cpu
        let usage = cpu?.perCore ?? []
        let power = monitor.power
        let split = power?.hasClusterSplit == true

        GaugeChartCard(title: L("CPU 总占用")) {
            RingGauge(rings: [
                Ring(id: "p", value: chip.average(.performance, in: usage), color: Palette.pCore),
                Ring(id: "e", value: chip.average(.efficiency, in: usage), color: Palette.eCore),
            ]) {
                GaugeCenter(text: Fmt.percent(cpu?.total ?? 0), value: cpu?.total ?? 0, caption: "CPU")
            }
        } legend: {
            LegendRow(
                color: Palette.pCore, label: CoreKind.performance.title,
                value: Fmt.percent(chip.average(.performance, in: usage)) + (split ? " · " + Fmt.watts(power!.pcpu) : "")
            )
            LegendRow(
                color: Palette.eCore, label: CoreKind.efficiency.title,
                value: Fmt.percent(chip.average(.efficiency, in: usage)) + (split ? " · " + Fmt.watts(power!.ecpu) : "")
            )
        } facts: {
            InlineStats(items: [
                .init(label: L("用户"), value: Fmt.percent(cpu?.user ?? 0), template: Fmt.percentPartTemplate),
                .init(label: L("系统"), value: Fmt.percent(cpu?.system ?? 0), template: Fmt.percentPartTemplate),
                .init(label: L("性能核"), value: cpu?.frequency[.performance].map(Fmt.gigahertz) ?? "—", template: "0.0 GHz"),
                .init(label: L("能效核"), value: cpu?.frequency[.efficiency].map(Fmt.gigahertz) ?? "—", template: "0.0 GHz"),
                .init(label: L("已运行"), value: Fmt.uptime(since: chip.bootDate, now: monitor.lastSampleDate), template: Fmt.uptimeTemplate),
            ])
            .font(.callout)
        } chart: {
            LiveChart(
                series: [ChartSeries(id: "cpu", color: Palette.cpu, values: monitor.cpuHistory.values)],
                maxValue: fractionCeiling(monitor.cpuHistory.values),
                style: .full
            )
        }
    }
}

/// Every core's recent history, performance and efficiency clusters side by side.
private struct PerCoreCard: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        // Shared by every row so rows stay comparable.
        let ceiling = fractionCeiling(monitor.coreHistories.flatMap(\.values))
        Card(padding: 20) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: L("每个核心"), subtitle: L("最近 60 秒 · 纵轴 0–\(Fmt.percent(ceiling))"))
                // Both clusters share one height, so the fewer performance cores get taller rows.
                HStack(alignment: .top, spacing: 24) {
                    column(.performance, ceiling: ceiling)
                    column(.efficiency, ceiling: ceiling)
                }
                .frame(height: 300)
            }
        }
    }

    private func column(_ kind: CoreKind, ceiling: Double) -> some View {
        let indices = monitor.chip.indices(of: kind)
        let usage = monitor.cpu?.perCore ?? []
        return VStack(alignment: .leading, spacing: 8) {
            CoreGroupHeader(kind: kind, count: indices.count)
            VStack(spacing: 6) {
                ForEach(Array(indices.enumerated()), id: \.element) { offset, index in
                    CoreRow(
                        label: "\(kind.prefix)\(offset + 1)",
                        color: Palette.core(kind),
                        value: usage[safe: index] ?? 0,
                        history: monitor.coreHistories[index].values,
                        ceiling: ceiling
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct GPUCard: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        let gpu = monitor.gpu
        GaugeChartCard(title: L("GPU 利用率")) {
            RingGauge(rings: [Ring(id: "gpu", value: gpu?.utilization ?? 0, color: Palette.gpu)], lineWidth: 16) {
                GaugeCenter(text: Fmt.percent(gpu?.utilization ?? 0), value: gpu?.utilization ?? 0, caption: "GPU")
            }
        } legend: {
            LegendRow(color: Palette.gpu, label: L("功耗"), value: monitor.power.map { Fmt.watts($0.gpu) } ?? "—")
            LegendRow(color: Palette.memory, label: L("占用内存"), value: Fmt.bytes(gpu?.memoryInUse ?? 0))
        } facts: {
            InlineStats(items: [
                .init(label: L("核心"), value: "\(monitor.chip.gpuCores)", template: "00"),
                .init(label: L("峰值"), value: Fmt.percent(monitor.gpuHistory.max), template: Fmt.percentTemplate),
                .init(label: L("频率"), value: gpu?.frequency.map { "\(Int($0.rounded())) MHz" } ?? "—", template: "0000 MHz"),
            ])
            .font(.callout)
        } chart: {
            LiveChart(
                series: [ChartSeries(id: "gpu", color: Palette.gpu, values: monitor.gpuHistory.values)],
                maxValue: fractionCeiling(monitor.gpuHistory.values),
                style: .full
            )
        }
    }
}
