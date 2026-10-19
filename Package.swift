// swift-tools-version: 5.9
import PackageDescription

// Every component is its own library product, so apps only link what they use.
// Each one lives in Components/<Name>/ with Sources/, Tests/ and a README.

let package = Package(
    name: "ios-atoms",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "ProgressiveSlider", targets: ["ProgressiveSlider"]),
    ],
    targets: [
        // MARK: ProgressiveSlider
        .target(
            name: "ProgressiveSlider",
            path: "Components/ProgressiveSlider/Sources"
        ),
        .testTarget(
            name: "ProgressiveSliderTests",
            dependencies: ["ProgressiveSlider"],
            path: "Components/ProgressiveSlider/Tests"
        ),
    ]
)
