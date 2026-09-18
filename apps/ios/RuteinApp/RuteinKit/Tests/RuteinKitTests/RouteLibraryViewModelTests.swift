import Foundation
import Testing
@testable import RuteinKit

@MainActor
@Suite("RouteLibraryViewModel")
struct RouteLibraryViewModelTests {
    private func stored(
        _ name: String,
        fingerprint: String = "abc",
        plan: RoutePlan? = nil,
    ) -> StoredRoute {
        StoredRoute(
            id: UUID(),
            name: name,
            summary: RouteSummary(
                distanceMetres: 12437,
                elevationCoverage: .complete,
                ascentMetres: 680,
                descentMetres: 680,
                minimumElevationMetres: 100,
                maximumElevationMetres: 780,
            ),
            outline: [],
            fingerprint: fingerprint,
            updatedAt: .now,
            plan: plan,
        )
    }

    private func fixtureURL(_ name: String) throws -> URL {
        try #require(Bundle.module.url(forResource: name, withExtension: "gpx"))
    }

    @Test("Loading surfaces the saved routes in the order the repository gives them")
    func loadingSurfacesSavedRoutes() async {
        let repository = FakeRouteRepository(stored: [stored("Second"), stored("First")])
        let viewModel = RouteLibraryViewModel(routes: repository)

        await viewModel.load()

        #expect(viewModel.savedRoutes.map(\.name) == ["Second", "First"])
        #expect(viewModel.libraryFailure == nil)
    }

    @Test("A failed load reports itself and keeps the routes already on screen")
    func failedLoadKeepsPreviousRoutes() async {
        let repository = FakeRouteRepository(stored: [stored("Agung")])
        let viewModel = RouteLibraryViewModel(routes: repository)

        await viewModel.load()
        await repository.fail(with: .storage)
        await viewModel.load()

        #expect(viewModel.libraryFailure == "library.failed.storage")
        #expect(viewModel.savedRoutes.map(\.name) == ["Agung"])
    }

    @Test("A route whose owned file is gone offers reimport rather than opening empty")
    func missingOwnedFileOffersReimport() async {
        let route = stored("Agung")
        let repository = FakeRouteRepository(stored: [route])
        let viewModel = RouteLibraryViewModel(routes: repository)

        await viewModel.open(route)

        #expect(viewModel.openFailure == "library.open.missing")
        #expect(viewModel.openedRoute == nil)
    }

    @Test("Opening a route hands the detail screen a saved route with its geometry")
    func openingHandsOverASavedRoute() async throws {
        let route = stored("Agung")
        let repository = FakeRouteRepository()
        let geometry = try await GPXParser.geometry(Data(contentsOf: fixtureURL("wikiloc-mt-agung")))

        await repository.put(route, geometry: geometry)

        let viewModel = RouteLibraryViewModel(routes: repository)

        await viewModel.open(route)

        #expect(viewModel.openedRoute?.isSaved == true)
        #expect(viewModel.openedRoute?.data == nil)
        #expect(viewModel.openedRoute?.route.geometry.pointCount == 256)
    }

    @Test("Opening a saved route carries its saved plan through to the detail screen")
    func openingCarriesTheSavedPlan() async throws {
        let plan = try RoutePlan(targetDurationSeconds: 18000, drinkIntervalMinutes: 30)
        let route = stored("Agung", plan: plan)
        let repository = FakeRouteRepository()
        let geometry = try await GPXParser.geometry(Data(contentsOf: fixtureURL("wikiloc-mt-agung")))

        await repository.put(route, geometry: geometry)

        let viewModel = RouteLibraryViewModel(routes: repository)

        await viewModel.open(route)

        #expect(viewModel.openedRoute?.plan == plan)
    }

    @Test("An invalid rename reports itself and leaves the name alone")
    func invalidRenameLeavesTheNameAlone() async {
        let route = stored("Agung")
        let repository = FakeRouteRepository(stored: [route])
        let viewModel = RouteLibraryViewModel(routes: repository)

        await viewModel.load()
        viewModel.renaming = route
        await viewModel.commitRename("   ")

        #expect(viewModel.renameFailure == "library.rename.invalid")
        #expect(viewModel.savedRoutes.map(\.name) == ["Agung"])
    }

    @Test("A confirmed delete removes the route and refreshes the library")
    func confirmedDeleteRemovesTheRoute() async {
        let route = stored("Agung")
        let repository = FakeRouteRepository(stored: [route, stored("Rinjani")])
        let viewModel = RouteLibraryViewModel(routes: repository)

        await viewModel.load()
        viewModel.deleting = route
        await viewModel.confirmDelete()

        #expect(viewModel.savedRoutes.map(\.name) == ["Rinjani"])
        #expect(viewModel.deleting == nil)
    }

