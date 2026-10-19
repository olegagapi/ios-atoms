# Snippets

Small, copy-paste pieces of code that don't deserve their own component: an
extension, a view modifier, a debugging helper.

## Conventions

- One Markdown file per snippet, named after what it does:
  `keyboard-avoiding-scroll-view.md`, `uicolor-hex-init.md`.
- Each file has a one-line summary, the code in a ```` ```swift ```` block, a short usage
  example, and the minimum iOS version if it matters.
- **Don't put `.swift` files in this folder.** SwiftPM treats a root-level
  `Snippets/` directory as [package snippets](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0356-swift-snippets.md)
  and compiles every `.swift` file here as a macOS executable, so a UIKit snippet
  would break `swift build`.
- When a snippet grows tests, configuration or more than one file, promote it to
  `Components/`.

## Index

_Nothing here yet._
