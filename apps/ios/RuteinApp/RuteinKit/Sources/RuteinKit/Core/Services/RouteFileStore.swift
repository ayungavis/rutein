import Foundation

public struct RouteFileStore: Sendable {
    public static let directoryName = "Routes"

    private let root: URL?

    public init(root: URL? = nil) {
        self.root = root
    }

    public static func fileName(for id: UUID) -> String {
        "\(id.uuidString).gpx"
    }

    public func write(_ data: Data, named fileName: String) throws {
        do {
            try data.write(to: directory().appending(path: fileName), options: .atomic)
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.storage
        }
    }

    public func read(_ fileName: String) throws -> Data {
        do {
            return try Data(contentsOf: directory().appending(path: fileName))
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.access
        }
    }

    public func remove(_ fileName: String) throws {
        let url = try directory().appending(path: fileName)

        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            throw AppError.storage
        }
    }

    public func fileNames() throws -> [String] {
        do {
            return try FileManager.default
                .contentsOfDirectory(atPath: directory().path)
                .filter { $0.hasSuffix(".gpx") }
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.storage
        }
    }

    private func directory() throws -> URL {
        do {
            let base = try root ?? FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true,
            )
            let directory = base.appending(path: Self.directoryName)

            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            return directory
        } catch {
            throw AppError.storage
        }
    }
}
