import CSystem
import Darwin

/// Every process's counters, system ones included, through the root helper.
final class HelperCounterReader {
    private var buffer: [ITMProcessCounters] = []
    /// After the helper fails to answer, it isn't asked again until then, so a helper launchd
    /// can't start costs one wait a minute rather than one every sample.
    private var quietUntil = ContinuousClock.now
    private static let backoff = Duration.seconds(60)

    /// nil when the helper isn't installed, approved or answering.
    func read() -> [pid_t: ProcessCounters]? {
        guard let label = PrivilegedHelper.label, ContinuousClock.now >= quietUntil else { return nil }
        if buffer.isEmpty {
            buffer = [ITMProcessCounters](repeating: ITMProcessCounters(), count: 8192)
        }
        let count = Int(itm_helper_snapshot(label, &buffer, Int32(buffer.count)))
        if count == Int(ITM_HELPER_TIMED_OUT) { quietUntil = .now + Self.backoff }
        guard count >= 0 else { return nil }
        var result: [pid_t: ProcessCounters] = [:]
        result.reserveCapacity(count)
        for entry in buffer.prefix(count) {
            result[entry.pid] = ProcessCounters(entry)
        }
        return result
    }
}
