import SwiftUI
import StoreKit
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @AppStorage("appearance") private var appearance = AppAppearance.system.rawValue
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.system.rawValue
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("soundsEnabled") private var soundsEnabled = true
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @State private var showsNotificationDeniedAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.appearance) {
                    Picker(L10n.theme, selection: $appearance) {
                        ForEach(AppAppearance.allCases) { theme in
                            Label(theme.title, systemImage: theme.icon)
                                .tag(theme.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                }

                Section(L10n.general) {
                    Toggle(isOn: $hapticsEnabled) {
                        SettingsLabel(
                            title: L10n.haptics,
                            subtitle: L10n.hapticsDescription,
                            symbol: "waveform.path",
                            color: AppTheme.accent
                        )
                    }
                    .tint(AppTheme.accent)

                    Toggle(isOn: $soundsEnabled) {
                        SettingsLabel(
                            title: L10n.buttonSounds,
                            subtitle: L10n.buttonSoundsDescription,
                            symbol: "speaker.wave.2.fill",
                            color: .orange
                        )
                    }
                    .tint(AppTheme.accent)

                    Toggle(isOn: $notificationsEnabled) {
                        SettingsLabel(
                            title: L10n.notifications,
                            subtitle: L10n.notificationsDescription,
                            symbol: "bell.badge.fill",
                            color: .red
                        )
                    }
                    .tint(AppTheme.accent)
                    .onChange(of: notificationsEnabled) { _, enabled in
                        SoundFeedback.button()
                        guard enabled else { return }
                        Task {
                            let granted = await NotificationManager.requestAuthorization()
                            if !granted {
                                notificationsEnabled = false
                                showsNotificationDeniedAlert = true
                            }
                        }
                    }

                    Picker(selection: $appLanguage) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.title)
                                .tag(language.rawValue)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            settingsIcon("globe", color: .blue)
                            Text(L10n.language)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section(L10n.aiService) {
                    HStack(spacing: 12) {
                        settingsIcon("sparkles", color: AppTheme.accent)
                        Text(L10n.provider)
                        Spacer()
                        Text("Groq · Qwen 3.8")
                            .foregroundStyle(.secondary)
                    }
                }

                Section(L10n.about) {
                    Button {
                        SoundFeedback.button()
                        requestReview()
                    } label: {
                        HStack(spacing: 12) {
                            settingsIcon("star.fill", color: .yellow)
                            Text(L10n.rateUs)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(.tertiary)
                        }
                    }

                    HStack(spacing: 12) {
                        settingsIcon("info.circle.fill", color: .gray)
                        Text(L10n.version)
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .id(appLanguage)
            .navigationTitle(L10n.settings)
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.done) {
                        SoundFeedback.button()
                        dismiss()
                    }
                        .fontWeight(.semibold)
                }
            }
        }
        .tint(AppTheme.accent)
        .preferredColorScheme(selectedAppearance.colorScheme)
        .environment(\.locale, selectedLanguage.locale ?? .current)
        .alert(L10n.notificationsDeniedTitle, isPresented: $showsNotificationDeniedAlert) {
            Button(L10n.cancel, role: .cancel) {}
            Button(L10n.openSystemSettings) {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
        } message: {
            Text(L10n.notificationsDeniedMessage)
        }
    }

    private var selectedAppearance: AppAppearance {
        AppAppearance(rawValue: appearance) ?? .system
    }

    private var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguage) ?? .system
    }

    private func settingsIcon(_ symbol: String, color: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 29, height: 29)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}

private struct SettingsLabel: View {
    let title: String
    let subtitle: String
    let symbol: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 29, height: 29)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
