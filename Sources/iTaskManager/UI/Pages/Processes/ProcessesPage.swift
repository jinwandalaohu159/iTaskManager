import SwiftUI

/// Every process, grouped into apps and background processes, with sorting, search and
/// "end task" like Windows Task Manager.
struct ProcessesPage: View {
    @Environment(SystemMonitor.self) private var monitor

    @State private var sortOrder = [KeyPathComparator(\ProcessRow.cpuKey, order: .reverse)]
    @State private var selection: ProcessRowID?
    @State private var search = ""
    @State private var expanded: Set<ProcessRowID> = []
    @State private var pendingTermination: ProcessRow?
    @State private var errorMessage: String?

    var body: some View {
        let tree = monitor.processes.tree
        let apps = prepare(tree.apps)
        let background = prepare(tree.background)

        Table(of: ProcessRow.self, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("名称", value: \.name) { row in
                HStack(spacing: 8) {
                    ProcessIconView(icon: row.icon)
                    Text(row.name).lineLimit(1)
                    if let children = row.children {
                        Text("(\(children.count))").foregroundStyle(.secondary)
                    }
                }
            }
            .width(min: 200, ideal: 260, max: 380)

            TableColumn("CPU", value: \.cpuKey) { row in
                MetricCell(text: row.cpu.map { Fmt.cpu($0) + "%" }, width: 56)
            }
            .width(min: 76, ideal: 96)
            .alignment(.center)

            TableColumn("核心", value: \.pShareKey) { row in
                CoreShareCell(pShare: row.pShare)
            }
            .width(min: 110, ideal: 130)
            .alignment(.center)

            TableColumn("内存", value: \.memoryKey) { row in
                MetricCell(text: row.memory.map(Fmt.bytes), width: 68)
            }
            .width(min: 86, ideal: 106)
            .alignment(.center)

            TableColumn("功耗", value: \.powerKey) { row in
                MetricCell(text: row.power.map(Fmt.watts), width: 60)
            }
            .width(min: 80, ideal: 100)
            .alignment(.center)

            TableColumn("磁盘", value: \.diskKey) { row in
                MetricCell(text: row.disk.map(Fmt.rate), width: 72)
            }
            .width(min: 90, ideal: 110)
            .alignment(.center)

            TableColumn("PID", value: \.pidKey) { row in
                MetricCell(text: String(row.pid), width: 48, secondary: true)
            }
            .width(min: 64, ideal: 80)
            .alignment(.center)
        } rows: {
            Section("应用（\(apps.count)）") {
                ForEach(apps) { row in groupRow(row) }
            }
            Section("后台进程（\(background.count)）") {
                ForEach(background) { row in groupRow(row) }
            }
        }
        .contextMenu(forSelectionType: ProcessRowID.self) { ids in
            if let id = ids.first, let row = find(id) {
                Button("结束任务") { pendingTermination = row }
                Button("强制结束") { terminate(row, force: true) }
                Divider()
                if let path = ProcessControl.executablePath(of: row.pid) {
                    Button("在访达中显示") {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                    }
                }
                Button("拷贝 PID") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(String(row.pid), forType: .string)
                }
            }
        } primaryAction: { ids in
            guard let id = ids.first else { return }
            if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) }
        }
        .searchable(text: $search, placement: .toolbar, prompt: "搜索进程")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if let selection, let row = find(selection) { pendingTermination = row }
                } label: {
                    Label("结束任务", systemImage: "xmark.circle")
                }
                .help("结束所选进程")
                .disabled(selection == nil)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { ProcessesFooter() }
        .confirmationDialog(
            "要结束“\(pendingTermination?.name ?? "")”吗？",
            isPresented: Binding(get: { pendingTermination != nil }, set: { if !$0 { pendingTermination = nil } }),
            presenting: pendingTermination
        ) { row in
            Button("结束任务") { terminate(row, force: false) }
            Button("强制结束", role: .destructive) { terminate(row, force: true) }
            Button("取消", role: .cancel) {}
        } message: { _ in
            Text("未存储的更改可能会丢失。")
        }
        .alert(
            "无法结束进程",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("好") {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    /// Apps with helpers get a disclosure triangle; single processes are plain rows.
    @TableRowBuilder<ProcessRow>
    private func groupRow(_ row: ProcessRow) -> some TableRowContent<ProcessRow> {
        if let children = row.children {
            DisclosureTableRow(row, isExpanded: expansion(row.id)) {
                ForEach(children) { child in
                    TableRow(child)
                }
            }
        } else {
            TableRow(row)
        }
    }

    private func expansion(_ id: ProcessRowID) -> Binding<Bool> {
        Binding(
            get: { expanded.contains(id) },
            set: { if $0 { expanded.insert(id) } else { expanded.remove(id) } }
        )
    }

    // MARK: Data

    private func prepare(_ rows: [ProcessRow]) -> [ProcessRow] {
        rows.matching(search).sortedTree(using: sortOrder)
    }

    private func find(_ id: ProcessRowID) -> ProcessRow? {
        monitor.processes.tree.row(for: id)
    }

    private func terminate(_ row: ProcessRow, force: Bool) {
        switch ProcessControl.terminate(pid: row.pid, force: force) {
        case .ok:
            selection = nil
        case .denied:
            errorMessage = "“\(row.name)”属于系统或其他用户，需要管理员权限才能结束。"
        case .failed:
            errorMessage = "“\(row.name)”没有响应结束请求，可以尝试“强制结束”。"
        }
    }
}
