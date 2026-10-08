import SwiftUI

enum AppTheme {
    static let accent = Color(red: 0.29, green: 0.36, blue: 0.96)
    static let accentSoft = Color(red: 0.46, green: 0.34, blue: 0.98)
    static let cornerRadius: CGFloat = 22

    static let background = Color(uiColor: .systemBackground)
    static let secondaryBackground = Color(uiColor: .secondarySystemBackground)
    static let tertiaryBackground = Color(uiColor: .tertiarySystemBackground)
}

struct GarnetMark: View {
    var size: CGFloat = 32

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppTheme.accent, AppTheme.accentSoft, .pink.opacity(0.88)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "sparkles")
                .font(.system(size: size * 0.43, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: AppTheme.accent.opacity(0.22), radius: size * 0.22, y: size * 0.08)
        .accessibilityHidden(true)
    }
}

extension View {
    func softCard() -> some View {
        self
            .background(AppTheme.secondaryBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                    .stroke(.primary.opacity(0.06), lineWidth: 1)
            }
    }
}
