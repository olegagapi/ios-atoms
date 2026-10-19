# ProgressiveSlider

A slider whose step size grows along the track: fine steps at the low end, coarse
steps further up. Ships as a SwiftUI view and a UIKit control, both driven by the
same `ProgressiveScale`.

```
0 ─ 0.1 ─ 0.2 ─ … ─ 0.9 ─ 1 ── 2 ── 3 ── … ── 9 ── 10
└──────── step 0.1 ────────┘└──────── step 1 ────────┘
```

- iOS 17+ (SwiftUI and UIKit). Also builds for macOS 14+ (SwiftUI only) and
  visionOS 1+ (no haptics there).
- No dependencies. Part of [ios-atoms](../../README.md).

## Install

In Xcode, **File › Add Package Dependencies…**, enter
`https://github.com/olegagapi/ios-atoms`, and add the `ProgressiveSlider` library.
Or in `Package.swift`:

```swift
.package(url: "https://github.com/olegagapi/ios-atoms", branch: "main"),
// …
.target(name: "MyApp", dependencies: [
    .product(name: "ProgressiveSlider", package: "ios-atoms"),
])
```

The repo is private for now. If it stays private, Xcode needs your GitHub account
signed in under **Settings › Accounts** to fetch it.

## Describe the scale

A scale is a lower bound plus segments, each with an upper bound and a step:

```swift
import ProgressiveSlider

let scale = ProgressiveScale(from: 0, [
    .to(1, step: 0.1),   // 0, 0.1, 0.2 … 1
    .to(10, step: 1),    // 2, 3 … 10
])
```

- **Any number of segments**, any lower bound (negative ranges work too).
- **Stops**: the slider only produces a segment's lower bound plus whole steps,
  or its upper bound. If a step doesn't divide its segment evenly, the upper
  bound is still a stop. Stops are rounded to the step's decimals, so you get
  `0.3`, not `0.30000000000000004`.
- **Track share**: by default a segment's share of the track is proportional to
  its number of steps, so every step is the same distance apart. Pass `weight:`
  to control the share yourself:

  ```swift
  // Seconds, minutes, then 5-minute steps, each a third of the track.
  ProgressiveScale(from: 0, [
      .to(60, step: 5, weight: 1),
      .to(600, step: 60, weight: 1),
      .to(3600, step: 300, weight: 1),
  ])
  ```

- **Preset**: `.decades(through:initialStep:)` grows the step tenfold at each power
  of ten. `ProgressiveScale.decades(through: 1000, initialStep: 0.1)` gives
  0…1 by 0.1, 1…10 by 1, 10…100 by 10, 100…1000 by 100.

Invalid configurations (no segments, bounds not ascending, a step ≤ 0) trap with
a message, like `ClosedRange` does.

The scale is a plain value type, so you can also use it without a slider:

| API | Purpose |
| --- | --- |
| `position(for:)` / `value(atPosition:)` | Map between a value and a track position in `0...1` |
| `snapped(_:)` | The nearest stop to a value |
| `value(after:)` / `value(before:)` | The next and previous stops |
| `step(at:)` / `fractionDigits(at:)` | The step in effect at a value, and the decimals it needs (useful for formatting) |
| `range`, `boundaries`, `stops` | Inspect the scale |

## SwiftUI

```swift
@State private var amount = 0.5

ProgressiveSlider(value: $amount, scale: scale) {
    Text("Amount")
}
```

It wraps the system `Slider`, so it looks native on every iOS version, and has the
same initializers: label only, label plus `minimumValueLabel` and
`maximumValueLabel`, and `onEditingChanged`. The binding can be any
`BinaryFloatingPoint` type.

```swift
ProgressiveSlider(value: $speed, scale: speedScale) {
    Text("Playback speed")
} minimumValueLabel: {
    Image(systemName: "tortoise")
} maximumValueLabel: {
    Image(systemName: "hare")
} onEditingChanged: { editing in
    isEditing = editing
}
.tint(.orange)
.progressiveSliderHapticFeedback(false)                     // on by default
.progressiveSliderAccessibilityValue { "\($0) times" }      // VoiceOver value
```

The slider only writes stops to the binding. It never rewrites a value you set
yourself; a value that isn't a stop is shown at its nearest stop.

## UIKit

```swift
let slider = ProgressiveUISlider(scale: scale, value: 0.5)
slider.addTarget(self, action: #selector(amountChanged), for: .valueChanged)

@objc func amountChanged(_ sender: ProgressiveUISlider) {
    print(sender.value) // always a stop
}
```

`ProgressiveUISlider` is a `UIControl` that wraps a `UISlider`. Its `value` is a
`Double` on your scale; values you assign are snapped to the nearest stop.

| Property / method | Notes |
| --- | --- |
| `scale` | Changing it re-snaps `value` |
| `value`, `setValue(_:animated:)` | Doesn't send `.valueChanged`, like `UISlider` |
| `isContinuous` | `false` sends `.valueChanged` once, when the drag ends |
| `isHapticFeedbackEnabled` | Selection haptic on each new stop (default `true`) |
| `accessibilityValueFormatter` | What VoiceOver reads for the value |
| `minimumTrackTintColor`, `maximumTrackTintColor`, `thumbTintColor`, `minimumValueImage`, `maximumValueImage`, `setThumbImage(_:for:)`, `setMinimumTrackImage(_:for:)`, `setMaximumTrackImage(_:for:)` | Passed to the inner `UISlider` |

Events: `.valueChanged` when the user moves to a new stop, and `.editingDidBegin`
and `.editingDidEnd` around each drag. `init(frame:)` and `init(coder:)` start
with a plain `0...1` scale in steps of 0.01, so it also works from Interface Builder.
Set `scale` afterwards.

## Behaviour in both versions

- The thumb snaps from stop to stop while dragging. `.valueChanged` and the
  binding update only when the stop changes.
- VoiceOver reads the real value, not the track percentage. Swiping up or down
  moves one stop, so the step changes at segment boundaries the same way dragging does.
- A selection haptic plays on each new stop while dragging (off for VoiceOver
  adjustments).
- One difference: if you set a value that isn't a stop, `ProgressiveUISlider`
  snaps it (`value = 250` reads back as `300` on a 100-step segment), while the
  SwiftUI view leaves your binding alone and only draws the thumb at the nearest stop.

> **Note:** the module and the SwiftUI view are both named `ProgressiveSlider`.
> Import the module and use the types directly; writing
> `ProgressiveSlider.ProgressiveScale` won't compile because Swift resolves the
> name to the view.

## Examples and tests

The [Catalog app](../../Catalog) has a **Progressive Slider** page with five demos,
each in both SwiftUI and UIKit (switch with the segmented control): basic (0.1, then 1),
price (`.decades`), around zero, timer (custom weights) and playback speed (options,
value labels, non-continuous). The demo code is in
[`Catalog/ProgressiveSlider/`](../../Catalog/ProgressiveSlider).

| What | Where | Run |
| --- | --- | --- |
| Scale math (22 tests) | [`Tests/`](Tests) | `swift test` from the repo root |
| Slider behaviour, both versions (9 tests) | [`Catalog/Tests/ProgressiveSlider/`](../../Catalog/Tests/ProgressiveSlider) | The Catalog scheme's tests (see the [root README](../../README.md#catalog-app)) |

The behaviour tests run inside the Catalog app because `UIControl` only dispatches
actions inside a running `UIApplication`.
