import SwiftUI

@main
struct CatalogApp: App {
    var body: some Scene {
        WindowGroup {
            CatalogView()
        }
    }
}

/// One entry per component. Add new components here.
enum CatalogEntry: String, CaseIterable, Identifiable, Hashable {
    case progressiveSlider

    var id: Self { self }

    var title: String {
        switch self {
        case .progressiveSlider: "Progressive Slider"
        }
    }

    var summary: String {
        switch self {
        case .progressiveSlider: "A slider whose step size grows along the track."
        }
    }

    var systemImage: String {
        switch self {
        case .progressiveSlider: "slider.horizontal.3"
        }
    }

    @MainActor @ViewBuilder
    var destination: some View {
        switch self {
        case .progressiveSlider: ProgressiveSliderScreen()
        }
    }
}

struct CatalogView: View {
    /// Launch with `-open <entry>` (for example `-open progressiveSlider`) to jump
    /// straight to a component.
    @State private var path: [CatalogEntry] = UserDefaults.standard.string(forKey: "open")
        .flatMap(CatalogEntry.init(rawValue:))
        .map { [$0] } ?? []

    var body: some View {
        NavigationStack(path: $path) {
            List(CatalogEntry.allCases) { entry in
                NavigationLink(value: entry) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title)
                            Text(entry.summary)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: entry.systemImage)
                    }
                }
            }
            .navigationTitle("iOS Atoms")
            .navigationDestination(for: CatalogEntry.self) { entry in
                entry.destination
            }
        }
    }
}
