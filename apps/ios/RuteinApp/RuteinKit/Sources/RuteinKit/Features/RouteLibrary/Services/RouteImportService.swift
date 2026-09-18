import Foundation

public enum RouteImportService {
    public static let maximumFileBytes = 20 * 1024 * 1024

    public static func read(from url: URL) throws -> Data {
        try read(url)
    }

    public static func document(_ data: Data) async throws -> GPXDocument {
        try await GPXParser.parse(data)
    }

    public static func route(
        named name: String,
        from document: GPXDocument,
        candidate: RouteCandidate,
    ) async throws -> ImportedRoute {
        let geometry = document.geometry(for: candidate)

        return try await ImportedRoute(
            name: name,
            geometry: geometry,
            summary: RouteAnalyzer.analyse(geometry),
            sourceKind: candidate.kind,
            sourceIndex: candidate.id,
            sourceName: candidate.name,
        )
    }

    public static func suggestedName(for url: URL) -> String {
        url.deletingPathExtension().lastPathComponent
    }
˝
    static func read(_ url: URL) throws -> Data {
        let scoped = url.startAccessingSecurityScopedResource()

        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data: Data

        do {
            data = try Data(contentsOf: url)
        } catch {
            throw AppError.access
        }

        guard data.count <= maximumFileBytes else {
            throw AppError.capacity
        }

        return data
    }
}
