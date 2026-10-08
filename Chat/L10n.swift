import Foundation

enum L10n {
    private static func localized(_ key: String) -> String {
        let rawValue = UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.system.rawValue
        let language = AppLanguage(rawValue: rawValue) ?? .system

        if language != .system,
           let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: key, value: key, table: "Localizable")
        }

        return Bundle.main.localizedString(forKey: key, value: key, table: "Localizable")
    }

    static var newChat: String { localized("new_chat") }
    static var appearanceSystem: String { localized("appearance_system") }
    static var appearanceLight: String { localized("appearance_light") }
    static var appearanceDark: String { localized("appearance_dark") }

    static var messagePlaceholder: String { localized("message_placeholder") }
    static var stopGeneration: String { localized("stop_generation") }
    static var send: String { localized("send") }
    static var disclaimer: String { localized("ai_disclaimer") }

    static var openChats: String { localized("open_chats") }
    static var welcomeTitle: String { localized("welcome_title") }
    static var welcomeSubtitle: String { localized("welcome_subtitle") }
    static var suggestionIdeas: String { localized("suggestion_ideas") }
    static var suggestionExplain: String { localized("suggestion_explain") }
    static var suggestionPlan: String { localized("suggestion_plan") }
    static var you: String { localized("you") }
    static var thinking: String { localized("thinking") }
    static var aiGenerating: String { localized("ai_generating") }
    static var retry: String { localized("retry") }

    static var chats: String { localized("chats") }
    static var conversations: String { localized("conversations") }
    static var history: String { localized("history") }
    static var searchChats: String { localized("search_chats") }
    static var noChats: String { localized("no_chats") }
    static var noChatsDescription: String { localized("no_chats_description") }
    static var noResults: String { localized("no_results") }
    static var noResultsDescription: String { localized("no_results_description") }
    static var rename: String { localized("rename") }
    static var delete: String { localized("delete") }
    static var appearance: String { localized("appearance") }
    static var theme: String { localized("theme") }
    static var renameChat: String { localized("rename_chat") }
    static var name: String { localized("name") }
    static var cancel: String { localized("cancel") }
    static var save: String { localized("save") }
    static var emptyChat: String { localized("empty_chat") }
    static var close: String { localized("close") }
    static var settings: String { localized("settings") }
    static var settingsDescription: String { localized("settings_description") }
    static var general: String { localized("general") }
    static var haptics: String { localized("haptics") }
    static var hapticsDescription: String { localized("haptics_description") }
    static var buttonSounds: String { localized("button_sounds") }
    static var buttonSoundsDescription: String { localized("button_sounds_description") }
    static var notifications: String { localized("notifications") }
    static var notificationsDescription: String { localized("notifications_description") }
    static var notificationsDeniedTitle: String { localized("notifications_denied_title") }
    static var notificationsDeniedMessage: String { localized("notifications_denied_message") }
    static var openSystemSettings: String { localized("open_system_settings") }
    static var language: String { localized("language") }
    static var followsSystem: String { localized("follows_system") }
    static var aiService: String { localized("ai_service") }
    static var provider: String { localized("provider") }
    static var about: String { localized("about") }
    static var version: String { localized("version") }
    static var rateUs: String { localized("rate_us") }
    static var done: String { localized("done") }

    static var loading: String { localized("loading") }
    static var next: String { localized("next") }
    static var getStarted: String { localized("get_started") }
    static var onboardingWelcomeTitle: String { localized("onboarding_welcome_title") }
    static var onboardingWelcomeSubtitle: String { localized("onboarding_welcome_subtitle") }
    static var onboardingChatsTitle: String { localized("onboarding_chats_title") }
    static var onboardingChatsSubtitle: String { localized("onboarding_chats_subtitle") }
    static var onboardingImagesTitle: String { localized("onboarding_images_title") }
    static var onboardingImagesSubtitle: String { localized("onboarding_images_subtitle") }
    static var responseReady: String { localized("response_ready") }
    static var responseReadyBody: String { localized("response_ready_body") }

    static var createChat: String { localized("create_chat") }
    static var chatTitleOptional: String { localized("chat_title_optional") }
    static var chatTitleHint: String { localized("chat_title_hint") }
    static var create: String { localized("create") }
    static var chatActions: String { localized("chat_actions") }
    static var pin: String { localized("pin") }
    static var unpin: String { localized("unpin") }
    static var pinned: String { localized("pinned") }
    static var recent: String { localized("recent") }
    static var deleteChat: String { localized("delete_chat") }
    static var deleteChatMessage: String { localized("delete_chat_message") }
    static var copy: String { localized("copy") }
    static var copied: String { localized("copied") }
    static var addImage: String { localized("add_image") }
    static var addPhoto: String { localized("add_photo") }
    static var addFile: String { localized("add_file") }
    static var addAttachment: String { localized("add_attachment") }
    static var removeImage: String { localized("remove_image") }
    static var removeAttachment: String { localized("remove_attachment") }
    static var photo: String { localized("photo") }
    static var photoChat: String { localized("photo_chat") }
    static var file: String { localized("file") }
    static var fileChat: String { localized("file_chat") }
    static var textDocument: String { localized("text_document") }
    static var attachmentErrorTitle: String { localized("attachment_error_title") }
    static var imageReadErrorMessage: String { localized("image_read_error_message") }
    static var fileReadErrorMessage: String { localized("file_read_error_message") }
    static var attachmentLimitMessage: String { localized("attachment_limit_message") }

    static var offlineTitle: String { localized("offline_title") }
    static var offlineMessage: String { localized("offline_message") }
    static var timeoutTitle: String { localized("timeout_title") }
    static var timeoutMessage: String { localized("timeout_message") }
    static var rateLimitTitle: String { localized("rate_limit_title") }
    static var rateLimitMessage: String { localized("rate_limit_message") }
    static var quotaLimitTitle: String { localized("quota_limit_title") }
    static var quotaLimitMessage: String { localized("quota_limit_message") }
    static var contextLimitTitle: String { localized("context_limit_title") }
    static var contextLimitMessage: String { localized("context_limit_message") }
    static var accessErrorTitle: String { localized("access_error_title") }
    static var accessErrorMessage: String { localized("access_error_message") }
    static var serviceErrorTitle: String { localized("service_error_title") }
    static var serviceErrorMessage: String { localized("service_error_message") }
}
