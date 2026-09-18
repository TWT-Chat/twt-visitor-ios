import Foundation

/// Classification of top-level navigation: in-container, system browser, or blocked.
enum VisitorNavigationDecision: Equatable, Sendable { case internalWebView, externalBrowser, blocked }

enum VisitorNavigationPolicy {
    static func decide(base: URL, candidate: URL, isMainFrame: Bool, isNewWindow: Bool = false) -> VisitorNavigationDecision {
        guard isMainFrame || isNewWindow else { return .internalWebView }
        guard VisitorURLPolicy.isValidHTTPS(candidate), VisitorURLPolicy.isValidHTTPS(base) else { return .blocked }
        let bp = base.port ?? 443, cp = candidate.port ?? 443
        guard candidate.host?.caseInsensitiveCompare(base.host ?? "") == .orderedSame else { return .externalBrowser }
        return bp == cp ? .internalWebView : .externalBrowser
    }
}
