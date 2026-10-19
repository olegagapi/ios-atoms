import ProgressiveSlider
import SwiftUI

struct ProgressiveSliderSwiftUIExamples: View {
    var body: some View {
        List {
            ForEach(ProgressiveSliderDemo.allCases) { demo in
                Section {
                    DemoRow(demo: demo)
                } header: {
                    Text(demo.title)
                } footer: {
                    Text("\(demo.summary)\n\(demo.scale.description)")
                }
            }

            Section {
                OptionsRow()
            } header: {
                Text("Labels & options")
            } footer: {
                Text("Value labels, a label, an editing callback, and haptics turned off.")
            }
        }
    }
}

private struct DemoRow: View {
    let demo: ProgressiveSliderDemo
    @State private var value: Double

    init(demo: ProgressiveSliderDemo) {
        self.demo = demo
        _value = State(initialValue: demo.initialValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(demo.format(value))
                    .font(.title2.monospacedDigit().weight(.semibold))
                    .contentTransition(.numericText(value: value))
                    .animation(.snappy, value: value)
                Spacer()
                Text("step \(demo.formatStep(at: value))")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ProgressiveSlider(value: $value, scale: demo.scale) {
                Text(demo.title)
            }
            .progressiveSliderAccessibilityValue { demo.format($0) }
        }
        .padding(.vertical, 4)
    }
}

private struct OptionsRow: View {
    private let demo = ProgressiveSliderDemo.speed
    @State private var value = ProgressiveSliderDemo.speed.initialValue
    @State private var isEditing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(demo.format(value))
                    .font(.title2.monospacedDigit().weight(.semibold))
                Spacer()
                Text(isEditing ? "editing" : "idle")
                    .font(.footnote)
                    .foregroundStyle(isEditing ? .orange : .secondary)
            }

            ProgressiveSlider(value: $value, scale: demo.scale) {
                Text("Playback speed")
            } minimumValueLabel: {
                Image(systemName: "tortoise")
            } maximumValueLabel: {
                Image(systemName: "hare")
            } onEditingChanged: { editing in
                isEditing = editing
            }
            .tint(.orange)
            .progressiveSliderHapticFeedback(false)
            .progressiveSliderAccessibilityValue { demo.format($0) }

            Button("Reset to 1×") {
                withAnimation { value = 1 }
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        ProgressiveSliderSwiftUIExamples()
    }
}
