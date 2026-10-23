/// Fixed-capacity series of recent values, oldest first.
struct History: Sendable {
    /// One extra point lives just past the right edge so charts can scroll it in.
    static let capacity = 61

    private(set) var values: [Double] = []

    var last: Double? { values.last }

    mutating func append(_ value: Double) {
        if values.count == Self.capacity + 1 {
            values.removeFirst()
        }
        values.append(value)
    }

    var max: Double { values.max() ?? 0 }
}
