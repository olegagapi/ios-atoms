import ProgressiveSlider
import SwiftUI
import Testing
import UIKit

private let scale = ProgressiveScale(from: 0, [
    .to(1, step: 0.1),
    .to(10, step: 1),
])

/// Position of the stop at `index`; with default weights the 19 steps are evenly spaced.
private func position(ofStop index: Double) -> Float {
    Float(index / 19)
}

@MainActor
private func findSlider(in view: UIView) -> UISlider? {
    if let slider = view as? UISlider { return slider }
    return view.subviews.lazy.compactMap(findSlider(in:)).first
}

/// Simulates the system slider reporting a raw drag position.
@MainActor
private func drag(_ slider: UISlider, to position: Float) {
    slider.value = position
    slider.sendActions(for: .valueChanged)
}

@MainActor
private final class EventRecorder: NSObject {
    var events: [String] = []
    @objc func valueChanged() { events.append("valueChanged") }
    @objc func began() { events.append("began") }
    @objc func ended() { events.append("ended") }
}

@MainActor
@Suite("ProgressiveUISlider")
struct ProgressiveUISliderTests {

    @Test func dragSnapsThumbAndValue() throws {
        let control = ProgressiveUISlider(scale: scale)
        let slider = try #require(findSlider(in: control))

        drag(slider, to: position(ofStop: 3.3))
        #expect(control.value == 0.3)
        #expect(slider.value == position(ofStop: 3))

        drag(slider, to: position(ofStop: 12.6))
        #expect(control.value == 4)
        #expect(slider.value == position(ofStop: 13))
    }

    @Test func valueChangedFiresOncePerNewStop() throws {
        let control = ProgressiveUISlider(scale: scale)
        let recorder = EventRecorder()
        control.addTarget(recorder, action: #selector(EventRecorder.valueChanged), for: .valueChanged)
        let slider = try #require(findSlider(in: control))

        drag(slider, to: position(ofStop: 2.8))
        drag(slider, to: position(ofStop: 3.1)) // same stop (0.3)
        drag(slider, to: position(ofStop: 3.2)) // same stop
        drag(slider, to: position(ofStop: 4))
        #expect(recorder.events == ["valueChanged", "valueChanged"])
    }

    @Test func nonContinuousSendsOnRelease() throws {
        let control = ProgressiveUISlider(scale: scale)
        control.isContinuous = false
        let recorder = EventRecorder()
        control.addTarget(recorder, action: #selector(EventRecorder.valueChanged), for: .valueChanged)
        control.addTarget(recorder, action: #selector(EventRecorder.began), for: .editingDidBegin)
        control.addTarget(recorder, action: #selector(EventRecorder.ended), for: .editingDidEnd)
        let slider = try #require(findSlider(in: control))

        slider.sendActions(for: .touchDown)
        slider.sendActions(for: .touchUpInside)
        #expect(recorder.events == ["began", "ended"]) // nothing moved

        recorder.events = []
        slider.sendActions(for: .touchDown)
        // `isTracking` is only true during a real touch, so move the value directly
        // as a stand-in for the tracked drag.
        control.setValue(0.5, animated: false)
        slider.sendActions(for: .touchUpInside)
        #expect(recorder.events == ["began", "valueChanged", "ended"])
    }

    @Test func settingValueSnapsWithoutSendingActions() {
        let control = ProgressiveUISlider(scale: scale)
        let recorder = EventRecorder()
        control.addTarget(recorder, action: #selector(EventRecorder.valueChanged), for: .valueChanged)

        control.value = 0.34
        #expect(control.value == 0.3)
        control.value = 99
        #expect(control.value == 10)
        #expect(recorder.events.isEmpty)
    }

    @Test func changingScaleResnapsValue() {
        let control = ProgressiveUISlider(scale: scale, value: 7)
        control.scale = ProgressiveScale(from: 0, [.to(5, step: 0.5)])
        #expect(control.value == 5)
    }

    @Test func accessibilityStepsThroughStops() {
        let control = ProgressiveUISlider(scale: scale, value: 0.9)
        let recorder = EventRecorder()
        control.addTarget(recorder, action: #selector(EventRecorder.valueChanged), for: .valueChanged)

        #expect(control.accessibilityTraits.contains(.adjustable))
        control.accessibilityIncrement()
        #expect(control.value == 1)
        control.accessibilityIncrement()
        #expect(control.value == 2)
        control.accessibilityDecrement()
        control.accessibilityDecrement()
        #expect(control.value == 0.9)
        #expect(recorder.events.count == 4)
    }

    @Test func accessibilityValueIsTheRealValue() {
        let control = ProgressiveUISlider(scale: scale, value: 0.3)
        #expect(control.accessibilityValue == 0.3.formatted(.number.precision(.fractionLength(0...1))))
        control.accessibilityValueFormatter = { "\($0) ms" }
        #expect(control.accessibilityValue == "0.3 ms")
    }
}

@MainActor
private final class ValueBox: ObservableObject {
    @Published var value = 0.0
}

@MainActor
private struct Host: View {
    @ObservedObject var box: ValueBox
    var body: some View {
        ProgressiveSlider(value: $box.value, scale: scale)
    }
}

@MainActor
@Suite("ProgressiveSlider (SwiftUI)")
struct ProgressiveSliderSwiftUITests {

    private func makeWindow(_ root: some View) -> UIWindow {
        let scene = UIApplication.shared.connectedScenes.first as! UIWindowScene
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 200)
        window.rootViewController = UIHostingController(rootView: root)
        window.makeKeyAndVisible()
        settle(window)
        return window
    }

    /// Lets SwiftUI process pending updates.
    private func settle(_ window: UIWindow) {
        for _ in 0..<5 {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
            window.layoutIfNeeded()
        }
    }

    @Test func dragSnapsThumbEvenWhenTheValueDoesNotChange() throws {
        let box = ValueBox()
        let window = makeWindow(Host(box: box))

        let slider = try #require(findSlider(in: window), "SwiftUI Slider is not backed by UISlider here")

        drag(slider, to: position(ofStop: 3.3))
        settle(window)
        #expect(box.value == 0.3)
        #expect(abs(slider.value - position(ofStop: 3)) < 1e-6)

        // Moving within the same stop doesn't change the value, but the thumb must still snap back.
        drag(slider, to: position(ofStop: 3.4))
        settle(window)
        #expect(box.value == 0.3)
        #expect(abs(slider.value - position(ofStop: 3)) < 1e-6)

        drag(slider, to: position(ofStop: 12.6))
        settle(window)
        #expect(box.value == 4)
        #expect(abs(slider.value - position(ofStop: 13)) < 1e-6)
    }

    @Test func externalValueIsShownAtItsStop() throws {
        let box = ValueBox()
        box.value = 5
        let window = makeWindow(Host(box: box))

        let slider = try #require(findSlider(in: window))
        #expect(abs(slider.value - position(ofStop: 14)) < 1e-6)

        box.value = 0.7
        settle(window)
        #expect(abs(slider.value - position(ofStop: 7)) < 1e-6)
    }
}