    @Test("Importing a file already saved asks rather than opening or duplicating")
    func importingADuplicateAsks() async throws {
        let url = try fixtureURL("wikiloc-mt-agung")
        let fingerprint = try RouteFingerprint.of(Data(contentsOf: url))
        let repository = FakeRouteRepository(stored: [stored("Agung", fingerprint: fingerprint)])
        let viewModel = RouteLibraryViewModel(routes: repository)

        await viewModel.importRoute(.success(url)).value

        #expect(viewModel.duplicate?.existing.name == "Agung")
        #expect(viewModel.openedRoute == nil)
    }

    @Test("Choosing Import a copy opens the incoming file as an unsaved draft")
    func importingACopyOpensTheDraft() async throws {
        let url = try fixtureURL("wikiloc-mt-agung")
        let fingerprint = try RouteFingerprint.of(Data(contentsOf: url))
        let repository = FakeRouteRepository(stored: [stored("Agung", fingerprint: fingerprint)])
        let viewModel = RouteLibraryViewModel(routes: repository)

        await viewModel.importRoute(.success(url)).value
        viewModel.importDuplicateCopy()

        #expect(viewModel.duplicate == nil)
        #expect(viewModel.openedRoute?.isSaved == false)
        #expect(viewModel.openedRoute?.data != nil)
        #expect(viewModel.openedRoute?.route.name == "wikiloc-mt-agung")
    }

    @Test("A file nobody has saved opens straight through as a draft")
    func aNewFileOpensStraightThrough() async throws {
        let viewModel = RouteLibraryViewModel(routes: FakeRouteRepository())

        try await viewModel.importRoute(.success(fixtureURL("wikiloc-mt-agung"))).value

        #expect(viewModel.duplicate == nil)
        #expect(viewModel.openedRoute?.isSaved == false)
        #expect(viewModel.importFailure == nil)
    }

    @Test("A file with two tracks asks which one instead of picking for you")
    func twoTracksAskWhichOne() async throws {
        let viewModel = RouteLibraryViewModel(routes: FakeRouteRepository())

        try await viewModel.importRoute(.success(fixtureURL("two-tracks"))).value

        let pending = try #require(viewModel.pendingImport)

        #expect(pending.choices.count == 2)
        #expect(pending.choices.map(\.name) == ["Ascent", "Descent"])
        #expect(viewModel.openedRoute == nil)
        #expect(!viewModel.isImporting)
    }

    @Test("Choosing a track makes only that track the route geometry")
    func choosingATrackUsesOnlyThatTrack() async throws {
        let viewModel = RouteLibraryViewModel(routes: FakeRouteRepository())

        try await viewModel.importRoute(.success(fixtureURL("two-tracks"))).value

        let second = try #require(viewModel.pendingImport?.choices.last)

        await viewModel.choose(second)

        #expect(viewModel.pendingImport == nil)
        #expect(viewModel.openedRoute?.route.geometry.pointCount == 4)
        #expect(viewModel.openedRoute?.route.sourceIndex == 1)
        #expect(viewModel.openedRoute?.route.sourceName == "Descent")
    }

    @Test("A file with a single track never asks")
    func singleTrackNeverAsks() async throws {
        let viewModel = RouteLibraryViewModel(routes: FakeRouteRepository())

        try await viewModel.importRoute(.success(fixtureURL("wikiloc-mt-agung"))).value

        #expect(viewModel.pendingImport == nil)
        #expect(viewModel.openedRoute != nil)
    }

    @Test("A cancelled import opens nothing and leaves no failure behind")
    func cancelledImportOpensNothing() async throws {
        let viewModel = RouteLibraryViewModel(routes: FakeRouteRepository())
        let task = try viewModel.importRoute(.success(fixtureURL("wikiloc-mt-agung")))

        viewModel.cancelImport()

        await task.value

        #expect(viewModel.openedRoute == nil)
        #expect(viewModel.pendingImport == nil)
        #expect(viewModel.importFailure == nil)
        #expect(!viewModel.isImporting)
    }

    @Test("Cancelling while a selection is open discards the pending import")
    func cancellingDiscardsThePendingImport() async throws {
        let viewModel = RouteLibraryViewModel(routes: FakeRouteRepository())

        try await viewModel.importRoute(.success(fixtureURL("two-tracks"))).value

        #expect(viewModel.pendingImport != nil)

        viewModel.cancelImport()

        #expect(viewModel.pendingImport == nil)
        #expect(viewModel.openedRoute == nil)
    }

    @Test("A malformed file reports its format error and opens nothing")
    func aMalformedFileReportsFormat() async throws {
        let viewModel = RouteLibraryViewModel(routes: FakeRouteRepository())

        try await viewModel.importRoute(.success(fixtureURL("mailformed"))).value

        #expect(viewModel.importFailure == "import.failed.format")
        #expect(viewModel.openedRoute == nil)
    }
}
