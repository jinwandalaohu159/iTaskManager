import Foundation

/// A string literal split into a lookup key, with `%@` where each value was interpolated,
/// and the values themselves.
struct LocalizedText: ExpressibleByStringInterpolation {
    fileprivate(set) var key = ""
    fileprivate(set) var values: [String] = []

    init(stringLiteral value: String) {
        key = value
    }

    init(stringInterpolation: StringInterpolation) {
        key = stringInterpolation.key
        values = stringInterpolation.values
    }

    struct StringInterpolation: StringInterpolationProtocol {
        fileprivate var key = ""
        fileprivate var values: [String] = []

        init(literalCapacity: Int, interpolationCount: Int) {}

        mutating func appendLiteral(_ literal: String) {
            key += literal
        }

        mutating func appendInterpolation(_ value: some Any) {
            key += "%@"
            values.append("\(value)")
        }

        mutating func appendInterpolation(_ value: Double, specifier: String) {
            key += "%@"
            values.append(String(format: specifier, value))
        }
    }

    /// Puts the values into a template in order. Placeholders are found in the template only,
    /// never inside a value already put in.
    func filling(_ template: String) -> String {
        guard !values.isEmpty else { return template }
        let pieces = template.components(separatedBy: "%@")
        var result = pieces[0]
        for (index, piece) in pieces.dropFirst().enumerated() {
            result += (values.indices.contains(index) ? values[index] : "") + piece
        }
        return result
    }
}
