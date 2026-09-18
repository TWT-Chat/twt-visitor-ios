import Foundation

struct VisitorWebsiteDataRecord: Equatable, Sendable {
    let displayName: String
    let dataTypes: Set<String>

    init(displayName: String, dataTypes: Set<String> = ["websiteData"]) {
        self.displayName = displayName
        self.dataTypes = dataTypes
    }
}

@MainActor
protocol VisitorWebsiteDataStorePort: AnyObject {
    var verificationDataTypes: Set<String> { get }
    func fetchRecords() async -> [VisitorWebsiteDataRecord]
    func remove(records: [VisitorWebsiteDataRecord]) async
}

@MainActor
enum VisitorSiteDataCleaner {
    static func clear(targetHost: String, store: VisitorWebsiteDataStorePort, registry: VisitorActivityRegistry) async throws {
        let host = VisitorSiteDataPolicy.normalized(targetHost)
        guard !host.isEmpty else { throw VisitorSDKError.invalidURL }
        guard !registry.isActive(host: host) else { throw VisitorSDKError.siteInUse }
        let records = await store.fetchRecords()
        // A new container may start while records are being fetched; the target host must be blocked
        // again regardless of whether a WebKit record already existed.
        guard !registry.isActive(host: host) else { throw VisitorSDKError.siteInUse }
        let names = VisitorSiteDataPolicy.matchingDisplayNames(targetHost: host, displayNames: records.map(\.displayName))
        guard !names.isEmpty else { return }
        guard !VisitorSiteDataPolicy.anyActiveHost(registry.activeHosts(), belongsToAny: names) else { throw VisitorSDKError.siteInUse }
        let selected = records.filter { names.contains($0.displayName) }
        await store.remove(records: selected)
        let remaining = await store.fetchRecords()
        let selectedNames = Set(selected.map { VisitorSiteDataPolicy.normalized($0.displayName) })
        let verificationFailed = remaining.contains {
            selectedNames.contains(VisitorSiteDataPolicy.normalized($0.displayName)) && !$0.dataTypes.isDisjoint(with: store.verificationDataTypes)
        }
        guard !verificationFailed else { throw VisitorSDKError.websiteDataVerificationFailed }
    }
}
