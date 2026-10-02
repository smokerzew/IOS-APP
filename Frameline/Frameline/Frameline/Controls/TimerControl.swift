import SwiftUI

/// Delay before a photo is taken or a recording starts. Pressing the shutter
/// again during the countdown cancels it.
struct TimerControl: View {
    @EnvironmentObject private var model: ViewfinderModel

    var body: some View {
        OptionStrip(
            options: TimerSetting.allCases,
            selection: model.timer,
            title: { $0.label },
            spokenTitle: { "Timer \($0.spokenLabel)" },
            onSelect: { model.setTimer($0) }
        )
    }
}
