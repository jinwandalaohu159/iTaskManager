/// Destinations in the main window's sidebar.
enum Page: String, CaseIterable, Identifiable {
    case overview, processor, memory, energy, processes, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "总览"
        case .processor: "处理器"
        case .memory: "内存"
        case .energy: "能耗"
        case .processes: "进程"
        case .settings: "设置"
        }
    }

    var symbol: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .processor: "cpu"
        case .memory: "memorychip"
        case .energy: "bolt"
        case .processes: "list.bullet.rectangle"
        case .settings: "gearshape"
        }
    }

    static let monitoring: [Page] = [.overview, .processor, .memory, .energy]
}
