import AppKit
import DesignSystem
import Observation
import Shared
import SwiftUI

@MainActor
@Observable
final class AppPreferences {
    var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "appLanguage") }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
        language = AppLanguage(rawValue: saved) ?? .english
    }

    func text(_ key: String) -> String {
        AppStrings.text(key, language: language)
    }
}

@main
struct MilyonusApp: App {
    @State private var preferences = AppPreferences()

    init() {
        let fontsRegistered = BrandFonts.register()
        if CommandLine.arguments.contains("--smoke-test") {
            let isPackaged = Bundle.main.bundleURL.pathExtension == "app"
            let resourcePath = Bundle.main.resourceURL?.standardizedFileURL.path
            let embeddedResources = !isPackaged || (
                AppStrings.resourceBundleURL.deletingLastPathComponent().standardizedFileURL.path == resourcePath
                    && BrandFonts.resourceBundleURL.deletingLastPathComponent().standardizedFileURL.path == resourcePath
            )
            let englishLoaded = AppStrings.text("Workspace", language: .english) == "Workspace"
            let turkishLoaded = AppStrings.text("Workspace", language: .turkish) == "Çalışma alanı"
                && AppStrings.text("Settings", language: .turkish) == "Ayarlar"
            let valid = fontsRegistered && embeddedResources && englishLoaded && turkishLoaded
            print(valid
                ? "Bundle smoke test: English, Turkish, and both brand fonts verified."
                : "Bundle smoke test failed: fonts=\(fontsRegistered), embedded=\(embeddedResources), "
                + "english=\(englishLoaded), turkish=\(turkishLoaded).")
            if !embeddedResources {
                print("Bundle smoke paths: main=\(Bundle.main.bundleURL.path), "
                    + "resources=\(Bundle.main.resourceURL?.path ?? "missing"), "
                    + "strings=\(AppStrings.resourceBundleURL.path), "
                    + "fonts=\(BrandFonts.resourceBundleURL.path).")
            }
            exit(valid ? 0 : 1)
        }
    }

    var body: some Scene {
        WindowGroup("Milyonus Nottaker", id: "main") {
            WorkspaceView(preferences: preferences)
                .preferredColorScheme(.dark)
                .tint(DesignTokens.Palette.brand)
        }
        .defaultSize(width: DesignTokens.Layout.windowWidth, height: DesignTokens.Layout.windowHeight)
        .windowStyle(.hiddenTitleBar)

        Settings {
            PreferencesView(preferences: preferences)
                .padding(DesignTokens.Space.section)
                .frame(width: DesignTokens.Layout.settingsWidth)
                .background(DesignTokens.Palette.canvas)
                .preferredColorScheme(.dark)
        }

        MenuBarExtra("Milyonus Nottaker", systemImage: "waveform") {
            MenuBarContent(preferences: preferences)
        }

        #if DEBUG
            Window(preferences.text("Component gallery"), id: "gallery") {
                ScrollView {
                    ComponentGallery(preferences: preferences)
                        .padding(DesignTokens.Space.section)
                }
                .frame(
                    minWidth: DesignTokens.Layout.galleryMinimumWidth,
                    minHeight: DesignTokens.Layout.galleryMinimumHeight
                )
                .foregroundStyle(DesignTokens.Palette.foreground)
                .background(DesignTokens.Palette.canvas)
                .preferredColorScheme(.dark)
            }
            .defaultSize(width: DesignTokens.Layout.galleryWidth, height: DesignTokens.Layout.galleryHeight)
            .commands { GalleryCommands(preferences: preferences) }
        #endif
    }
}

#if DEBUG
    private struct GalleryCommands: Commands {
        @Environment(\.openWindow) private var openWindow
        let preferences: AppPreferences

        var body: some Commands {
            CommandMenu(preferences.text("Developer")) {
                Button(preferences.text("Open component gallery")) {
                    openWindow(id: "gallery")
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
            }
        }
    }
#endif

private struct MenuBarContent: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    let preferences: AppPreferences

    var body: some View {
        Text(verbatim: preferences.text("No recording in progress"))
        Divider()
        Button(preferences.text("Open Milyonus")) {
            openWindow(id: "main")
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut("o")
        Button(preferences.text("Settings")) {
            openSettings()
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",")
        Divider()
        Button(preferences.text("Quit Milyonus")) { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
