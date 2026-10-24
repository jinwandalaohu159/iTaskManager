/// Destinations in the main window's sidebar.
enum Page: String, CaseIterable, Identifiable {
    case overview, processor, gpu, memory, energy, processes, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: L("总览")
        case .processor: L("处理器")
        case .gpu: "GPU"
        case .memory: L("内存")
        case .energy: L("能耗")
        case .processes: L("进程")
        case .settings: L("设置")
        }
    }

    var symbol: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .processor: "cpu"
        case .gpu: "square.stack.3d.up"
        case .memory: "memorychip"
        case .energy: "bolt"
        case .processes: "list.bullet.rectangle"
        case .settings: "gearshape"
        }
    }

    static let monitoring: [Page] = [.overview, .processor, .gpu, .memory, .energy]
}
