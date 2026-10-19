#if !os(tvOS)
import SwiftUI

/// A SwiftUI slider whose step size changes along the track, as described by a
/// ``ProgressiveScale``.
///
/// ```swift
/// @State private var amount = 0.5
///
/// ProgressiveSlider(value: $amount, scale: ProgressiveScale(from: 0, [
///     .to(1, step: 0.1),
///     .to(10, step: 1),
/// ])) {
///     Text("Amount")
/// }
/// ```
///
/// It wraps the system `Slider`, so it looks and behaves like one. The slider only
/// ever writes stops to `value`; a value set from outside is shown at its nearest stop.
public struct ProgressiveSlider<Label: View, ValueLabel: View>: View {
    @Binding private var value: Double
    private let scale: ProgressiveScale
    private let label: Label
    private let minimumValueLabel: ValueLabel
    private let maximumValueLabel: ValueLabel
    private let onEditingChanged: (Bool) -> Void

    @State private var isEditing = false

    @Environment(\.progressiveSliderHapticFeedback) private var hapticFeedback
    @Environment(\.progressiveSliderAccessibilityValue) private var accessibilityValueFormatter

    /// Creates a slider with a label and labels for the minimum and maximum values.
    public init<V: BinaryFloatingPoint>(
        value: Binding<V>,
        scale: ProgressiveScale,
        @ViewBuilder label: () -> Label,
        @ViewBuilder minimumValueLabel: () -> ValueLabel,
        @ViewBuilder maximumValueLabel: () -> ValueLabel,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        _value = Binding(
            get: { Double(value.wrappedValue) },
            set: { value.wrappedValue = V($0) }
        )
        self.scale = scale
        self.label = label()
        self.minimumValueLabel = minimumValueLabel()
        self.maximumValueLabel = maximumValueLabel()
        self.onEditingChanged = onEditingChanged
    }

    public var body: some View {
        Slider(
            value: position,
            in: 0...1,
            label: { label },
            minimumValueLabel: { minimumValueLabel },
            maximumValueLabel: { maximumValueLabel },
            onEditingChanged: editingChanged
        )
        .accessibilityValue(Text(accessibilityValue))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = scale.value(after: value)
            case .decrement: value = scale.value(before: value)
            @unknown default: break
            }
        }
        #if !os(visionOS)
        .sensoryFeedback(.selection, trigger: value) { _, _ in
            hapticFeedback && isEditing
        }
        #endif
    }

    /// The system slider works in track positions; this translates them to stops.
    /// The slider reads the position back after every change, so the thumb snaps
    /// to the stop while dragging.
    private var position: Binding<Double> {
        Binding(
            get: { scale.position(for: scale.snapped(value)) },
            set: { newPosition in
                let newValue = scale.value(atPosition: newPosition)
                if newValue != value {
                    value = newValue
                }
            }
        )
    }

    private var accessibilityValue: String {
        let current = scale.snapped(value)
        return accessibilityValueFormatter?(current) ?? scale.accessibilityDescription(of: current)
    }

    private func editingChanged(_ editing: Bool) {
        isEditing = editing
        onEditingChanged(editing)
    }
}

extension ProgressiveSlider where ValueLabel == EmptyView {
    /// Creates a slider with a label.
    public init<V: BinaryFloatingPoint>(
        value: Binding<V>,
        scale: ProgressiveScale,
        @ViewBuilder label: () -> Label,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.init(value: value, scale: scale, label: label,
                  minimumValueLabel: { EmptyView() }, maximumValueLabel: { EmptyView() },
                  onEditingChanged: onEditingChanged)
    }
}

extension ProgressiveSlider where Label == EmptyView, ValueLabel == EmptyView {
    /// Creates a slider without labels.
    public init<V: BinaryFloatingPoint>(
        value: Binding<V>,
        scale: ProgressiveScale,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.init(value: value, scale: scale, label: { EmptyView() }, onEditingChanged: onEditingChanged)
    }
}

// MARK: - Configuration

extension View {
    /// Sets whether progressive sliders in this view play a selection haptic each
    /// time a drag reaches a new stop. On by default.
    public func progressiveSliderHapticFeedback(_ enabled: Bool) -> some View {
        environment(\.progressiveSliderHapticFeedback, enabled)
    }

    /// Sets how progressive sliders in this view describe their value to VoiceOver.
    /// By default the number is spoken with as many decimals as it has.
    public func progressiveSliderAccessibilityValue(_ format: @escaping @Sendable (Double) -> String) -> some View {
        environment(\.progressiveSliderAccessibilityValue, format)
    }
}

private struct HapticFeedbackKey: EnvironmentKey {
    static let defaultValue = true
}

private struct AccessibilityValueKey: EnvironmentKey {
    static let defaultValue: (@Sendable (Double) -> String)? = nil
}

extension EnvironmentValues {
    fileprivate var progressiveSliderHapticFeedback: Bool {
        get { self[HapticFeedbackKey.self] }
        set { self[HapticFeedbackKey.self] = newValue }
    }

    fileprivate var progressiveSliderAccessibilityValue: (@Sendable (Double) -> String)? {
        get { self[AccessibilityValueKey.self] }
        set { self[AccessibilityValueKey.self] = newValue }
    }
}
#endif
