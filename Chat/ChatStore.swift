import Combine
import Foundation
import UIKit

@MainActor
final class ChatStore: ObservableObject {
    @Published private(set) var chats: [ChatThread] = []
    @Published var selectedChatID: UUID?
    @Published private(set) var generationStates: [UUID: GenerationState] = [:]

    private let aiClient: AIClient
    private let persistenceURL: URL
    private let maxConcurrentGenerations = 1
    private var generationTasks: [UUID: Task<Void, Never>] = [:]
    private var generationQueue: [ScheduledGeneration] = []
    private var streamingMessageIDs: [UUID: UUID] = [:]
    private var failedMessageIDs: [UUID: UUID] = [:]
    private var backgroundTaskIDs: [UUID: UIBackgroundTaskIdentifier] = [:]
    private var userScrollingChatIDs: Set<UUID> = []

    init(aiClient: AIClient = AIClient(), fileManager: FileManager = .default) {
        self.aiClient = aiClient
        let baseURL = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fileManager.temporaryDirectory
        let directory = baseURL.appendingPathComponent("GarnetChat", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        persistenceURL = directory.appendingPathComponent("chats.json")
        load()
        AppLogger.record(
            "store",
            "loaded",
            metadata: [
                "chats": String(chats.count),
                "pending": String(chats.filter(\.isResponsePending).count)
            ]
        )
        resumePendingGenerations()
    }

    var sortedChats: [ChatThread] {
        chats.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
            return $0.updatedAt > $1.updatedAt
        }
    }

    var pinnedChats: [ChatThread] { sortedChats.filter(\.isPinned) }
    var recentChats: [ChatThread] { sortedChats.filter { !$0.isPinned } }

    var selectedChat: ChatThread? {
        guard let selectedChatID else { return nil }
        return chats.first { $0.id == selectedChatID }
    }

    var generationState: GenerationState {
        state(for: selectedChatID)
    }

    var hasActiveGeneration: Bool {
        generationStates.values.contains(.generating)
    }

    var isSelectedChatBlockedByAnotherChat: Bool {
        generationState != .generating && hasActiveGeneration
    }

    func state(for chatID: UUID?) -> GenerationState {
        guard let chatID else { return .idle }
        return generationStates[chatID] ?? .idle
    }

    func isGenerating(_ chatID: UUID) -> Bool {
        state(for: chatID) == .generating
    }

    @discardableResult
    func createChat(title: String? = nil) -> UUID {
        let cleanTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let chat = ChatThread(
            title: cleanTitle.isEmpty ? L10n.newChat : Self.shortened(cleanTitle, limit: 48),
            isTitleAutomatic: cleanTitle.isEmpty
        )
        chats = chats + [chat]
        selectedChatID = chat.id
        persist()
        HapticFeedback.light()
        return chat.id
    }

    func selectChat(_ id: UUID?) {
        selectedChatID = id
        AppLogger.record("chat", "selected", metadata: ["chat": id.map(AppLogger.shortID) ?? "none"])
    }

    func deleteChat(_ id: UUID) {
        stopGeneration(in: id)
        userScrollingChatIDs.remove(id)
        if selectedChatID == id { selectedChatID = nil }
        chats = chats.filter { $0.id != id }
        generationStates[id] = nil
        failedMessageIDs[id] = nil
        persist()
    }

