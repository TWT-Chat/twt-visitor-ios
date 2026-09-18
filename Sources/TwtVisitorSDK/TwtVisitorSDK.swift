import Foundation

#if canImport(UIKit)
import UIKit
#endif
#if canImport(WebKit)
import WebKit
#endif

/// Presentation and site data cleanup entry point of the Twt visitor SDK.
@MainActor
public enum TwtVisitorSDK {
    @MainActor public final class VisitorHandle {
        public let sessionId: String
#if canImport(UIKit) && canImport(WebKit)
        private weak var controller: VisitorViewController?
        fileprivate init(sessionId: String, controller: VisitorViewController) { self.sessionId = sessionId; self.controller = controller }
        public func setTheme(_ theme: VisitorTheme) { controller?.setTheme(theme) }
        public func reportDownloadStatus(_ status: VisitorDownloadStatus) { controller?.reportDownloadStatus(status) }
        public func close() { controller?.dismiss(animated: true) }
#else
        fileprivate init(sessionId: String) { self.sessionId = sessionId }
        public func setTheme(_ theme: VisitorTheme) {}
        public func reportDownloadStatus(_ status: VisitorDownloadStatus) {}
        public func close() {}
#endif
    }
    public static weak var bridgeDelegate: VisitorBridgeDelegate?
#if canImport(UIKit) && canImport(WebKit)
    private static weak var activeController: VisitorViewController?
    /// Registers the embedded controller so the host can drive theme and download status through the SDK.
    public static func register(controller: VisitorViewController) { activeController = controller }
    /// Creates a visitor controller that does not present itself, for host containers such as a Flutter PlatformView.
    public static func makeEmbeddedController(configuration: VisitorConfiguration, delegate: VisitorBridgeDelegate? = nil) throws -> VisitorViewController {
        let controller = try VisitorViewController(configuration: configuration, showsChrome: false)
        controller.bridgeDelegate = delegate ?? bridgeDelegate
        register(controller: controller)
        return controller
    }
    @discardableResult public static func present(from presenter: UIViewController, configuration: VisitorConfiguration = .init(), animated: Bool = true, delegate: VisitorBridgeDelegate? = nil) throws -> VisitorHandle {
        _ = try VisitorURLPolicy.makeURL(from: configuration)
        let controller = try VisitorViewController(configuration: configuration)
        controller.bridgeDelegate = delegate ?? bridgeDelegate
        presenter.present(controller, animated: animated)
        return VisitorHandle(sessionId: controller.sessionId, controller: controller)
    }

#endif

#if canImport(WebKit)
    public static func clearSiteData(for configuration: VisitorConfiguration = .init()) async throws {
        let targetURL = try VisitorURLPolicy.makeURL(from: configuration)
        guard let targetHost = targetURL.host else { throw VisitorSDKError.invalidURL }
        try await VisitorSiteDataCleaner.clear(targetHost: targetHost, store: WebKitWebsiteDataStorePort(), registry: .shared)
    }

    private final class WebKitWebsiteDataStorePort: VisitorWebsiteDataStorePort {
        private let store = WKWebsiteDataStore.default()
        let verificationDataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        private var nativeRecords: [String: [WKWebsiteDataRecord]] = [:]
        func fetchRecords() async -> [VisitorWebsiteDataRecord] {
            let records = await withCheckedContinuation { continuation in store.fetchDataRecords(ofTypes: verificationDataTypes) { continuation.resume(returning: $0) } }
            nativeRecords = Dictionary(grouping: records, by: \.displayName)
            return records.map { VisitorWebsiteDataRecord(displayName: $0.displayName, dataTypes: $0.dataTypes) }
        }
        func remove(records: [VisitorWebsiteDataRecord]) async {
            let selected = records.flatMap { nativeRecords[$0.displayName] ?? [] }
            await withCheckedContinuation { continuation in store.removeData(ofTypes: verificationDataTypes, for: selected) { continuation.resume() } }
        }
    }
#endif
}
