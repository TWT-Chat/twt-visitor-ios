import Foundation
import TwtVisitorSDK

/// Testable input model for the sample's custom form; strings stay in the user's own form and are parsed at submit time.
struct CustomVisitorConfigurationInput {
    var urlText: String
    var queryText: String
    var language: VisitorLanguage
    var theme: VisitorTheme
    var directChatIdText: String
}

/// Input errors of the sample form, each with a message that can be shown to the user directly.
enum CustomVisitorConfigurationError: LocalizedError, Equatable {
    case invalidURL
    case invalidQueryFormat
    case invalidQueryKey
    case invalidQueryEncoding

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Enter a complete HTTPS URL including a valid host"
        case .invalidQueryFormat:
            return "Query parameters must use the key=value&key2=value2 format"
        case .invalidQueryKey:
            return "Query parameter names must not be empty"
        case .invalidQueryEncoding:
            return "Query parameters contain invalid percent encoding"
        }
    }
}

/// Converts the sample form text into the SDK's typed configuration; every untrusted input is validated before it reaches the WebView.
enum CustomVisitorConfigurationBuilder {
    static func makeConfiguration(from input: CustomVisitorConfigurationInput) throws -> VisitorConfiguration {
        let urlText = input.urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        try validateRawURLPercentEscapes(urlText)
        guard let components = URLComponents(string: urlText),
              components.scheme?.lowercased() == "https",
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil,
              components.port.map({ (1...65535).contains($0) }) ?? true,
              let url = components.url else {
            throw CustomVisitorConfigurationError.invalidURL
        }
        try validateHost(components, decodedHost: host)
        try validatePercentEncoding(components.percentEncodedPath, error: .invalidURL)
        try validatePercentEncoding(components.percentEncodedQuery ?? "", error: .invalidQueryEncoding)
        try validatePercentEncoding(components.percentEncodedFragment ?? "", error: .invalidURL)
        try validateExistingQuery(components.percentEncodedQuery)

        let directChatID = input.directChatIdText.trimmingCharacters(in: .whitespacesAndNewlines)
        let directChatIDValue = directChatID.isEmpty ? nil : directChatID

        return VisitorConfiguration(
            url: url,
            query: try parseQuery(input.queryText),
            title: "Online support",
            language: input.language,
            theme: input.theme,
            directChatId: directChatIDValue
        )
    }

    private static func parseQuery(_ text: String) throws -> [String: String] {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [:] }

