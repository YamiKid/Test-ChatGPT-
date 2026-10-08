import SwiftUI
import UIKit

struct RootView: View {
    @ObservedObject var store: ChatStore
    @State private var showsSidebar = false
    @State private var showsSettings = false
    @State private var showsNewChatDialog = false
    @State private var newChatTitle = ""
    @State private var renameTargetID: UUID?
    @State private var renameText = ""
    @State private var deleteTargetID: UUID?
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.system.rawValue

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                NavigationStack {
                    ZStack {
                        AppTheme.background.ignoresSafeArea()
                        ambientBackground

                        if let chat = store.selectedChat, !chat.messages.isEmpty {
                            ConversationView(store: store)
                        } else {
                            WelcomeView { prompt in
                                store.send(prompt)
                            }
                        }
                    }
                    .navigationTitle(store.selectedChat?.title ?? "Garnet")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                SoundFeedback.button()
                                withAnimation(drawerAnimation) { showsSidebar = true }
                            } label: {
                                Image(systemName: "line.3.horizontal")
                            }
                            .accessibilityLabel(L10n.openChats)
                        }

                        ToolbarItem(placement: .principal) { chatTitle }

                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                SoundFeedback.button()
                                newChatTitle = ""
                                showsNewChatDialog = true
                            } label: {
                                Image(systemName: "square.and.pencil")
                            }
                            .accessibilityLabel(L10n.newChat)
                        }
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        ComposerView(
                            isGenerating: store.generationState == .generating,
                            onSend: { text, attachments in
                                store.send(text, attachments: attachments)
                            },
                            onStop: store.stopGeneration
                        )
                    }
                }
                .id(appLanguage)
                .toolbarBackground(AppTheme.background, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .scaleEffect(showsSidebar ? 0.985 : 1, anchor: .trailing)
                .offset(x: showsSidebar ? 18 : 0)
                .disabled(showsSidebar)

                if showsSidebar {
                    Color.black.opacity(0.34)
                        .ignoresSafeArea()
                        .onTapGesture { closeDrawer() }
                        .transition(.opacity)

                    SidebarView(
                        store: store,
                        topInset: geometry.safeAreaInsets.top,
                        bottomInset: geometry.safeAreaInsets.bottom,
                        onNewChat: requestNewChat,
                        onSettings: openSettings,
                        onDismiss: closeDrawer
                    )
                        .frame(width: min(geometry.size.width * 0.88, 370))
                        .transition(.move(edge: .leading).combined(with: .opacity))
                        .zIndex(2)
                }
            }
            .animation(drawerAnimation, value: showsSidebar)
        }
        .tint(AppTheme.accent)
        .background(KeyboardDismissRecognizer())
        .sheet(isPresented: $showsSettings) {
            SettingsView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .alert(L10n.createChat, isPresented: $showsNewChatDialog) {
            TextField(L10n.chatTitleOptional, text: $newChatTitle)
            Button(L10n.cancel, role: .cancel) {
                finishNewChatDialog()
            }
            Button(L10n.create) {
                createChatAndCloseDialog()
            }
        } message: {
            Text(L10n.chatTitleHint)
        }
        .alert(L10n.renameChat, isPresented: Binding(
            get: { renameTargetID != nil },
            set: { if !$0 { renameTargetID = nil } }
        )) {
            TextField(L10n.name, text: $renameText)
            Button(L10n.cancel, role: .cancel) { renameTargetID = nil }
            Button(L10n.save) {
                SoundFeedback.button()
                if let renameTargetID { store.renameChat(renameTargetID, to: renameText) }
                renameTargetID = nil
            }
        }
        .confirmationDialog(
            L10n.deleteChat,
            isPresented: Binding(
                get: { deleteTargetID != nil },
                set: { if !$0 { deleteTargetID = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(L10n.delete, role: .destructive) {
                SoundFeedback.button()
                if let deleteTargetID { store.deleteChat(deleteTargetID) }
                deleteTargetID = nil
            }
            Button(L10n.cancel, role: .cancel) { deleteTargetID = nil }
        } message: {
            Text(L10n.deleteChatMessage)
        }
    }

    @ViewBuilder
    private var chatTitle: some View {
        if let chat = store.selectedChat {
            Menu {
                Button {
                    SoundFeedback.button()
                    renameTargetID = chat.id
                    renameText = chat.title
                } label: {
                    Label(L10n.rename, systemImage: "pencil")
                }
                Button {
                    store.togglePin(chat.id)
                } label: {
                    Label(chat.isPinned ? L10n.unpin : L10n.pin, systemImage: chat.isPinned ? "pin.slash" : "pin")
                }
                Divider()
                Button(role: .destructive) {
                    SoundFeedback.button()
                    deleteTargetID = chat.id
                } label: {
                    Label(L10n.delete, systemImage: "trash")
                }
            } label: {
                HStack(spacing: 5) {
                    Text(chat.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.82)
                        .frame(maxWidth: 145)
                    Image(systemName: "chevron.down")
                        .font(.caption2.bold())
                        .foregroundStyle(.tertiary)
                }
                .frame(width: 165)
                .foregroundStyle(.primary)
                .contentShape(Rectangle())
            }
            .accessibilityLabel(L10n.chatActions)
        } else {
            HStack(spacing: 8) {
                GarnetMark(size: 27)
                Text("Garnet")
                    .font(.headline)
            }
        }
    }

    private var drawerAnimation: Animation {
        .spring(response: 0.38, dampingFraction: 0.86)
    }

    private func closeDrawer() {
        SoundFeedback.button()
        withAnimation(drawerAnimation) { showsSidebar = false }
    }

    private func requestNewChat() {
        closeDrawer()
        newChatTitle = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            showsNewChatDialog = true
        }
    }

    private func openSettings() {
        closeDrawer()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            showsSettings = true
        }
    }

    private func createChatAndCloseDialog() {
        let title = newChatTitle
        dismissKeyboard()
        showsNewChatDialog = false
        newChatTitle = ""
        store.createChat(title: title)
    }

    private func finishNewChatDialog() {
        SoundFeedback.button()
        dismissKeyboard()
        showsNewChatDialog = false
        newChatTitle = ""
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private var ambientBackground: some View {
        GeometryReader { proxy in
            Circle()
                .fill(AppTheme.accent.opacity(0.09))
                .frame(width: proxy.size.width * 0.9)
                .blur(radius: 70)
                .offset(x: proxy.size.width * 0.42, y: -proxy.size.height * 0.2)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

private struct WelcomeView: View {
    let onPromptSelected: (String) -> Void

    private var suggestions: [(String, String)] {
        [
            ("lightbulb.max", L10n.suggestionIdeas),
            ("text.book.closed", L10n.suggestionExplain),
            ("checklist", L10n.suggestionPlan)
        ]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                Spacer(minLength: 66)

                GarnetMark(size: 64)
                VStack(spacing: 8) {
                    Text(L10n.welcomeTitle)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.primary, AppTheme.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    Text(L10n.welcomeSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                }

                VStack(spacing: 10) {
                    ForEach(suggestions, id: \.1) { suggestion in
                        Button {
                            onPromptSelected(suggestion.1)
                        } label: {
                            HStack(spacing: 13) {
                                Image(systemName: suggestion.0)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(AppTheme.accent)
                                    .frame(width: 26)
                                Text(suggestion.1)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 17)
                            .padding(.vertical, 15)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .softCard()
                    }
                }
                .frame(maxWidth: 430)
                .padding(.horizontal, 20)

                Spacer(minLength: 34)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.immediately)
    }
}

private struct ConversationView: View {
    @ObservedObject var store: ChatStore

    private var chat: ChatThread? { store.selectedChat }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 22) {
                    ForEach((chat?.messages ?? []).filter { !$0.text.isEmpty || !$0.attachments.isEmpty }) { message in
                        MessageRow(
                            message: message,
                            isStreaming: false
                        )
                        .equatable()
                        .id(message.id)
                    }

                    if
                        store.generationState == .generating,
                        chat?.messages.last?.role == .assistant,
                        chat?.messages.last?.text.isEmpty == true
                    {
                        ThinkingRow()
                    }

                    if case .failed(let failure) = store.generationState {
                        FailureCard(failure: failure, onRetry: store.retry)
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("chat-bottom")
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 18)
                .transaction { transaction in
                    transaction.animation = nil
                    transaction.disablesAnimations = true
                }
            }
            .id(chat?.id)
            .defaultScrollAnchor(.bottom, for: .initialOffset)
            .scrollDismissesKeyboard(.immediately)
            .onScrollPhaseChange { _, phase in
                guard let chatID = chat?.id else { return }
                switch phase {
                case .tracking, .interacting, .decelerating:
                    store.setUserScrolling(true, in: chatID)
                case .idle:
                    store.setUserScrolling(false, in: chatID)
                case .animating:
                    break
                }
            }
            .task(id: chat?.id) {
                await Task.yield()
                guard !Task.isCancelled else { return }
                proxy.scrollTo("chat-bottom", anchor: .bottom)
            }
            .onDisappear {
                if let chatID = chat?.id {
                    store.setUserScrolling(false, in: chatID)
                }
            }
        }
    }
}

private struct MessageRow: View, Equatable {
    let message: ChatMessage
    let isStreaming: Bool
    @State private var copied = false

    static func == (lhs: MessageRow, rhs: MessageRow) -> Bool {
        lhs.message == rhs.message && lhs.isStreaming == rhs.isStreaming
    }

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            if message.role == .assistant {
                GarnetMark(size: 30)
            } else {
                Spacer(minLength: 46)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                Group {
                    if message.role == .assistant {
                        if isStreaming {
                            Text(message.text)
                                .font(.body)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            MarkdownMessageView(text: message.text)
                        }
                    } else {
                        UserMessageContent(message: message)
                    }
                }

                if message.role == .assistant && !message.text.isEmpty {
                    Button {
                        UIPasteboard.general.string = message.text
                        copied = true
                        HapticFeedback.success()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { copied = false }
                    } label: {
                        Label(copied ? L10n.copied : L10n.copy, systemImage: copied ? "checkmark" : "doc.on.doc")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(copied ? AppTheme.accent : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .assistant {
                Spacer(minLength: 16)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message.role == .user ? L10n.you : "Garnet"): \(message.text)")
    }
}

private struct UserMessageContent: View {
    let message: ChatMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            if !imageAttachments.isEmpty {
                attachmentGrid
            }
            if !fileAttachments.isEmpty {
                VStack(spacing: 6) {
                    ForEach(fileAttachments) { attachment in
                        HStack(spacing: 10) {
                            Image(systemName: fileIcon(for: attachment))
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(AppTheme.accent)
                                .frame(width: 34, height: 34)
                                .background(AppTheme.accent.opacity(0.11), in: RoundedRectangle(cornerRadius: 9))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(attachment.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Text(fileTypeTitle(for: attachment))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(9)
                        .background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 13))
                    }
                }
            }
            if !message.text.isEmpty {
                Text(message.text)
                    .font(.body)
                    .textSelection(.enabled)
                    .padding(.horizontal, message.attachments.isEmpty ? 4 : 7)
                    .padding(.vertical, message.attachments.isEmpty ? 3 : 5)
            }
        }
        .padding(message.attachments.isEmpty ? 10 : 7)
        .frame(maxWidth: 290, alignment: .leading)
        .background(
            LinearGradient(
                colors: [AppTheme.accent.opacity(0.18), AppTheme.accentSoft.opacity(0.11)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }

    private var attachmentGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 5) {
            ForEach(imageAttachments) { attachment in
                if let image = UIImage(data: attachment.previewData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: imageAttachments.count == 1 ? 190 : 126)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
            }
        }
    }

    private var gridColumns: [GridItem] {
        imageAttachments.count == 1
            ? [GridItem(.flexible())]
            : [GridItem(.flexible()), GridItem(.flexible())]
    }

    private var imageAttachments: [ChatAttachment] {
        message.attachments.filter(\.isImage)
    }

    private var fileAttachments: [ChatAttachment] {
        message.attachments.filter { !$0.isImage }
    }

    private func fileIcon(for attachment: ChatAttachment) -> String {
        if attachment.mimeType == "application/pdf" { return "doc.richtext.fill" }
        if attachment.mimeType.contains("json") { return "curlybraces.square.fill" }
        if attachment.mimeType.contains("csv") { return "tablecells.fill" }
        return "doc.text.fill"
    }

    private func fileTypeTitle(for attachment: ChatAttachment) -> String {
        if attachment.mimeType == "application/pdf" { return "PDF" }
        return L10n.textDocument
    }
}

private struct ThinkingRow: View {
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            GarnetMark(size: 30)
            ProgressView()
                .controlSize(.small)
            Text(L10n.thinking)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel(L10n.aiGenerating)
    }
}

private struct FailureCard: View {
    let failure: ChatFailure
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: iconName)
                    .font(.title3)
                    .foregroundStyle(iconColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text(failure.title)
                        .font(.headline)
                    Text(failure.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Button(action: onRetry) {
                Label(L10n.retry, systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
        }
        .padding(16)
        .softCard()
        .frame(maxWidth: 430)
    }

    private var iconName: String {
        switch failure.kind {
        case .offline: "wifi.slash"
        case .rateLimit: "clock.badge.exclamationmark"
        case .quota: "exclamationmark.circle.fill"
        case .contextLimit: "text.badge.exclamationmark"
        case .access: "lock.fill"
        case .service: "exclamationmark.triangle.fill"
        }
    }

    private var iconColor: Color {
        switch failure.kind {
        case .offline: .secondary
        case .rateLimit, .contextLimit: .orange
        case .quota, .access, .service: .red
        }
    }
}
