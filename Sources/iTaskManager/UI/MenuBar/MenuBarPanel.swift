import SwiftUI

/// The window that drops down from the status item: a compact live summary. Each section is
/// its own view observing only the readings it shows.
struct MenuBarPanel: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PanelHeader()
            PanelCPUSection()
            PanelMemoryRow()
            PanelGPURow()
            PanelPowerSection()

            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Text("占用最高的应用").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                TopAppsList(metric: .cpu, limit: 5, showsBars: false)
            }

            Divider()
            PanelActions()
        }
        .padding(16)
        .frame(width: 330)
        .onAppear { monitor.beginForegroundUse() }
        .onDisappear { monitor.endForegroundUse() }
    }
}

private struct PanelHeader: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(monitor.chip.name).font(.headline)
                Text(monitor.chip.hostName).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let battery = monitor.battery {
                // The panel is narrow: icon and charge only.
                Label(Fmt.percent(battery.percent), systemImage: battery.symbolName)
                    .symbolRenderingMode(.hierarchical)
                    .monospacedDigit()
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct PanelCPUSection: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        let chip = monitor.chip
        let usage = monitor.cpu?.perCore ?? []
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("CPU", systemImage: "cpu").font(.callout.weight(.medium))
                Spacer()
                Text(Fmt.percent(monitor.cpu?.total ?? 0))
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
            }
            // Every core gets an equal column across the panel, clusters split by a gap.
            GeometryReader { geo in
                let gap: CGFloat = 14
                let column = (geo.size.width - gap) / CGFloat(max(chip.coreKinds.count, 1))
                HStack(alignment: .bottom, spacing: gap) {
                    ForEach([CoreKind.performance, .efficiency], id: \.self) { kind in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(alignment: .bottom, spacing: 0) {
                                ForEach(chip.indices(of: kind), id: \.self) { index in
                                    CoreMeter(value: usage[safe: index] ?? 0,
                                              color: Palette.core(kind), width: min(column * 0.55, 12))
                                        .frame(width: column, height: 36)
                                }
                            }
                            Text("\(kind.title) \(Fmt.percent(chip.average(kind, in: usage)))")
                                .font(.caption2)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(height: 54)
        }
    }
}

private struct PanelMemoryRow: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        let memory = monitor.memory
        PanelMeterRow(
            title: "内存", symbol: "memorychip",
            value: Fmt.percent(memory?.usedFraction ?? 0),
            detail: "\(Fmt.bytes(memory?.used ?? 0)) / \(Fmt.bytes(monitor.chip.memoryBytes))",
            fraction: memory?.usedFraction ?? 0, color: Palette.memory
        )
    }
}

private struct PanelGPURow: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        let utilization = monitor.gpu?.utilization ?? 0
        PanelMeterRow(
            title: "GPU", symbol: "square.stack.3d.up",
            value: Fmt.percent(utilization),
            detail: "\(monitor.chip.gpuCores) 核",
            fraction: utilization, color: Palette.gpu
        )
    }
}

/// Title, detail and figure over a thin usage bar.
private struct PanelMeterRow: View {
    let title: String
    let symbol: String
    let value: String
    let detail: String
    let fraction: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(title, systemImage: symbol).font(.callout.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
            }
            UsageBar(value: fraction, color: color, height: 5)
        }
    }
}

private struct PanelPowerSection: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        let power = monitor.power
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("功耗", systemImage: "bolt").font(.callout.weight(.medium))
                if let power {
                    Text("CPU \(Fmt.watts(power.cpu)) · GPU \(Fmt.watts(power.gpu))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(Fmt.wattsFixed(monitor.systemWatts ?? 0))
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
            }
            LiveChart(
                series: [ChartSeries(id: "power", color: Palette.power, values: monitor.systemPowerHistory.values)],
                maxValue: niceCeiling(monitor.systemPowerHistory.max)
            )
            .frame(height: 30)
        }
    }
}

private struct PanelActions: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @Environment(Updater.self) private var updater

    var body: some View {
        HStack {
            Button(action: showMainWindow) {
                Label("打开 iTaskManager", systemImage: "macwindow")
            }
            Spacer()
            if let release = updater.available {
                Button {
                    showMainWindow()
                    updater.presentsSheet = true
                } label: {
                    Label("更新到 \(release.version.description)", systemImage: "arrow.down.circle.fill")
                }
                .foregroundStyle(Color.accentColor)
            }
            Button {
                NSApp.activate()
                openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .help("设置")
            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .help("退出")
        }
        .buttonStyle(.borderless)
    }

    private func showMainWindow() {
        openWindow(id: "main")
        NSApp.activate()
    }
}
