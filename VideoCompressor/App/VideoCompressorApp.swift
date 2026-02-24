import SwiftUI
import AppKit

@main
struct VideoCompressorApp: App {
    @StateObject private var languageStore = LanguageStore()
    @StateObject private var themeStore = ThemeStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(languageStore)
                .environmentObject(themeStore)
                .environment(\.locale, languageStore.locale)
                .preferredColorScheme(themeStore.preferredScheme)
                .frame(minWidth: 880, minHeight: 700)
                .onAppear {
                    if let iconPath = Bundle.module.path(forResource: "AppIcon1024", ofType: "png"),
                       let image = NSImage(contentsOfFile: iconPath) {
                        NSApp.applicationIconImage = image
                    }
                }
        }
        .windowResizability(.contentSize)
    }
}
