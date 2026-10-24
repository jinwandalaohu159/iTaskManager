import SwiftUI

struct GPUPage: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        let hasPower = monitor.hasPowerReadings
        let hasTemperature = monitor.temperatures.gpu != nil
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GPUCard().reveal(0)
                StagesCard().reveal(1)
                if hasPower || hasTemperature {
                    HStack(alignment: .top, spacing: 16) {
                        if hasPower {
                            ComponentPowerCard(title: L("GPU 功耗"), color: Palette.gpu, part: \.gpu, history: \.gpuPowerHistory)
                        }
                        if hasTemperature {
                            TemperatureCard()
                        }
                    }
                    .equalHeightRow()
                    .reveal(2)
                }
            }
            .padding(24)
        }
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
                .init(label: L("60 秒峰值"), value: Fmt.percent(monitor.gpuHistory.max), template: Fmt.percentTemplate),
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

/// The renderer and tiler stages, as the GPU driver reports them.
private struct StagesCard: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        let gpu = monitor.gpu
        let ceiling = fractionCeiling(monitor.rendererHistory.values + monitor.tilerHistory.values)
        Card(padding: 20) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: L("渲染与分块"), subtitle: L("驱动报告的忙碌时间 · 最近 60 秒 · 纵轴 0–\(Fmt.percent(ceiling))"))
                    .help(L("渲染器处理像素，分块器处理几何。这里是忙碌时间的占比，不论频率高低，所以低负载时会高于 GPU 利用率。"))
                VStack(spacing: 6) {
                    CoreRow(label: L("渲染器"), color: Palette.gpu, value: gpu?.renderer ?? 0,
                            history: monitor.rendererHistory.values, ceiling: ceiling, labelWidth: 56)
                    CoreRow(label: L("分块器"), color: Palette.gpu, value: gpu?.tiler ?? 0,
                            history: monitor.tilerHistory.values, ceiling: ceiling, labelWidth: 56)
                }
                .frame(height: 130)
            }
        }
    }
}

/// The GPU sensors' average, hottest on hover, and its recent curve.
private struct TemperatureCard: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        let group = monitor.temperatures.gpu
        let history = monitor.gpuTemperatureHistory
        MetricChartCard(
            title: L("GPU 温度"), color: Palette.gpu,
            reading: group.map { Fmt.celsius($0.average) } ?? "—", value: group?.average ?? 0,
            history: history, ceiling: niceCeiling(history.max, minimum: 50),
            format: Fmt.celsius, axisFormat: { "\(Int($0)) °C" },
            readingHelp: group.map { L("该部位 SMC 温度传感器的平均 \(Fmt.celsius($0.average)) · 最高 \(Fmt.celsius($0.maximum))") }
        )
    }
}
