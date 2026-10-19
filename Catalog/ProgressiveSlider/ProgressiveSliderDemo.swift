import Foundation
import ProgressiveSlider

/// The Progressive Slider example configurations, shared by the SwiftUI and UIKit screens.
enum ProgressiveSliderDemo: String, CaseIterable, Identifiable, Sendable {
    case basic
    case price
    case aroundZero
    case duration
    case speed

    var id: Self { self }

    var title: String {
        switch self {
        case .basic: "Basic"
        case .price: "Max price"
        case .aroundZero: "Fine-tune around zero"
        case .duration: "Timer"
        case .speed: "Playback speed"
        }
    }

    var summary: String {
        switch self {
        case .basic: "0.1 steps up to 1, then 1 steps up to 10."
        case .price: "Built with .decades: the step grows tenfold at 10, 100 and 1,000."
        case .aroundZero: "Negative range with fine steps close to zero."
        case .duration: "Seconds, then minutes, then 5-minute steps, each taking a third of the track (custom weights)."
        case .speed: "Doesn't start at zero: 0.05× steps below 1×, 0.25× steps above."
        }
    }

    var scale: ProgressiveScale {
        switch self {
        case .basic:
            ProgressiveScale(from: 0, [
                .to(1, step: 0.1),
                .to(10, step: 1),
            ])
        case .price:
            .decades(through: 10_000, initialStep: 1)
        case .aroundZero:
            ProgressiveScale(from: -10, [
                .to(-1, step: 1),
                .to(1, step: 0.1),
                .to(10, step: 1),
            ])
        case .duration:
            // Values are seconds.
            ProgressiveScale(from: 0, [
                .to(60, step: 5, weight: 1),
                .to(600, step: 60, weight: 1),
                .to(3600, step: 300, weight: 1),
            ])
        case .speed:
            ProgressiveScale(from: 0.25, [
                .to(1, step: 0.05),
                .to(4, step: 0.25),
            ])
        }
    }

    var initialValue: Double {
        switch self {
        case .basic: 0.5
        case .price: 200
        case .aroundZero: 0
        case .duration: 300
        case .speed: 1
        }
    }

    func format(_ value: Double) -> String {
        switch self {
        case .basic:
            return value.formatted(.number.precision(.fractionLength(scale.fractionDigits(at: value))))
        case .price:
            return value.formatted(.currency(code: "USD").precision(.fractionLength(0)))
        case .aroundZero:
            return value.formatted(.number
                .precision(.fractionLength(scale.fractionDigits(at: value)))
                .sign(strategy: .always(includingZero: false)))
        case .duration:
            return Duration.seconds(value).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated))
        case .speed:
            return value.formatted(.number.precision(.fractionLength(0...2))) + "×"
        }
    }

    func formatStep(at value: Double) -> String {
        let step = scale.step(at: value)
        switch self {
        case .duration:
            return Duration.seconds(step).formatted(.units(allowed: [.minutes, .seconds], width: .abbreviated))
        case .price:
            return step.formatted(.currency(code: "USD").precision(.fractionLength(0)))
        default:
            return step.formatted()
        }
    }
}