        var query: [String: String] = [:]
        for rawPair in text.split(separator: "&", omittingEmptySubsequences: false) {
            guard !rawPair.isEmpty else { throw CustomVisitorConfigurationError.invalidQueryFormat }
            let pieces = rawPair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let key = try decode(String(pieces[0]))
            guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw CustomVisitorConfigurationError.invalidQueryKey
            }
            query[key] = try decode(pieces.count == 2 ? String(pieces[1]) : "")
        }
        return query
    }

    private static func decode(_ value: String) throws -> String {
        var bytes: [UInt8] = []
        let source = Array(value.utf8)
        var index = 0
        while index < source.count {
            if source[index] == 37 {
                guard index + 2 < source.count,
                      let high = hex(source[index + 1]),
                      let low = hex(source[index + 2]) else {
                    throw CustomVisitorConfigurationError.invalidQueryEncoding
                }
                bytes.append(high * 16 + low)
                index += 3
            } else {
                bytes.append(source[index])
                index += 1
            }
        }
        guard let result = String(bytes: bytes, encoding: .utf8) else {
            throw CustomVisitorConfigurationError.invalidQueryEncoding
        }
        return result
    }

    private static func validatePercentEncoding(
        _ value: String,
        error validationError: CustomVisitorConfigurationError
    ) throws {
        do { _ = try decode(value) }
        catch { throw validationError }
    }

    /// URLComponents decodes percent escapes inside the host; checking only that the host is
    /// non-empty would let control characters, whitespace, or path separators through. Validate the
    /// decoded host against DNS/IPv6 character boundaries so no ambiguous address reaches the WebView.
    private static func validateHost(_ components: URLComponents, decodedHost: String) throws {
        guard let percentEncodedHost = components.percentEncodedHost else {
            throw CustomVisitorConfigurationError.invalidURL
        }

        let host: String
        do {
            host = try decode(percentEncodedHost)
        } catch {
            throw CustomVisitorConfigurationError.invalidURL
        }

        guard host == decodedHost, !host.isEmpty else {
            throw CustomVisitorConfigurationError.invalidURL
        }

        let scalars = Array(host.unicodeScalars)
        guard scalars.allSatisfy({ scalar in
            scalar.value >= 0x20 && scalar.value != 0x7F
                && !CharacterSet.whitespacesAndNewlines.contains(scalar)
        }) else {
            throw CustomVisitorConfigurationError.invalidURL
        }

        if host.first == "[" || host.last == "]" {
            guard host.first == "[", host.last == "]", scalars.count > 3 else {
                throw CustomVisitorConfigurationError.invalidURL
            }
            let inner = scalars.dropFirst().dropLast()
            guard inner.contains(where: { $0.value == 58 }),
                  inner.allSatisfy({ scalar in
                      (scalar.value >= 48 && scalar.value <= 57)
                          || (scalar.value >= 65 && scalar.value <= 70)
                          || (scalar.value >= 97 && scalar.value <= 102)
                          || scalar.value == 58
                          || scalar.value == 46
                  }) else {
                throw CustomVisitorConfigurationError.invalidURL
            }
            return
        }

        guard !scalars.contains(where: { scalar in scalar.value == 58 || scalar.value == 91 || scalar.value == 93 }) else {
            throw CustomVisitorConfigurationError.invalidURL
        }

        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        var normalizedLabels = labels
        if normalizedLabels.last?.isEmpty == true { normalizedLabels.removeLast() }
        guard !normalizedLabels.isEmpty else { throw CustomVisitorConfigurationError.invalidURL }

        for label in normalizedLabels {
            guard !label.isEmpty,
                  label.first?.unicodeScalars.allSatisfy(isHostLabelScalar) == true,
                  label.last?.unicodeScalars.allSatisfy(isHostLabelScalar) == true,
                  label.unicodeScalars.allSatisfy(isHostLabelScalar) else {
                throw CustomVisitorConfigurationError.invalidURL
            }
        }
    }

    private static func isHostLabelScalar(_ scalar: Unicode.Scalar) -> Bool {
        CharacterSet.alphanumerics.contains(scalar) || scalar.value == 45 || scalar.value == 95
    }

    private static func validateRawURLPercentEscapes(_ value: String) throws {
        let bytes = Array(value.utf8)
        let queryStart = bytes.firstIndex(of: 63)
        let fragmentStart = bytes.firstIndex(of: 35)
        var index = 0
        while index < bytes.count {
            guard bytes[index] != 37 else {
                guard index + 2 < bytes.count,
                      hex(bytes[index + 1]) != nil,
                      hex(bytes[index + 2]) != nil else {
                    let isQueryEscape = queryStart.map { index > $0 && (fragmentStart.map { index < $0 } ?? true) } ?? false
                    throw isQueryEscape
                        ? CustomVisitorConfigurationError.invalidQueryEncoding
                        : CustomVisitorConfigurationError.invalidURL
                }
                index += 3
                continue
            }
            index += 1
        }
    }

    private static func validateExistingQuery(_ rawQuery: String?) throws {
        guard let rawQuery, !rawQuery.isEmpty else { return }
        for rawPair in rawQuery.split(separator: "&", omittingEmptySubsequences: false) {
            guard !rawPair.isEmpty else { throw CustomVisitorConfigurationError.invalidQueryFormat }
            let pieces = rawPair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let key = try decode(String(pieces[0]))
            guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw CustomVisitorConfigurationError.invalidQueryKey
            }
            _ = try decode(pieces.count == 2 ? String(pieces[1]) : "")
        }
    }

    private static func hex(_ byte: UInt8) -> UInt8? {
        switch byte {
        case 48...57: return byte - 48
        case 65...70: return byte - 55
        case 97...102: return byte - 87
        default: return nil
        }
    }
}
