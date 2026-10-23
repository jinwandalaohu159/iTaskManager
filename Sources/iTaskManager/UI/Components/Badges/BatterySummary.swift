import SwiftUI

/// Battery icon, state and remaining time on one line.
struct BatterySummary: View {
    let battery: BatteryStats
    var showsPercent = true

    @Environment(\.smoothMotion) private var smooth

    var body: some View {
        HStack(spacing: 6) {
            // Every icon gets the width of the battery glyph, so swapping to the narrower plug
            // doesn't pull the text along.
            Image(systemName: "battery.100percent")
                .hidden()
                .overlay {
                    Image(systemName: battery.symbolName)
                        .symbolRenderingMode(.hierarchical)
                        .contentTransition(.symbolEffect(.replace))
                }
            if showsPercent {
                Text(Fmt.percent(battery.percent)).monospacedDigit()
                    .reservingWidth(of: Fmt.percentTemplate, alignment: .trailing)
                separator
            }
            Text(battery.stateLabel)
                .contentTransition(.opacity)
            if let minutes = battery.timeRemaining, !battery.isPluggedIn {
                Group {
                    separator
                    Text(L("剩余 \(Fmt.minutes(minutes))")).monospacedDigit()
                        .reservingWidth(of: L("剩余 \(Fmt.minutesTemplate)"))
                }
                .transition(.opacity)
            }
        }
        .font(.callout)
        // Only a change of state animates; the figures update in place.
        .animation(smooth ? .smooth(duration: 0.35) : nil, value: battery.symbolName)
        .animation(smooth ? .smooth(duration: 0.35) : nil, value: battery.stateLabel)
    }

    private var separator: some View {
        Text("·").foregroundStyle(.tertiary)
    }
}
