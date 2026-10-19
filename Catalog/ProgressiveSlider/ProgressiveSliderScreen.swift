import SwiftUI

/// The catalog page for Progressive Slider: the same demos in SwiftUI and UIKit.
struct ProgressiveSliderScreen: View {
    enum Variant: String {
        case swiftUI
        case uiKit
    }

    /// Remembered between launches. Can also be passed as `-progressiveSliderVariant uiKit`.
    @AppStorage("progressiveSliderVariant") private var variant = Variant.swiftUI

    var body: some View {
        Group {
            switch variant {
            case .swiftUI:
                ProgressiveSliderSwiftUIExamples()
            case .uiKit:
                ProgressiveSliderUIKitExamples()
                    .ignoresSafeArea()
            }
        }
        .navigationTitle("Progressive Slider")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Framework", selection: $variant) {
                    Text("SwiftUI").tag(Variant.swiftUI)
                    Text("UIKit").tag(Variant.uiKit)
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
        }
    }
}
