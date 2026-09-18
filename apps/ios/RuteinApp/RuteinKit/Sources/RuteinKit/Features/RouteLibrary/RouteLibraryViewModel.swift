import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
public final class RouteLibraryViewModel {
    private let routes: any RouteRepository

    private var importTask: Task<Void, Never>?

    public private(set) var library: Loadable<[StoredRoute]> = .idle
    public private(set) var importState: Loadable<ImportedFile> = .idle
    public private(set) var openFailure: LocalizedStringKey?
    public private(set) var renameFailure: LocalizedStringKey?
    public var isPickingFile = false
    public var openedRoute: OpenedRoute?
    public var duplicate: DuplicateRoute?
    public var renaming: StoredRoute?
    public var deleting: StoredRoute?
    public var pendingImport: PendingImport?

    public init(routes: any RouteRepository) {
        self.routes = routes
    }

    public var isImporting: Bool {
        if case .loading = importState {
            return true
        }

        return false
    }

    public var savedRoutes: [StoredRoute] {
        library.value ?? []
    }

    public var libraryFailure: LocalizedStringKey? {
        guard case .failed = library else { return nil }

        return "library.failed.storage"
    }

    public var importFailure: LocalizedStringKey? {
        guard case let .failed(error, _) = importState else { return nil }

        return Self.importFailureKey(for: error)
    }

    public static func importFailureKey(for error: AppError) -> LocalizedStringKey {
        switch error {
        case .access: "import.failed.access"
        case .format: "import.failed.format"
        case .geometry: "import.failed.geometry"
        case .capacity: "import.failed.capacity"
        default: "import.failed.unknown"
        }
    }

    public func dismissFailure() {
        importState = .idle
        openFailure = nil
        renameFailure = nil
    }

    public func load() async {
        library = .loading(previous: library.value)

        do {
            library = try await .loaded(routes.routes())
        } catch let error as AppError {
            Log.report(error)
            library = .failed(error, previous: library.value)
        } catch {
            Log.report(AppError.storage)
            library = .failed(.storage, previous: library.value)
        }
    }

    @discardableResult
    public func importRoute(_ result: Result<URL, Error>) -> Task<Void, Never> {
        guard case let .success(url) = result else {
            importState = .failed(.access, previous: importState.value)

            return Task {}
        }

        importState = .loading(previous: importState.value)
        importTask?.cancel()

        let task = Task { [weak self] in
            await self?.read(url)

            return
        }

        importTask = task

        return task
    }

    public func cancelImport() {
        importTask?.cancel()
        importTask = nil
        importState = .idle
        pendingImport = nil
    }

    public func choose(_ candidate: RouteCandidate) async {
        guard let pending = pendingImport else { return }

        pendingImport = nil

        await finish(pending, with: candidate)
    }

    private func read(_ url: URL) async {
        let operation = Log.newOperationID()

        do {
            let data = try RouteImportService.read(from: url)
            let document = try await Log.measure(
                .parsing,
                count: data.count,
                operation: operation,
            ) {
                try await RouteImportService.document(data)
            }

            guard !Task.isCancelled else { return }

            let pending = PendingImport(
                name: RouteImportService.suggestedName(for: url),
                data: data,
                document: document,
            )

            if pending.choices.count > 1 {
                importState = .idle
                pendingImport = pending
            } else if let only = pending.choices.first {
                await finish(pending, with: only)
            } else {
                importState = .failed(.geometry, previous: importState.value)
            }
        } catch let error as AppError {
            guard !Task.isCancelled, error != .cancelled else { return }

            Log.report(error)
            importState = .failed(error, previous: importState.value)
        } catch {
            guard !Task.isCancelled else { return }

            Log.report(AppError.format)
            importState = .failed(.format, previous: importState.value)
        }
    }

    private func finish(_ pending: PendingImport, with candidate: RouteCandidate) async {
        let operation = Log.newOperationID()

        do {
            let route = try await Log.measure(
                .analysis,
                count: candidate.pointCount,
                operation: operation,
            ) {
                try await RouteImportService.route(
                    named: pending.name,
                    from: pending.document,
                    candidate: candidate,
                )
            }

            guard !Task.isCancelled else { return }

            let file = ImportedFile(route: route, data: pending.data)

            importState = .loaded(file)

            if let existing = await existingDuplicate(of: file) {
                duplicate = DuplicateRoute(existing: existing, incoming: file)
            } else {
                openedRoute = OpenedRoute(route: route, data: pending.data, isSaved: false)
            }
        } catch let error as AppError {
            guard !Task.isCancelled, error != .cancelled else { return }

            Log.report(error)
            importState = .failed(error, previous: importState.value)
        } catch {
            guard !Task.isCancelled else { return }

            importState = .failed(.geometry, previous: importState.value)
        }
    }

    public func openDuplicateOriginal() async {
        guard let existing = duplicate?.existing else { return }

        duplicate = nil

        await open(existing)
    }

    public func importDuplicateCopy() {
        guard let incoming = duplicate?.incoming else { return }

        duplicate = nil
        openedRoute = OpenedRoute(route: incoming.route, data: incoming.data, isSaved: false)
    }

    public func open(_ stored: StoredRoute) async {
        do {
            openedRoute = try await OpenedRoute(
                route: ImportedRoute(
                    id: stored.id,
                    name: stored.name,
                    geometry: routes.geometry(id: stored.id),
                    summary: stored.summary,
                ),
                data: nil,
                isSaved: true,
                plan: stored.plan,
            )
        } catch let error as AppError {
            Log.report(error)
            openFailure = error == .access ? "library.open.missing" : "library.failed.storage"
        } catch {
            Log.report(AppError.storage)
            openFailure = "library.failed.storage"
        }
    }

    public func commitRename(_ name: String) async {
        guard let target = renaming else { return }

        renaming = nil

        do {
            _ = try await routes.rename(id: target.id, to: name)
            await load()
        } catch AppError.dataQuality {
            renameFailure = "library.rename.invalid"
        } catch {
            Log.report(AppError.storage)
            renameFailure = "library.failed.storage"
        }
    }

    public func confirmDelete() async {
        guard let target = deleting else { return }

        deleting = nil

        do {
            try await routes.delete(id: target.id)
            await load()
        } catch {
            Log.report(AppError.storage)
            library = .failed(.storage, previous: library.value)
        }
    }

    private func existingDuplicate(of file: ImportedFile) async -> StoredRoute? {
        do {
            return try await routes.existing(
                fingerprint: RouteFingerprint.of(file.route, in: file.data),
            )
        } catch {
            return nil
        }
    }
}
