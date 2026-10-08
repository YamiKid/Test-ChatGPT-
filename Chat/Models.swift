import Foundation
import SwiftUI

enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
}

struct ChatMessage: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let role: MessageRole
    var text: String
    let attachments: [ChatAttachment]
    let createdAt: Date

    private enum CodingKeys: String, CodingKey {
        case id, role, text, attachments, createdAt
    }

    nonisolated init(
        id: UUID = UUID(),
        role: MessageRole,
        text: String,
        attachments: [ChatAttachment] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.attachments = attachments
        self.createdAt = createdAt
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        role = try container.decode(MessageRole.self, forKey: .role)
        text = try container.decode(String.self, forKey: .text)
        attachments = try container.decodeIfPresent([ChatAttachment].self, forKey: .attachments) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}

struct ChatAttachment: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let data: Data
    let mimeType: String
    let fileName: String?
    let extractedText: String?
    let thumbnailData: Data?

    private enum CodingKeys: String, CodingKey {
        case id, data, mimeType, fileName, extractedText, thumbnailData
    }

    nonisolated init(
        id: UUID = UUID(),
        data: Data,
        mimeType: String = "image/jpeg",
        fileName: String? = nil,
        extractedText: String? = nil,
        thumbnailData: Data? = nil
    ) {
        self.id = id
        self.data = data
        self.mimeType = mimeType
        self.fileName = fileName
        self.extractedText = extractedText
        self.thumbnailData = thumbnailData
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        data = try container.decodeIfPresent(Data.self, forKey: .data) ?? Data()
        mimeType = try container.decodeIfPresent(String.self, forKey: .mimeType) ?? "image/jpeg"
        fileName = try container.decodeIfPresent(String.self, forKey: .fileName)
        extractedText = try container.decodeIfPresent(String.self, forKey: .extractedText)
        thumbnailData = try container.decodeIfPresent(Data.self, forKey: .thumbnailData)
    }

    nonisolated var isImage: Bool { mimeType.hasPrefix("image/") }
    var displayName: String { fileName ?? (isImage ? L10n.photo : L10n.file) }
    nonisolated var previewData: Data { thumbnailData ?? data }
}

struct ChatThread: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var title: String
    var isPinned: Bool
    var isTitleAutomatic: Bool
    var isResponsePending: Bool
    let createdAt: Date
    var updatedAt: Date
    var messages: [ChatMessage]

    private enum CodingKeys: String, CodingKey {
        case id, title, isPinned, isTitleAutomatic, isResponsePending, createdAt, updatedAt, messages
    }

    init(
        id: UUID = UUID(),
        title: String = L10n.newChat,
        isPinned: Bool = false,
        isTitleAutomatic: Bool = true,
        isResponsePending: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        messages: [ChatMessage] = []
    ) {
        self.id = id
        self.title = title
        self.isPinned = isPinned
        self.isTitleAutomatic = isTitleAutomatic
        self.isResponsePending = isResponsePending
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        isTitleAutomatic = try container.decodeIfPresent(Bool.self, forKey: .isTitleAutomatic) ?? false
        isResponsePending = try container.decodeIfPresent(Bool.self, forKey: .isResponsePending) ?? false
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        messages = try container.decode([ChatMessage].self, forKey: .messages)
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: L10n.appearanceSystem
        case .light: L10n.appearanceLight
        case .dark: L10n.appearanceDark
        }
    }

    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.stars.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case ru
    case en

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: L10n.followsSystem
        case .ru: "Русский"
        case .en: "English"
        }
    }

    var locale: Locale? {
        switch self {
        case .system: nil
        case .ru: Locale(identifier: "ru")
        case .en: Locale(identifier: "en")
        }
    }

    var responseLanguageName: String {
        switch self {
        case .ru: "Russian"
        case .en: "English"
        case .system:
            Locale.current.language.languageCode?.identifier == "ru" ? "Russian" : "English"
        }
    }
}

enum GenerationState: Equatable {
    case idle
    case generating
    case failed(ChatFailure)
}

struct ChatFailure: Equatable {
    enum Kind: Equatable {
        case offline
        case rateLimit
        case quota
        case contextLimit
        case access
        case service
    }

    let kind: Kind
    let title: String
    let message: String
}
