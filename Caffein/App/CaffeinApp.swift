import SwiftData
import SwiftUI

@main
struct CaffeinApp: App {
    init() {
        AppDefaults.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.caffeine)
        }
        .modelContainer(for: AppSchema.models)
    }
}

struct RootView: View {
    @AppStorage(SettingsKey.didOnboard) private var didOnboard = false
    @AppStorage(AppLanguage.storageKey) private var languageRaw = AppLanguage.system.rawValue

    var body: some View {
        let language = AppLanguage(rawValue: languageRaw) ?? .system
        content
            .environment(\.locale, language.locale)
            // Arabic (and any other right-to-left language) mirrors the layout.
            .environment(\.layoutDirection,
                         Locale.Language(identifier: language.resolvedCode).characterDirection == .rightToLeft
                             ? .rightToLeft : .leftToRight)
    }

    @ViewBuilder
    private var content: some View {
        if didOnboard {
            TabView {
                NavigationStack { TodayView() }
                    .tabItem { Label("Bugün", systemImage: "sun.max.fill") }
                NavigationStack { WeeklyView() }
                    .tabItem { Label("Haftam", systemImage: "chart.bar.xaxis") }
            }
            // Rebuild when the language changes, so strings built in code refresh too.
            .id(languageRaw)
        } else {
            OnboardingView { didOnboard = true }
        }
    }
}
