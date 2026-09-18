import Foundation

/// Interface languages supported by the visitor page; the raw value goes into the `lang` query parameter.
public enum VisitorLanguage: String, CaseIterable, Sendable {
    case en
    case zhCn = "zh-cn"
    case zhTw = "zh-tw"
    case ja
    case ko
    case de
    case fr
    case pt
    case ru
    case es
    case vi
    case th
    case id
    case ms
    case tl
}

/// Theme preference for the visitor page; the raw value goes into the `theme` query parameter.
public enum VisitorTheme: String, CaseIterable, Sendable {
    case light
    case dark
    case system
}

public enum VisitorMessageSoundMode: String, CaseIterable, Sendable { case native, web }

/// SDK errors observable while clearing site data or building the visitor URL.
public enum VisitorSDKError: Error, Equatable, Sendable {
    case invalidURL
    case invalidQueryKey
    case invalidDirectChatID
    case siteInUse
    case websiteDataVerificationFailed
}

/// Typed configuration for the visitor web container.
public struct VisitorConfiguration: Sendable {
    /// The host must pass its own HTTPS visitor URL; the SDK bundles no test URL.
    public static let defaultVisitorURL = URL(string: "")!

    public var url: URL
    public var query: [String: String]
    /// Whether the page is opened from an app; when enabled the URL carries `is_app=1` for the visitor page to detect.
    public var isApp: Bool
    public var title: String?
    public var language: VisitorLanguage
    public var theme: VisitorTheme
    public var directChatId: String?
    public var newMessageSoundMode: VisitorMessageSoundMode

    public init(
        url: URL = Self.defaultVisitorURL,
        query: [String: String] = [:],
        title: String? = nil,
        language: VisitorLanguage = .zhCn,
        theme: VisitorTheme = .system,
        directChatId: String? = nil,
        newMessageSoundMode: VisitorMessageSoundMode = .web,
        isApp: Bool = false
    ) {
        self.url = url
        self.query = query
        self.isApp = isApp
        self.title = title
        self.language = language
        self.theme = theme
        self.directChatId = directChatId
        self.newMessageSoundMode = newMessageSoundMode
    }
}
