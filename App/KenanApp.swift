import SwiftUI

@main
struct KenanApp: App {
    @StateObject private var studio = Studio()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(studio)
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "ar"))
                .preferredColorScheme(.dark)
                .tint(Gold.light)
                .task { studio.onLaunch() }
                .onChange(of: phase) { _, p in if p == .active { studio.refreshOnForeground() } }
        }
    }
}
