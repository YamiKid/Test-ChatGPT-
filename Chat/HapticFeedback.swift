import UIKit

enum HapticFeedback {
    private static var isEnabled: Bool {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: "hapticsEnabled") == nil || defaults.bool(forKey: "hapticsEnabled")
    }

    static func light() {
        SoundFeedback.button()
        guard isEnabled else { return }
#if targetEnvironment(simulator)
        return
#else
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
    }

    static func selection() {
        SoundFeedback.button()
        guard isEnabled else { return }
#if targetEnvironment(simulator)
        return
#else
        UISelectionFeedbackGenerator().selectionChanged()
#endif
    }

    static func success() {
        SoundFeedback.button()
        guard isEnabled else { return }
#if targetEnvironment(simulator)
        return
#else
        UINotificationFeedbackGenerator().notificationOccurred(.success)
#endif
    }
}
