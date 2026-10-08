import SwiftUI
import UIKit

@main
struct ChatApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store: ChatStore
    @AppStorage("appearance") private var appearance = AppAppearance.system.rawValue
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.system.rawValue

    init() {
        AppLogger.startSession()
        _store = StateObject(wrappedValue: ChatStore())
    }

    var body: some Scene {
        WindowGroup {
            AppContainerView(store: store)
                .preferredColorScheme(AppAppearance(rawValue: appearance)?.colorScheme)
                .environment(\.locale, selectedLanguage.locale ?? .current)
                .onChange(of: scenePhase) { _, newPhase in
                    AppLogger.record("lifecycle", "scene_phase", metadata: ["value": String(describing: newPhase)])
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
                    AppLogger.recordSynchronously("memory", "memory_warning")
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                    AppLogger.markCleanTermination()
                }
        }
    }

    private var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguage) ?? .system
    }
}
