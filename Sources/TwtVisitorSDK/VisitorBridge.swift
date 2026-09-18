import Foundation

public protocol VisitorBridgeDelegate: AnyObject {
    func visitorDownloadRequested(requestId: String, url: URL, type: String, fileName: String?, mimeType: String?, callback: String?)
    func visitorNewMessage()
    func visitorBack() -> Bool
    func visitorPermissionResult(requestId: String, granted: Bool, canAskAgain: Bool, resources: [String])
}

public extension VisitorBridgeDelegate {
    func visitorPermissionResult(requestId: String, granted: Bool, canAskAgain: Bool, resources: [String]) {}
}

public struct VisitorDownloadStatus: Sendable {
    public init(requestId: String, status: String, path: String? = nil, errorCode: String? = nil, message: String? = nil) { self.requestId = requestId; self.status = status; self.path = path; self.errorCode = errorCode; self.message = message }
    public let requestId: String; public let status: String; public let path: String?; public let errorCode: String?; public let message: String?
}
