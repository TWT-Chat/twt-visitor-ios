import Foundation

/// Dot-boundary matching policy between a WKWebsiteDataRecord displayName and a host.
enum VisitorSiteDataPolicy {
    static func normalized(_ value: String) -> String { value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")) }

    static func host(_ host: String, belongsTo displayName: String) -> Bool {
        let h = normalized(host), d = normalized(displayName)
        return !h.isEmpty && !d.isEmpty && (h == d || h.hasSuffix("." + d))
    }

    static func matchingDisplayNames(targetHost: String, displayNames: [String]) -> [String] {
        let candidates = displayNames.filter { host(targetHost, belongsTo: $0) }
        guard let maxLength = candidates.map({ normalized($0).count }).max() else { return [] }
        return candidates.filter { normalized($0).count == maxLength }
    }

    static func anyActiveHost(_ activeHosts: [String], belongsToAny displayNames: [String]) -> Bool {
        activeHosts.contains { active in
            displayNames.contains { displayName in host(active, belongsTo: displayName) }
        }
    }
}
