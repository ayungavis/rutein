import CryptoKit
import Foundation

public enum RouteFingerprint {
    public static func of(_ data: Data, kind: RouteSourceKind = .track, index: Int = 0) -> String {
        var hasher = SHA256()

        hasher.update(data: data)
        hasher.update(data: Data("\(kind.rawValue)#\(index)".utf8))

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    public static func of(_ route: ImportedRoute, in data: Data) -> String {
        of(data, kind: route.sourceKind, index: route.sourceIndex)
    }
}
