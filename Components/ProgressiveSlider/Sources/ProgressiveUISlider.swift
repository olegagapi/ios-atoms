#if canImport(UIKit) && !os(tvOS) && !os(watchOS)
import UIKit

/// A UIKit slider whose step size changes along the track, as described by a
/// ``ProgressiveScale``.
///
/// ```swift
/// let slider = ProgressiveUISlider(scale: ProgressiveScale(from: 0, [
///     .to(1, step: 0.1),
///     .to(10, step: 1),
/// ]))
/// slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
/// ```
///
/// The thumb snaps from stop to stop while dragging and `value` is always a stop.
///
/// Events:
/// - `.valueChanged` when the user moves `value` to a different stop. If
///   `isContinuous` is `false`, it's sent once when the drag ends instead.
///   Setting `value` in code doesn't send it.
/// - `.editingDidBegin` and `.editingDidEnd` when a drag starts and ends.
open class ProgressiveUISlider: UIControl {

    /// The scale that maps the track to values. Changing it snaps `value` to the new scale.
    public var scale: ProgressiveScale {
        didSet {
            currentValue = scale.snapped(currentValue)
            syncThumb(animated: false)
        }
    }

    /// The current value, always a stop on `scale`. Assigned values are snapped
    /// to the nearest stop.
    public var value: Double {
        get { currentValue }
        set { setValue(newValue, animated: false) }
    }

    /// Whether `.valueChanged` is sent during a drag (`true`) or only when it ends.
    public var isContinuous = true

    /// Whether the slider plays a selection haptic each time a drag reaches a new stop.
    public var isHapticFeedbackEnabled = true

    /// Formats `value` for VoiceOver. By default the number is spoken with as many
    /// decimals as it has, using the current locale.
    public var accessibilityValueFormatter: ((Double) -> String)?

    private var currentValue: Double
    private var valueAtDragStart: Double
    private let slider = UISlider()
    #if os(iOS)
    private var feedbackGenerator: UISelectionFeedbackGenerator?
    #endif

    public init(scale: ProgressiveScale, value: Double? = nil) {
        self.scale = scale
        currentValue = scale.snapped(value ?? scale.lowerBound)
        valueAtDragStart = currentValue
        super.init(frame: .zero)
        commonInit()
    }

    /// Creates a slider with a plain `0...1` scale in steps of `0.01`. Set `scale` afterwards.
    public override init(frame: CGRect) {
        scale = ProgressiveScale(from: 0, [.to(1, step: 0.01)])
        currentValue = 0
        valueAtDragStart = 0
        super.init(frame: frame)
        commonInit()
    }

    /// Creates a slider with a plain `0...1` scale in steps of `0.01`. Set `scale` afterwards.
    public required init?(coder: NSCoder) {
        scale = ProgressiveScale(from: 0, [.to(1, step: 0.01)])
        currentValue = 0
        valueAtDragStart = 0
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.isContinuous = true
        slider.isAccessibilityElement = false
        slider.translatesAutoresizingMaskIntoConstraints = false
        addSubview(slider)
        NSLayoutConstraint.activate([
            slider.leadingAnchor.constraint(equalTo: leadingAnchor),
            slider.trailingAnchor.constraint(equalTo: trailingAnchor),
            slider.topAnchor.constraint(equalTo: topAnchor),
            slider.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        slider.addTarget(self, action: #selector(sliderMoved), for: .valueChanged)
        slider.addTarget(self, action: #selector(dragBegan), for: .touchDown)
        slider.addTarget(self, action: #selector(dragEnded), for: [.touchUpInside, .touchUpOutside, .touchCancel])

        isAccessibilityElement = true
        syncThumb(animated: false)
    }

    /// Sets the value, snapped to the nearest stop, optionally animating the thumb.
    /// Doesn't send `.valueChanged`.
    public func setValue(_ value: Double, animated: Bool) {
        currentValue = scale.snapped(value)
        syncThumb(animated: animated)
    }

    // MARK: - Appearance

    public var minimumTrackTintColor: UIColor? {
        get { slider.minimumTrackTintColor }
        set { slider.minimumTrackTintColor = newValue }
    }

    public var maximumTrackTintColor: UIColor? {
        get { slider.maximumTrackTintColor }
        set { slider.maximumTrackTintColor = newValue }
    }

    public var thumbTintColor: UIColor? {
        get { slider.thumbTintColor }
        set { slider.thumbTintColor = newValue }
    }

    public var minimumValueImage: UIImage? {
        get { slider.minimumValueImage }
        set { slider.minimumValueImage = newValue }
    }

    public var maximumValueImage: UIImage? {
        get { slider.maximumValueImage }
        set { slider.maximumValueImage = newValue }
    }

    public func setThumbImage(_ image: UIImage?, for state: UIControl.State) {
        slider.setThumbImage(image, for: state)
    }

    public func setMinimumTrackImage(_ image: UIImage?, for state: UIControl.State) {
        slider.setMinimumTrackImage(image, for: state)
    }

    public func setMaximumTrackImage(_ image: UIImage?, for state: UIControl.State) {
        slider.setMaximumTrackImage(image, for: state)
    }

    open override var isEnabled: Bool {
        didSet { slider.isEnabled = isEnabled }
    }

    // MARK: - Interaction

    @objc private func dragBegan() {
        valueAtDragStart = currentValue
        #if os(iOS)
        if isHapticFeedbackEnabled {
            feedbackGenerator = UISelectionFeedbackGenerator()
            feedbackGenerator?.prepare()
        }
        #endif
        sendActions(for: .editingDidBegin)
    }

    @objc private func sliderMoved() {
        let newValue = scale.value(atPosition: Double(slider.value))
        // Pull the thumb onto the stop so it moves in discrete steps.
        slider.value = Float(scale.position(for: newValue))
        guard newValue != currentValue else { return }
        currentValue = newValue
        #if os(iOS)
        feedbackGenerator?.selectionChanged()
        feedbackGenerator?.prepare()
        #endif
        if isContinuous || !slider.isTracking {
            sendActions(for: .valueChanged)
        }
    }

    @objc private func dragEnded() {
        if !isContinuous && currentValue != valueAtDragStart {
            sendActions(for: .valueChanged)
        }
        #if os(iOS)
        feedbackGenerator = nil
        #endif
        sendActions(for: .editingDidEnd)
    }

    private func syncThumb(animated: Bool) {
        slider.setValue(Float(scale.position(for: currentValue)), animated: animated)
    }

    // MARK: - Accessibility

    open override var accessibilityTraits: UIAccessibilityTraits {
        get { isEnabled ? .adjustable : [.adjustable, .notEnabled] }
        set {}
    }

    open override var accessibilityValue: String? {
        get { accessibilityValueFormatter?(currentValue) ?? scale.accessibilityDescription(of: currentValue) }
        set {}
    }

    open override func accessibilityIncrement() {
        adjust(to: scale.value(after: currentValue))
    }

    open override func accessibilityDecrement() {
        adjust(to: scale.value(before: currentValue))
    }

    private func adjust(to newValue: Double) {
        guard isEnabled, newValue != currentValue else { return }
        currentValue = newValue
        syncThumb(animated: false)
        sendActions(for: .valueChanged)
    }
}
#endif
