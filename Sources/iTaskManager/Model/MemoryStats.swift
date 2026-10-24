import Foundation

enum MemoryPressure: Sendable {
    case normal, warning, critical
}

struct MemoryStats: Sendable {
    var total: UInt64
    var app: UInt64
    var wired: UInt64
    var compressed: UInt64
    var cached: UInt64
    /// Pages no one is using (free and speculative).
    var free: UInt64
    var swapUsed: UInt64
    var swapTotal: UInt64
    var pressure: MemoryPressure

    /// Same definition as Activity Monitor's "Memory Used".
    var used: UInt64 { app + wired + compressed }
    var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
    /// What could be handed out now: free pages plus cached files, which are dropped on
    /// demand. Not total − used: part of the installed memory is reserved by the hardware and
    /// never managed by macOS (about 0.75 GB on a 24 GB M5).
    var available: UInt64 { free + cached }
}