    func renameChat(_ id: UUID, to title: String) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, let index = chatIndex(for: id) else { return }
        var updatedChats = chats
        updatedChats[index].title = Self.shortened(clean, limit: 48)
        updatedChats[index].isTitleAutomatic = false
        updatedChats[index].updatedAt = .now
        chats = updatedChats
        persist()
    }

    func togglePin(_ id: UUID) {
        guard let index = chatIndex(for: id) else { return }
        var updatedChats = chats
        updatedChats[index].isPinned.toggle()
        updatedChats[index].updatedAt = .now
        chats = updatedChats
        persist()
        HapticFeedback.selection()
    }

    func send(_ text: String, attachments: [ChatAttachment] = []) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (!clean.isEmpty || !attachments.isEmpty), !hasActiveGeneration else { return }

        let chatID = selectedChatID ?? createChat()
        guard !isGenerating(chatID), let index = chatIndex(for: chatID) else { return }

        var updatedChats = chats
        updatedChats[index].messages.append(ChatMessage(role: .user, text: clean, attachments: attachments))
        if
            updatedChats[index].isTitleAutomatic,
            updatedChats[index].messages.filter({ $0.role == .user }).count == 1
        {
            updatedChats[index].title = clean.isEmpty
                ? (attachments.allSatisfy(\.isImage) ? L10n.photoChat : L10n.fileChat)
                : Self.title(from: clean)
            updatedChats[index].isTitleAutomatic = false
        }
        updatedChats[index].updatedAt = .now
        chats = updatedChats
        persist()
        HapticFeedback.light()
        AppLogger.record(
            "ai",
            "message_submitted",
            metadata: [
                "attachments": String(attachments.count),
                "chat": AppLogger.shortID(chatID),
                "textCharacters": String(clean.count)
            ]
        )
        startGeneration(in: chatID)
    }

    func retry() {
        guard let chatID = selectedChatID else { return }
        retry(in: chatID)
    }

    func retry(in chatID: UUID) {
        guard !hasActiveGeneration, !isGenerating(chatID), let index = chatIndex(for: chatID) else { return }
        if let failedMessageID = failedMessageIDs[chatID] {
            var updatedChats = chats
            updatedChats[index].messages.removeAll { $0.id == failedMessageID }
            chats = updatedChats
        }
        failedMessageIDs[chatID] = nil
        guard chats[index].messages.last?.role == .user else { return }
        persist()
        startGeneration(in: chatID)
    }

    func stopGeneration() {
        guard let selectedChatID else { return }
        stopGeneration(in: selectedChatID)
    }

    func stopGeneration(in chatID: UUID) {
        guard isGenerating(chatID) else { return }
        AppLogger.record(
            "ai",
            "generation_stopped",
            metadata: [
                "active": String(generationTasks.count),
                "chat": AppLogger.shortID(chatID),
                "queued": String(generationQueue.count)
            ]
        )
        generationTasks[chatID]?.cancel()
        generationTasks[chatID] = nil
        generationQueue.removeAll { $0.chatID == chatID }
        if let messageID = streamingMessageIDs[chatID] {
            finishStreamingMessage(in: chatID, messageID: messageID, removeIfEmpty: true)
        }
        streamingMessageIDs[chatID] = nil
        generationStates[chatID] = .idle
        setResponsePending(false, in: chatID)
        endBackgroundTime(for: chatID)
        persist()
        drainGenerationQueue()
    }

    /// Streaming may deliver many small fragments. Publishing them while the
    /// scroll view is tracking a finger forces SwiftUI to recalculate layout
    /// and the scroll position at the same time. Keep receiving the response,
    /// but defer visual updates until the gesture has completely stopped.
    func setUserScrolling(_ isScrolling: Bool, in chatID: UUID) {
        if isScrolling {
            guard userScrollingChatIDs.insert(chatID).inserted else { return }
            AppLogger.record("scroll", "stream_updates_paused", metadata: ["chat": AppLogger.shortID(chatID)])
        } else {
            guard userScrollingChatIDs.remove(chatID) != nil else { return }
            AppLogger.record("scroll", "stream_updates_resumed", metadata: ["chat": AppLogger.shortID(chatID)])
        }
    }

    private func startGeneration(in chatID: UUID, resumingMessageID: UUID? = nil) {
        guard
            generationTasks[chatID] == nil,
            !generationQueue.contains(where: { $0.chatID == chatID }),
            let index = chatIndex(for: chatID)
        else { return }
        failedMessageIDs[chatID] = nil

        let message: ChatMessage
        if let resumingMessageID,
           let messageIndex = chats[index].messages.firstIndex(where: { $0.id == resumingMessageID }) {
            message = chats[index].messages[messageIndex]
        } else {
            message = ChatMessage(role: .assistant, text: "")
            var updatedChats = chats
            updatedChats[index].messages.append(message)
            chats = updatedChats
        }

        streamingMessageIDs[chatID] = message.id
        generationStates[chatID] = .generating
        setResponsePending(true, in: chatID)
        persist()
        generationQueue.append(ScheduledGeneration(chatID: chatID, messageID: message.id))
        AppLogger.record(
            "ai",
            "generation_enqueued",
            metadata: [
                "active": String(generationTasks.count),
                "chat": AppLogger.shortID(chatID),
                "queued": String(generationQueue.count),
                "resumed": String(resumingMessageID != nil)
            ]
        )
        drainGenerationQueue()
    }

    private func drainGenerationQueue() {
        while generationTasks.count < maxConcurrentGenerations, !generationQueue.isEmpty {
            let scheduled = generationQueue.removeFirst()
            guard
                generationTasks[scheduled.chatID] == nil,
                isGenerating(scheduled.chatID),
                let chatIndex = chatIndex(for: scheduled.chatID),
                let messageIndex = chats[chatIndex].messages.firstIndex(where: { $0.id == scheduled.messageID })
            else { continue }

            let context = Array(chats[chatIndex].messages[..<messageIndex])
            launchGeneration(scheduled, context: context)
        }
    }

    private func launchGeneration(_ scheduled: ScheduledGeneration, context: [ChatMessage]) {
        let chatID = scheduled.chatID
        let messageID = scheduled.messageID
        beginBackgroundTime(for: chatID)
        AppLogger.record(
            "ai",
            "generation_started",
            metadata: [
                "active": String(generationTasks.count + 1),
                "chat": AppLogger.shortID(chatID),
                "contextMessages": String(context.count),
                "queued": String(generationQueue.count)
            ]
        )

        generationTasks[chatID] = Task { [weak self] in
            guard let self else { return }
            var bufferedText = ""
            let startedAt = Date()
            var receivedCharacters = 0
            var interfaceUpdates = 0
            do {
                for try await token in aiClient.streamReply(for: context) {
                    guard !Task.isCancelled else { return }
                    bufferedText += token
                    receivedCharacters += token.count
                }
                guard !Task.isCancelled else { return }
                try await waitForScrollingToEnd(in: chatID)
                guard !Task.isCancelled else { return }
                if !bufferedText.isEmpty {
                    append(bufferedText, to: messageID, in: chatID)
                    interfaceUpdates += 1
                }
                finishStreamingMessage(in: chatID, messageID: messageID, removeIfEmpty: true)
                generationStates[chatID] = .idle
                generationTasks[chatID] = nil
                streamingMessageIDs[chatID] = nil
                setResponsePending(false, in: chatID)
                endBackgroundTime(for: chatID)
                persist()
                let chatTitle = chats.first(where: { $0.id == chatID })?.title ?? "Garnet"
                NotificationManager.notifyResponseReady(chatTitle: chatTitle)
                AppLogger.record(
                    "ai",
                    "generation_completed",
                    metadata: [
                        "chat": AppLogger.shortID(chatID),
                        "characters": String(receivedCharacters),
                        "durationMs": String(Int(Date().timeIntervalSince(startedAt) * 1_000)),
                        "interfaceUpdates": String(interfaceUpdates)
                    ]
                )
                drainGenerationQueue()
            } catch {
                guard !Task.isCancelled else { return }
                await waitForScrollingToEndIgnoringCancellation(in: chatID)
                guard !Task.isCancelled else { return }
                let failure = Self.failure(from: error)
                failedMessageIDs[chatID] = messageID
                streamingMessageIDs[chatID] = nil
                generationStates[chatID] = .failed(failure)
                generationTasks[chatID] = nil
                setResponsePending(false, in: chatID)
                endBackgroundTime(for: chatID)
                persist()
                AppLogger.record(
                    "ai",
                    "generation_failed",
                    metadata: [
                        "chat": AppLogger.shortID(chatID),
                        "characters": String(receivedCharacters),
                        "durationMs": String(Int(Date().timeIntervalSince(startedAt) * 1_000)),
                        "error": String(reflecting: error),
                        "interfaceUpdates": String(interfaceUpdates)
                    ]
                )
                if Self.shouldHaltQueue(after: error) {
                    failScheduledGenerations(with: failure, excluding: chatID)
                } else {
                    drainGenerationQueue()
                }
            }
        }
    }

    private func waitForScrollingToEnd(in chatID: UUID) async throws {
        while userScrollingChatIDs.contains(chatID) {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: 80_000_000)
        }
    }

    private func waitForScrollingToEndIgnoringCancellation(in chatID: UUID) async {
        while userScrollingChatIDs.contains(chatID), !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 80_000_000)
        }
    }

    private func failScheduledGenerations(with failure: ChatFailure, excluding excludedChatID: UUID) {
        var affectedMessages: [UUID: UUID] = [:]

        let queuedCount = generationQueue.count
        for scheduled in generationQueue where scheduled.chatID != excludedChatID {
            affectedMessages[scheduled.chatID] = scheduled.messageID
        }
        generationQueue.removeAll()

        let activeChatIDs = generationTasks.keys.filter { $0 != excludedChatID }
        AppLogger.record(
            "ai",
            "queue_halted",
            metadata: [
                "activeCancelled": String(activeChatIDs.count),
                "excludedChat": AppLogger.shortID(excludedChatID),
                "queuedCancelled": String(queuedCount)
            ]
        )
        for chatID in activeChatIDs {
            if let messageID = streamingMessageIDs[chatID] {
                affectedMessages[chatID] = messageID
            }
            generationTasks[chatID]?.cancel()
            generationTasks[chatID] = nil
            endBackgroundTime(for: chatID)
        }

        for (chatID, messageID) in affectedMessages {
            guard chatIndex(for: chatID) != nil else { continue }
            failedMessageIDs[chatID] = messageID
            streamingMessageIDs[chatID] = nil
            generationStates[chatID] = .failed(failure)
            setResponsePending(false, in: chatID)
        }
        persist()
    }

    private func resumePendingGenerations() {
        var invalidPendingChatIDs: [UUID] = []
        let pending = chats.compactMap { chat -> (UUID, UUID?)? in
            guard chat.isResponsePending else { return nil }
            guard let last = chat.messages.last else {
                invalidPendingChatIDs.append(chat.id)
                return nil
            }
            if last.role == .user {
                return (chat.id, nil)
            }
            if last.role == .assistant,
               last.text.isEmpty,
               chat.messages.dropLast().last?.role == .user {
                return (chat.id, last.id)
            }
            invalidPendingChatIDs.append(chat.id)
            return nil
        }

        for chatID in invalidPendingChatIDs {
            setResponsePending(false, in: chatID)
        }
        if !invalidPendingChatIDs.isEmpty {
            persist()
        }

        AppLogger.record(
            "ai",
            "pending_recovery",
            metadata: [
                "invalid": String(invalidPendingChatIDs.count),
                "resuming": String(pending.count)
            ]
        )

        for (chatID, messageID) in pending {
            startGeneration(in: chatID, resumingMessageID: messageID)
        }
    }

    private func append(_ token: String, to messageID: UUID, in chatID: UUID) {
        guard
            let chatIndex = chatIndex(for: chatID),
            let messageIndex = chats[chatIndex].messages.firstIndex(where: { $0.id == messageID })
        else { return }
        var updatedChats = chats
        updatedChats[chatIndex].messages[messageIndex].text += token
        updatedChats[chatIndex].updatedAt = .now
        chats = updatedChats
    }

    private func finishStreamingMessage(in chatID: UUID, messageID: UUID, removeIfEmpty: Bool) {
        guard
            let chatIndex = chatIndex(for: chatID),
            let messageIndex = chats[chatIndex].messages.firstIndex(where: { $0.id == messageID })
        else { return }
        if removeIfEmpty && chats[chatIndex].messages[messageIndex].text.isEmpty {
            var updatedChats = chats
            updatedChats[chatIndex].messages.remove(at: messageIndex)
            chats = updatedChats
        }
    }

    private func setResponsePending(_ isPending: Bool, in chatID: UUID) {
        guard let index = chatIndex(for: chatID) else { return }
        var updatedChats = chats
        updatedChats[index].isResponsePending = isPending
        chats = updatedChats
    }

    private func beginBackgroundTime(for chatID: UUID) {
        guard backgroundTaskIDs[chatID] == nil else { return }
        var identifier: UIBackgroundTaskIdentifier = .invalid
        identifier = UIApplication.shared.beginBackgroundTask(withName: "Garnet response") { [weak self] in
            Task { @MainActor [weak self] in
                AppLogger.record("lifecycle", "background_time_expired", metadata: ["chat": AppLogger.shortID(chatID)])
                self?.endBackgroundTime(for: chatID)
            }
        }
        if identifier != .invalid {
            backgroundTaskIDs[chatID] = identifier
        }
    }

    private func endBackgroundTime(for chatID: UUID) {
        guard let identifier = backgroundTaskIDs.removeValue(forKey: chatID), identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
    }

    private func chatIndex(for id: UUID) -> Int? {
        chats.firstIndex { $0.id == id }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: persistenceURL.path) else { return }
        do {
            let data = try Data(contentsOf: persistenceURL)
            chats = try JSONDecoder().decode([ChatThread].self, from: data)
        } catch {
            AppLogger.record("storage", "load_failed", metadata: ["error": String(reflecting: error)])
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(chats)
            try data.write(to: persistenceURL, options: .atomic)
        } catch {
            AppLogger.record("storage", "save_failed", metadata: ["error": String(reflecting: error)])
        }
    }

    private static func title(from text: String) -> String {
        let compact = text.split(whereSeparator: \Character.isWhitespace).joined(separator: " ")
        return shortened(compact, limit: 28)
    }

    private static func shortened(_ text: String, limit: Int) -> String {
        let compact = text.split(whereSeparator: \Character.isWhitespace).joined(separator: " ")
        guard compact.count > limit else { return compact }

        let prefix = String(compact.prefix(limit))
        let wordBoundary = prefix.lastIndex(of: " ")
        let candidate: String
        if let wordBoundary, prefix.distance(from: prefix.startIndex, to: wordBoundary) >= limit / 2 {
            candidate = String(prefix[..<wordBoundary])
        } else {
            candidate = prefix
        }
        return candidate.trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    private static func failure(from error: Error) -> ChatFailure {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost:
                return ChatFailure(kind: .offline, title: L10n.offlineTitle, message: L10n.offlineMessage)
            case .timedOut:
                return ChatFailure(kind: .service, title: L10n.timeoutTitle, message: L10n.timeoutMessage)
            default: break
            }
        }

        if let aiError = error as? AIClientError {
            switch aiError {
            case .missingAPIKey:
                return ChatFailure(kind: .access, title: L10n.accessErrorTitle, message: L10n.accessErrorMessage)
            case .rateLimited:
                return ChatFailure(kind: .rateLimit, title: L10n.rateLimitTitle, message: L10n.rateLimitMessage)
            case .quotaExceeded:
                return ChatFailure(kind: .quota, title: L10n.quotaLimitTitle, message: L10n.quotaLimitMessage)
            case .contextLimitExceeded:
                return ChatFailure(
                    kind: .contextLimit,
                    title: L10n.contextLimitTitle,
                    message: L10n.contextLimitMessage
                )
            case .unauthorized:
                return ChatFailure(kind: .access, title: L10n.accessErrorTitle, message: L10n.accessErrorMessage)
            case .invalidResponse, .emptyResponse, .server:
                break
            }
        }

        return ChatFailure(kind: .service, title: L10n.serviceErrorTitle, message: L10n.serviceErrorMessage)
    }

    private static func shouldHaltQueue(after error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost:
                return true
            default:
                break
            }
        }

        guard let aiError = error as? AIClientError else { return false }
        switch aiError {
        case .missingAPIKey, .rateLimited, .quotaExceeded, .unauthorized:
            return true
        case .invalidResponse, .emptyResponse, .contextLimitExceeded, .server:
            return false
        }
    }
}

private struct ScheduledGeneration {
    let chatID: UUID
    let messageID: UUID
}
