extension Collection {
    /// The element at `index`, or nil when it's out of range (e.g. before the first sample).
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
