import SwiftUI

struct SidebarView: View {
    @ObservedObject var store: ChatStore
    let topInset: CGFloat
    let bottomInset: CGFloat
    let onNewChat: () -> Void
    let onSettings: () -> Void
    let onDismiss: () -> Void

    @State private var searchText = ""
    @State private var renameTarget: ChatThread?
    @State private var deleteTarget: ChatThread?
    @State private var renameText = ""
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            header
            searchField
            newChatButton
            history
            settingsButton
        }
        .padding(.top, max(topInset, 12) + 10)
        .padding(.bottom, max(bottomInset, 10) + 8)
        .background(drawerBackground)
        .clipShape(.rect(bottomTrailingRadius: 30, topTrailingRadius: 30))
        .shadow(color: .black.opacity(0.24), radius: 28, x: 12)
        .ignoresSafeArea(edges: .vertical)
        .offset(x: min(0, dragOffset))
        .gesture(
            DragGesture(minimumDistance: 12)
                .onChanged { value in
                    if value.translation.width < 0 { dragOffset = value.translation.width }
                }
                .onEnded { value in
                    if value.translation.width < -70 || value.predictedEndTranslation.width < -120 {
                        onDismiss()
                    }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { dragOffset = 0 }
                }
        )
        .alert(L10n.renameChat, isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            TextField(L10n.name, text: $renameText)
            Button(L10n.cancel, role: .cancel) { renameTarget = nil }
            Button(L10n.save) {
                if let renameTarget { store.renameChat(renameTarget.id, to: renameText) }
                renameTarget = nil
            }
        }
        .confirmationDialog(
            L10n.deleteChat,
            isPresented: Binding(
                get: { deleteTarget != nil },
                set: { if !$0 { deleteTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(L10n.delete, role: .destructive) {
                if let deleteTarget { store.deleteChat(deleteTarget.id) }
                deleteTarget = nil
            }
            Button(L10n.cancel, role: .cancel) { deleteTarget = nil }
        } message: {
            Text(L10n.deleteChatMessage)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            GarnetMark(size: 42)
            VStack(alignment: .leading, spacing: 1) {
                Text("Garnet")
                    .font(.title3.bold())
                Text(L10n.conversations)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 38, height: 38)
                    .background(.primary.opacity(0.07), in: Circle())
            }
            .accessibilityLabel(L10n.close)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(L10n.searchChats, text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 45)
        .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .padding(.horizontal, 14)
    }

    private var newChatButton: some View {
        Button(action: onNewChat) {
            HStack(spacing: 11) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 16, weight: .semibold))
                Text(L10n.newChat)
                    .font(.subheadline.bold())
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.caption.bold())
                    .opacity(0.8)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(
                LinearGradient(
                    colors: [AppTheme.accent, AppTheme.accentSoft],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .shadow(color: AppTheme.accent.opacity(0.22), radius: 12, y: 5)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 18)
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.history.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.8)
                Spacer()
                if !store.sortedChats.isEmpty {
                    Text("\(store.sortedChats.count)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.primary.opacity(0.06), in: Capsule())
                }
            }
            .padding(.horizontal, 20)

            if filteredChats.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 5) {
                        if searchText.isEmpty {
                            if !store.pinnedChats.isEmpty {
                                sectionLabel(L10n.pinned, icon: "pin.fill")
                                chatRows(store.pinnedChats)
                            }
                            if !store.recentChats.isEmpty {
                                sectionLabel(L10n.recent, icon: "clock")
                                chatRows(store.recentChats)
                            }
                        } else {
                            chatRows(filteredChats)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 12)
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: searchText.isEmpty ? "bubble.left.and.bubble.right" : "magnifyingglass")
                .font(.system(size: 27, weight: .medium))
                .foregroundStyle(AppTheme.accent)
            Text(searchText.isEmpty ? L10n.noChats : L10n.noResults)
                .font(.subheadline.weight(.semibold))
            Text(searchText.isEmpty ? L10n.noChatsDescription : L10n.noResultsDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 230)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 50)
    }

    private var settingsButton: some View {
        Button(action: onSettings) {
            HStack(spacing: 12) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 34, height: 34)
                    .background(AppTheme.accent.opacity(0.1), in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text(L10n.settings)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(L10n.settingsDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2.bold())
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .frame(height: 58)
            .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.top, 8)
    }

    private func sectionLabel(_ title: String, icon: String) -> some View {
        Label(title.uppercased(), systemImage: icon)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.secondary)
            .tracking(0.7)
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 3)
    }

    @ViewBuilder
    private func chatRows(_ chats: [ChatThread]) -> some View {
        ForEach(chats) { chat in
            HStack(spacing: 0) {
                Button {
                    store.selectChat(chat.id)
                    onDismiss()
                } label: {
                    ChatHistoryRow(
                        chat: chat,
                        isSelected: store.selectedChatID == chat.id,
                        isGenerating: store.isGenerating(chat.id)
                    )
                }
                .buttonStyle(.plain)

                Menu {
                    Button {
                        store.togglePin(chat.id)
                    } label: {
                        Label(chat.isPinned ? L10n.unpin : L10n.pin, systemImage: chat.isPinned ? "pin.slash" : "pin")
                    }
                    Button {
                        SoundFeedback.button()
                        beginRenaming(chat)
                    } label: {
                        Label(L10n.rename, systemImage: "pencil")
                    }
                    Divider()
                    Button(role: .destructive) {
                        SoundFeedback.button()
                        deleteTarget = chat
                    } label: {
                        Label(L10n.delete, systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(L10n.chatActions)
            }
            .padding(.trailing, 4)
            .background(
                store.selectedChatID == chat.id ? AppTheme.accent.opacity(0.11) : Color.clear,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .contextMenu {
                Button {
                    store.togglePin(chat.id)
                } label: {
                    Label(chat.isPinned ? L10n.unpin : L10n.pin, systemImage: chat.isPinned ? "pin.slash" : "pin")
                }
                Button {
                    SoundFeedback.button()
                    beginRenaming(chat)
                } label: {
                    Label(L10n.rename, systemImage: "pencil")
                }
                Button(role: .destructive) {
                    SoundFeedback.button()
                    deleteTarget = chat
                } label: {
                    Label(L10n.delete, systemImage: "trash")
                }
            }
        }
    }

    private func beginRenaming(_ chat: ChatThread) {
        renameTarget = chat
        renameText = chat.title
    }

    private var filteredChats: [ChatThread] {
        guard !searchText.isEmpty else { return store.sortedChats }
        return store.sortedChats.filter { chat in
            chat.title.localizedCaseInsensitiveContains(searchText) ||
            chat.messages.contains { $0.text.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private var drawerBackground: some View {
        ZStack {
            Rectangle().fill(.regularMaterial)
            LinearGradient(
                colors: [AppTheme.accent.opacity(0.08), .clear, AppTheme.accentSoft.opacity(0.045)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Rectangle().fill(AppTheme.background.opacity(0.72))
        }
    }
}

private struct ChatHistoryRow: View {
    let chat: ChatThread
    let isSelected: Bool
    let isGenerating: Bool

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: isSelected ? "bubble.left.fill" : "bubble.left")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : AppTheme.accent)
                .frame(width: 34, height: 34)
                .background(isSelected ? AppTheme.accent : AppTheme.accent.opacity(0.1), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(chat.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(preview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)
            if isGenerating {
                ProgressView()
                    .controlSize(.mini)
                    .tint(AppTheme.accent)
            }
            if chat.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.accent)
            }
            Text(chat.updatedAt, format: .dateTime.day().month(.abbreviated))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 11)
        .frame(height: 58)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var preview: String {
        guard let message = chat.messages.last(where: { !$0.text.isEmpty || !$0.attachments.isEmpty }) else {
            return L10n.emptyChat
        }
        return message.text.isEmpty ? L10n.photo : message.text
    }
}
