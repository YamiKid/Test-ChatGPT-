import AudioToolbox
import Foundation

enum SoundFeedback {
    private static var isEnabled: Bool {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: "soundsEnabled") == nil || defaults.bool(forKey: "soundsEnabled")
    }

    static func button() {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(1104)
    }
}
