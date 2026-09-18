import Foundation

/// Tracks live containers created by the SDK; releasing a token is idempotent.
@MainActor
final class VisitorActivityRegistry {
    static let shared = VisitorActivityRegistry()
    private let state = State()
    init() {}

    func acquire(host: String) -> Token {
        let key = VisitorSiteDataPolicy.normalized(host)
        state.acquire(host: key)
        return Token { [state] in state.release(host: key) }
    }

    func isActive(host: String) -> Bool { state.isActive(host: VisitorSiteDataPolicy.normalized(host)) }
    func activeHosts() -> [String] { state.activeHosts() }

    /// All mutable state is guarded by `lock`; the release closure only touches the equally guarded `State`.
    final class Token: @unchecked Sendable {
        private let lock = NSLock()
        private var releaseBody: (@Sendable () -> Void)?
        fileprivate init(_ releaseBody: @escaping @Sendable () -> Void) { self.releaseBody = releaseBody }
        func release() {
            lock.lock(); let body = releaseBody; releaseBody = nil; lock.unlock()
            body?()
        }
        deinit { release() }
    }

    /// Every read and write of `hosts` happens under the same mutex, so it is safe to hold across isolation domains.
    private final class State: @unchecked Sendable {
        private let lock = NSLock()
        private var hosts: [String: Int] = [:]
        func acquire(host: String) { lock.withLock { hosts[host, default: 0] += 1 } }
        func release(host: String) { lock.withLock { guard let count = hosts[host], count > 0 else { return }; if count == 1 { hosts.removeValue(forKey: host) } else { hosts[host] = count - 1 } } }
        func isActive(host: String) -> Bool { lock.withLock { (hosts[host] ?? 0) > 0 } }
        func activeHosts() -> [String] { lock.withLock { hosts.filter { $0.value > 0 }.map(\.key) } }
    }
}
