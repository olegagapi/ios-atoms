# iOS Atoms

A personal collection of reusable iOS components and code snippets. Each component
ships as its own Swift Package library with a SwiftUI version and, where it makes
sense, a UIKit one.

## Components

| Component | What it does | Platforms |
| --- | --- | --- |
| [ProgressiveSlider](Components/ProgressiveSlider) | A slider whose step size grows along the track: 0.1 steps up to 1, then 1 steps up to 10, and so on. SwiftUI + UIKit. | iOS 17+ |

## Snippets

Copy-paste code that's too small for a component lives in [`Snippets/`](Snippets)
as Markdown files.

## Using a component

Add the package once and pick the libraries you need. Each component is a
separate product, so your app only links what it imports.

```swift
// Package.swift
.package(url: "https://github.com/olegagapi/ios-atoms", branch: "main"),

.target(name: "MyApp", dependencies: [
    .product(name: "ProgressiveSlider", package: "ios-atoms"),
])
```

In Xcode: **File › Add Package Dependencies…**, paste the URL, choose the libraries.

## Layout

```
ios-atoms/
├── Package.swift              one library product per component
├── Components/
│   └── <Name>/
│       ├── README.md          usage and API
│       ├── Sources/           the library
│       └── Tests/             unit tests (swift test)
├── Snippets/                  Markdown snippets
└── Catalog/                   demo app for every component
    ├── project.yml            xcodegen spec (the .xcodeproj is generated, not committed)
    ├── App/                   catalog list
    ├── <Name>/                demo screens for one component
    └── Tests/<Name>/          tests that need a running app
```

## Catalog app

The Catalog app lists every component with live demos. The Xcode project is
generated from `Catalog/project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
brew install xcodegen          # once
cd Catalog
xcodegen generate
open Catalog.xcodeproj
```

Launch arguments, handy for screenshots: `-open progressiveSlider` opens a
component's page directly.

## Tests

```sh
swift test                                   # all component unit tests, on macOS

cd Catalog && xcodegen generate
xcodebuild test -project Catalog.xcodeproj -scheme Catalog \
  -destination 'platform=iOS Simulator,name=<simulator name>'   # tests hosted in the app
```

`xcodebuild -list` at the repo root shows the scheme for running the package
tests on an iOS simulator. It's `ios-atoms` while there's one product, and becomes
`ios-atoms-Package` once there are several.

## Adding a component

1. Create `Components/<Name>/Sources`, `Tests` and a `README.md`.
2. In `Package.swift`, add a `.library` product plus a `.target` and `.testTarget`
   whose `path`s point at those folders.
3. Add demo screens in `Catalog/<Name>/`, add the folder to the `Catalog` target's
   `sources` in `Catalog/project.yml`, and add a case to `CatalogEntry` in
   `Catalog/App/CatalogApp.swift`.
4. Put app-hosted tests (UIKit controls, SwiftUI hosting) in `Catalog/Tests/<Name>/`.
5. Prefix demo type names with the component name. The Catalog is a single module,
   so a plain `Demo` would collide.
6. Add a row to the table above.
