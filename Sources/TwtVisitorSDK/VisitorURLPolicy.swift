import Foundation

/// Validation, query parameter override, and RFC 3986 encode/decode policy for visitor URLs.
enum VisitorURLPolicy {
    static func makeURL(from configuration: VisitorConfiguration) throws -> URL {
        let input = configuration.url
        guard let scheme = input.scheme?.lowercased(), scheme == "https",
              validHost(input),
              input.user == nil, input.password == nil,
              validPort(input.port) else {
            throw VisitorSDKError.invalidURL
        }
        let pairs = try mergedPairs(configuration: configuration)
        guard var components = URLComponents(url: input, resolvingAgainstBaseURL: false) else {
            throw VisitorSDKError.invalidURL
        }
        components.scheme = "https"
        components.percentEncodedQuery = pairs.isEmpty ? nil : pairs.map { "\(encode($0.0))=\(encode($0.1))" }.joined(separator: "&")
        guard let result = components.url else { throw VisitorSDKError.invalidURL }
        return result
    }

    static func isValidHTTPS(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https", validHost(url),
              url.user == nil, url.password == nil, validPort(url.port) else { return false }
        return true
    }

    static func mergedPairs(configuration: VisitorConfiguration) throws -> [(String, String)] {
        var values: [(String, String)] = []
        let baseQuery = URLComponents(url: configuration.url, resolvingAgainstBaseURL: false)?.percentEncodedQuery
        for pair in try parseQuery(baseQuery) {
            upsert(pair, into: &values)
        }
        for (key, value) in configuration.query {
            guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw VisitorSDKError.invalidQueryKey }
            upsert((key, value), into: &values)
        }
        if configuration.isApp { upsert(("is_app", "1"), into: &values) }
        upsert(("lang", configuration.language.rawValue), into: &values)
        upsert(("theme", configuration.theme.rawValue), into: &values)
        if let id = configuration.directChatId {
            guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw VisitorSDKError.invalidDirectChatID }
            values.removeAll { $0.0 == "chat_id" }
            upsert(("direct", "1"), into: &values)
            upsert(("chatid", id), into: &values)
        }
        return values
    }

    private static func validPort(_ port: Int?) -> Bool { port == nil || (1...65535).contains(port!) }

    /// The URL `host` property may already have decoded percent escapes into control characters or
    /// path separators. Validate the decoded `percentEncodedHost` instead, so URL building and
    /// navigation decisions share the same security boundary.
    private static func validHost(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let encodedHost = components.percentEncodedHost,
              !encodedHost.isEmpty,
              let host = try? decode(encodedHost),
              !host.isEmpty else { return false }

        let scalars = Array(host.unicodeScalars)
        guard scalars.allSatisfy({ scalar in
            scalar.value >= 0x20
                && scalar.value != 0x7F
                && !CharacterSet.whitespacesAndNewlines.contains(scalar)
        }) else { return false }

        if host.first == "[" || host.last == "]" {
            return validIPLiteralHost(host)
        }

        // A plain DNS/reg-name host must not keep URL separators or leftover percent signs, which
        // would make the origin ambiguous.
        return scalars.allSatisfy(isSafeRegNameScalar)
    }

    private static func validIPLiteralHost(_ host: String) -> Bool {
        guard host.first == "[", host.last == "]", host.count > 2 else { return false }
        let inner = host.dropFirst().dropLast()
        let parts = inner.split(separator: "%", omittingEmptySubsequences: false)
        guard parts.count <= 2,
              let address = parts.first,
              !address.isEmpty else { return false }

        if address.first == "v" || address.first == "V" {
            // RFC 3986 IPvFuture form: v<hex>.<unreserved/sub-delims>.
            let body = address.dropFirst()
            guard let dot = body.firstIndex(of: "."), dot != body.startIndex else { return false }
            let version = body[..<dot]
            let futureAddress = body[body.index(after: dot)...]
            guard !futureAddress.isEmpty,
                  version.unicodeScalars.allSatisfy(isHexScalar),
                  futureAddress.unicodeScalars.allSatisfy(isIPvFutureScalar) else { return false }
        } else {
            // IPv6 may end with an embedded IPv4 part; only character boundaries are checked here,
            // leaving address semantics to the system network stack.
            guard address.unicodeScalars.contains(where: { $0.value == 0x3A }),
                  address.unicodeScalars.allSatisfy(isIPv6Scalar) else { return false }
        }

        if parts.count == 2 {
            let zone = parts[1]
            guard !zone.isEmpty, zone.unicodeScalars.allSatisfy(isZoneScalar) else { return false }
        }
        return true
    }

    private static func isSafeRegNameScalar(_ scalar: Unicode.Scalar) -> Bool {
        if CharacterSet.alphanumerics.contains(scalar) { return true }
        switch scalar.value {
        case 0x2D, 0x2E, 0x5F, 0x7E, // unreserved: - . _ ~
             0x21, 0x24, 0x26, 0x27, 0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x3B, 0x3D:
            return true
        default:
            return false
        }
    }

    private static func isIPv6Scalar(_ scalar: Unicode.Scalar) -> Bool {
        isHexScalar(scalar) || scalar.value == 0x3A || scalar.value == 0x2E
    }

    private static func isIPvFutureScalar(_ scalar: Unicode.Scalar) -> Bool {
        isSafeRegNameScalar(scalar) || scalar.value == 0x3A
    }

    private static func isZoneScalar(_ scalar: Unicode.Scalar) -> Bool {
        if CharacterSet.alphanumerics.contains(scalar) { return true }
        switch scalar.value {
        case 0x2D, 0x2E, 0x5F, 0x7E: return true
        default: return false
        }
    }

    private static func isHexScalar(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 48...57, 65...70, 97...102: return true
        default: return false
        }
    }

    private static func upsert(_ pair: (String, String), into values: inout [(String, String)]) {
        if let index = values.firstIndex(where: { $0.0 == pair.0 }) { values[index] = pair } else { values.append(pair) }
    }

    private static func parseQuery(_ raw: String?) throws -> [(String, String)] {
        guard let raw, !raw.isEmpty else { return [] }
        return try raw.split(separator: "&", omittingEmptySubsequences: false).map { part in
            let pieces = part.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let key = try decode(String(pieces[0]))
            guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw VisitorSDKError.invalidQueryKey }
            let value = try decode(pieces.count == 2 ? String(pieces[1]) : "")
            return (key, value)
        }
    }

    static func decode(_ value: String) throws -> String {
        var bytes: [UInt8] = []; let chars = Array(value.utf8); var i = 0
        while i < chars.count {
            if chars[i] == 37 {
                guard i + 2 < chars.count, let h = hex(chars[i + 1]), let l = hex(chars[i + 2]) else { throw VisitorSDKError.invalidURL }
                bytes.append(h * 16 + l); i += 3
            } else { bytes.append(chars[i]); i += 1 }
        }
        guard let result = String(bytes: bytes, encoding: .utf8) else { throw VisitorSDKError.invalidURL }
        return result
    }

    private static func hex(_ byte: UInt8) -> UInt8? {
        switch byte { case 48...57: return byte - 48; case 65...70: return byte - 55; case 97...102: return byte - 87; default: return nil }
    }

    static func encode(_ value: String) -> String {
        value.utf8.map { byte in
            if (48...57).contains(byte) || (65...90).contains(byte) || (97...122).contains(byte) || byte == 45 || byte == 46 || byte == 95 || byte == 126 { return String(UnicodeScalar(byte)) }
            return String(format: "%%%02X", byte)
        }.joined()
    }
}
