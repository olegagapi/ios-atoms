import ProgressiveSlider
import SwiftUI
import UIKit

/// Hosts the UIKit screen inside the SwiftUI catalog.
struct ProgressiveSliderUIKitExamples: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ProgressiveSliderUIKitViewController {
        ProgressiveSliderUIKitViewController()
    }

    func updateUIViewController(_ uiViewController: ProgressiveSliderUIKitViewController, context: Context) {}
}

final class ProgressiveSliderUIKitViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        for demo in ProgressiveSliderDemo.allCases {
            stack.addArrangedSubview(DemoCard(demo: demo))
        }
        stack.addArrangedSubview(OptionsCard())

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
        ])
    }
}

/// A rounded card with a title, a value readout, the slider and a footnote.
private class Card: UIView {
    let titleLabel = UILabel()
    let valueLabel = UILabel()
    let detailLabel = UILabel()
    let footnoteLabel = UILabel()
    let content = UIStackView()

    init() {
        super.init(frame: .zero)
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 16
        layer.cornerCurve = .continuous

        titleLabel.font = .preferredFont(forTextStyle: .headline)
        valueLabel.font = .monospacedDigitSystemFont(
            ofSize: UIFont.preferredFont(forTextStyle: .title2).pointSize, weight: .semibold)
        detailLabel.font = .preferredFont(forTextStyle: .footnote)
        detailLabel.textColor = .secondaryLabel
        detailLabel.setContentHuggingPriority(.required, for: .horizontal)
        footnoteLabel.font = .preferredFont(forTextStyle: .footnote)
        footnoteLabel.textColor = .secondaryLabel
        footnoteLabel.numberOfLines = 0

        let readout = UIStackView(arrangedSubviews: [valueLabel, detailLabel])
        readout.alignment = .firstBaseline

        content.axis = .vertical
        content.spacing = 8
        content.translatesAutoresizingMaskIntoConstraints = false
        [titleLabel, readout].forEach(content.addArrangedSubview)
        addSubview(content)

        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private final class DemoCard: Card {
    private let demo: ProgressiveSliderDemo
    private let slider: ProgressiveUISlider

    init(demo: ProgressiveSliderDemo) {
        self.demo = demo
        slider = ProgressiveUISlider(scale: demo.scale, value: demo.initialValue)
        super.init()

        titleLabel.text = demo.title
        footnoteLabel.text = "\(demo.summary)\n\(demo.scale.description)"

        slider.accessibilityLabel = demo.title
        slider.accessibilityValueFormatter = { demo.format($0) }
        slider.addTarget(self, action: #selector(valueChanged), for: .valueChanged)

        content.addArrangedSubview(slider)
        content.addArrangedSubview(footnoteLabel)
        valueChanged()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func valueChanged() {
        valueLabel.text = demo.format(slider.value)
        detailLabel.text = "step \(demo.formatStep(at: slider.value))"
    }
}

/// Shows the non-continuous mode, editing events, images and colors.
private final class OptionsCard: Card {
    private let demo = ProgressiveSliderDemo.speed
    private let slider: ProgressiveUISlider
    private var deliveredCount = 0

    override init() {
        slider = ProgressiveUISlider(scale: ProgressiveSliderDemo.speed.scale, value: ProgressiveSliderDemo.speed.initialValue)
        super.init()

        titleLabel.text = "Options"
        footnoteLabel.text = "isContinuous = false, so .valueChanged is sent once per drag. Images, tint colors and haptics turned off."

        slider.isContinuous = false
        slider.isHapticFeedbackEnabled = false
        slider.minimumTrackTintColor = .systemOrange
        slider.minimumValueImage = UIImage(systemName: "tortoise")
        slider.maximumValueImage = UIImage(systemName: "hare")
        slider.accessibilityLabel = "Playback speed"
        slider.accessibilityValueFormatter = { [demo] in demo.format($0) }
        slider.addTarget(self, action: #selector(valueChanged), for: .valueChanged)
        slider.addTarget(self, action: #selector(editingChanged), for: [.editingDidBegin, .editingDidEnd])

        let reset = UIButton(configuration: .bordered(), primaryAction: UIAction(title: "Reset to 1×") { [weak self] _ in
            guard let self else { return }
            slider.setValue(1, animated: true)
            render()
        })
        reset.contentHorizontalAlignment = .leading

        content.addArrangedSubview(slider)
        content.addArrangedSubview(reset)
        content.addArrangedSubview(footnoteLabel)
        render()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func valueChanged() {
        deliveredCount += 1
        render()
    }

    @objc private func editingChanged() {
        render()
    }

    private func render() {
        valueLabel.text = demo.format(slider.value)
        detailLabel.text = "\(deliveredCount) events"
    }
}
