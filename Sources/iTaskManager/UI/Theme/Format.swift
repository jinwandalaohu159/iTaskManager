import Foundation

/// Display formatting shared by every view.
enum Fmt {
    /// Templates matching each formatter's widest output.
    static let percentTemplate = "100%"
    /// A part of a total, like user/system CPU: reaches 100% only when it's the whole of it.
    static let percentPartTemplate = "00%"
    static let bytesTemplate = "00.0 GB"
    static let wattsTemplate = "000 mW"
    static var minutesTemplate: String { L("00 小时 00 分钟") }
    static var uptimeTemplate: String { L("00 小时 00 分") }

    /// Pads with figure spaces (the width of a digit) for places that can't reserve layout
    /// space, such as the menu bar.
    static func padded(_ text: String, to length: Int) -> String {
        String(repeating: "\u{2007}", count: max(length - text.count, 0)) + text
    }

    static func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }

    static func bytes(_ value: UInt64) -> String {
        let v = Double(value)
        let gb = 1024.0 * 1024 * 1024
        let mb = 1024.0 * 1024
        if v >= gb { return String(format: "%.1f GB", v / gb) }
        if v >= mb { return String(format: "%.0f MB", v / mb) }
        return String(format: "%.0f KB", v / 1024)
    }

    static func watts(_ value: Double) -> String {
        if value < 0.995 { return "\(Int((value * 1000).rounded())) mW" }
        return wattsFixed(value)
    }

    /// Headline power figures stay in watts with one decimal ("0.4 W", "18.2 W").
    static func wattsFixed(_ value: Double) -> String {
        String(format: "%.1f W", value)
    }

    /// Axis tick: only as many decimals as the value needs (0 W, 2.5 W, 0.25 W), so a tick
    /// is never rounded away from the grid line it labels.
    static func axisWatts(_ value: Double) -> String {
        for decimals in 0...2 {
            let text = String(format: "%.\(decimals)f", value)
            if let parsed = Double(text), abs(parsed - value) < 1e-9 { return text + " W" }
        }
        return String(format: "%.2f W", value)
    }

    /// Energy in joules as watt-hours: "0.4 mWh", "35 mWh", "1.2 Wh".
    static func energy(_ joules: Double) -> String {
        let wattHours = joules / 3600
        if wattHours < 0.00995 { return String(format: "%.1f mWh", wattHours * 1000) }
        if wattHours < 0.995 { return "\(Int((wattHours * 1000).rounded())) mWh" }
        return String(format: "%.1f Wh", wattHours)
    }

    /// A clock in MHz as GHz with one decimal ("2.1 GHz").
    static func gigahertz(_ megahertz: Double) -> String {
        String(format: "%.1f GHz", megahertz / 1000)
    }

    static func rate(_ bytesPerSecond: Double) -> String {
        let mb = bytesPerSecond / 1_048_576
        if mb < 0.05 { return "0 MB/s" }
        return String(format: "%.1f MB/s", mb)
    }

    static func cpu(_ percent: Double) -> String {
        String(format: "%.1f", percent)
    }

    static func uptime(since date: Date, now: Date = .now) -> String {
        let minutes = max(Int(now.timeIntervalSince(date) / 60), 0)
        let d = minutes / 1440, h = minutes / 60 % 24, m = minutes % 60
        if d > 0 { return L("\(d) 天 \(h) 小时") }
        if h > 0 { return L("\(h) 小时 \(m) 分") }
        return L("\(m) 分钟")
    }

    static func minutes(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        return h > 0 ? L("\(h) 小时 \(m) 分钟") : L("\(m) 分钟")
    }
}
