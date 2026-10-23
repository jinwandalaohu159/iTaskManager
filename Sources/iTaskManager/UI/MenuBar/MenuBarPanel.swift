import SwiftUI

/// The window that drops down from the status item: a compact live summary. Each section is
/// its own view observing only the readings it shows.
struct MenuBarPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PanelHeader()
            PanelCPUSection()
            PanelMemoryRow()
            PanelGPURow()
            PanelPowerSection()

            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Text(L("占用最高的应用")).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                TopAppsList(metric: .cpu, limit: 5, showsBars: false)
            }

            Divider()
            PanelActions()
        }
        .padding(16)
        .frame(width: 330)
        .foregroundUse()
    }
}
