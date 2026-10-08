import SwiftUI

struct AppContainerView: View {
    @ObservedObject var store: ChatStore
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var isLoading = true

    var body: some View {
        ZStack {
            if isLoading {
                LaunchLoadingView()
                    .transition(.opacity.combined(with: .scale(scale: 1.03)))
            } else if !hasCompletedOnboarding {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else {
                RootView(store: store)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.32), value: isLoading)
        .animation(.easeInOut(duration: 0.32), value: hasCompletedOnboarding)
        .task {
            guard isLoading else { return }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            isLoading = false
        }
    }
}

private struct LaunchLoadingView: View {
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            Circle()
                .fill(AppTheme.accent.opacity(0.18))
                .frame(width: 290, height: 290)
                .blur(radius: 70)
                .offset(x: 120, y: -260)

            VStack(spacing: 20) {
                GarnetMark(size: 82)
                    .shadow(color: AppTheme.accent.opacity(0.28), radius: 24, y: 10)
                Text("Garnet")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                ProgressView()
                    .tint(AppTheme.accent)
                    .controlSize(.regular)
                Text(L10n.loading)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct OnboardingPage: Identifiable {
    let id: Int
    let symbol: String
    let title: String
    let subtitle: String
}

private struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var selection = 0

    private var pages: [OnboardingPage] {
        [
            .init(
                id: 0,
                symbol: "sparkles",
                title: L10n.onboardingWelcomeTitle,
                subtitle: L10n.onboardingWelcomeSubtitle
            ),
            .init(
                id: 1,
                symbol: "bubble.left.and.bubble.right.fill",
                title: L10n.onboardingChatsTitle,
                subtitle: L10n.onboardingChatsSubtitle
            ),
            .init(
                id: 2,
                symbol: "photo.on.rectangle.angled",
                title: L10n.onboardingImagesTitle,
                subtitle: L10n.onboardingImagesSubtitle
            )
        ]
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            LinearGradient(
                colors: [AppTheme.accent.opacity(0.16), .clear, AppTheme.accentSoft.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 8) {
                HStack {
                    GarnetMark(size: 38)
                    Text("Garnet")
                        .font(.headline)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                TabView(selection: $selection) {
                    ForEach(pages) { page in
                        VStack(spacing: 28) {
                            Spacer()
                            Image(systemName: page.symbol)
                                .font(.system(size: 58, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 132, height: 132)
                                .background(
                                    LinearGradient(
                                        colors: [AppTheme.accent, AppTheme.accentSoft],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    in: RoundedRectangle(cornerRadius: 38, style: .continuous)
                                )
                                .shadow(color: AppTheme.accent.opacity(0.28), radius: 24, y: 12)

                            VStack(spacing: 12) {
                                Text(page.title)
                                    .font(.system(size: 30, weight: .bold, design: .rounded))
                                    .multilineTextAlignment(.center)
                                Text(page.subtitle)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(4)
                                    .frame(maxWidth: 330)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 28)
                        .tag(page.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                Button {
                    SoundFeedback.button()
                    if selection < pages.count - 1 {
                        withAnimation(.snappy) { selection += 1 }
                    } else {
                        onComplete()
                    }
                } label: {
                    Text(selection == pages.count - 1 ? L10n.getStarted : L10n.next)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [AppTheme.accent, AppTheme.accentSoft],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
    }
}
