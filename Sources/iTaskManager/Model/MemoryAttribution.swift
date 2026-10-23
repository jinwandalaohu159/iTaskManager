import Foundation

/// "Memory used" split by who holds it, from the processes' own footprints. Unlike the
/// app/wired/compressed split it lines up with the process list: the "apps" part is what
/// that list adds up to.
struct MemoryAttribution: Sendable, Equatable {
    /// Footprints of this user's processes, and of everyone else's (system daemons, WindowServer).
    var user: UInt64
    var system: UInt64
    /// Every process could be read; without the helper, system processes are missing.
    var complete: Bool

    struct Parts {
        var user: UInt64
        var system: UInt64
        var kernel: UInt64
        /// Used memory no single process accounts for: shared memory, graphics buffers and the
        /// like. A footprint includes the process's compressed pages, so this is what's left
        /// of "used" after processes and the kernel.
        var other: UInt64
    }

    /// Sums footprints by owner. `complete`: system processes were readable (through the
    /// helper); without it their memory can't be told apart from the unattributed rest.
    init(processes: [ProcessStats], complete: Bool) {
        let me = getuid()
        var user: UInt64 = 0, system: UInt64 = 0
        for process in processes {
            guard let footprint = process.memory else { continue }
            if process.uid == me { user += footprint } else { system += footprint }
        }
        // Rounded to what's displayed, so small drifts don't redraw the memory views.
        let step: UInt64 = 10 * 1_048_576
        self.user = user / step * step
        self.system = system / step * step
        self.complete = complete
    }

    func parts(of memory: MemoryStats) -> Parts {
        let kernel = min(memory.wired, memory.used)
        let user = min(user, memory.used - kernel)
        let system = min(system, memory.used - kernel - user)
        return Parts(user: user, system: system, kernel: kernel, other: memory.used - kernel - user - system)
    }
}
