import Foundation
import Testing
@testable import RuteinKit

@MainActor
@Suite("RouteBriefViewModel")
struct RouteBriefViewModelTests {
    private static let markerLatitude = 12.345678

    private func opened(isSaved: Bool, plan: RoutePlan? = nil, named: Bool = true) -> OpenedRoute {
        let points = (0 ..< 180).map { step in
            TrackPoint(
                latitude: Self.markerLatitude + Double(step) * 0.001,
                longitude: 98.7654321,
                elevation: 900 + Double(step) * 4,
                timestamp: nil,
            )
        }
        let waypoints = named
            ? [
                Waypoint(
                    name: "Water point",
                    latitude: Self.markerLatitude + 0.045,
                    longitude: 98.7654321,
                    elevation: 1100,
                ),
            ]
            : []

        return OpenedRoute(
            route: ImportedRoute(
                name: "Ridge Loop",
                geometry: RouteGeometry(segments: [points], waypoints: waypoints),
                summary: RouteSummary(
                    distanceMetres: 20000,
                    elevationCoverage: .complete,
                    ascentMetres: 1200,
                    descentMetres: 1200,
                    minimumElevationMetres: 800,
                    maximumElevationMetres: 1600,
                ),
            ),
            data: isSaved ? nil : Data("<gpx><trkpt lat=\"12.345678\"/></gpx>".utf8),
            isSaved: isSaved,
            plan: plan,
        )
    }

    private func viewModel(
        isSaved: Bool = true,
        savedPlan: RoutePlan? = nil,
        named: Bool = true,
        seconds: Double = 18000,
        drink: Int? = nil,
        start: Date? = nil,
        repository: FakeRouteRepository = FakeRouteRepository(),
    ) throws -> RouteBriefViewModel {
        let plan = try RoutePlan(
            targetDurationSeconds: seconds,
            startInstant: start,
            timeZoneIdentifier: start == nil ? nil : "Asia/Makassar",
            drinkIntervalMinutes: drink,
        )

        return RouteBriefViewModel(
            planned: PlannedRoute(
                opened: opened(isSaved: isSaved, plan: savedPlan, named: named),
                plan: plan,
            ),
            routes: repository,
        )
    }

    @Test("The brief opens on the route's own numbers")
    func briefCarriesTheRouteNumbers() throws {
        let viewModel = try viewModel()

        #expect(viewModel.name == "Ridge Loop")
        #expect(viewModel.averagePace == RouteFormat.pace(secondsPerKilometre: 900))
        #expect(viewModel.targetDuration == RouteFormat.duration(18000))
    }

    @Test("The shared text carries the name, the estimate method and every timeline row")
    func shareTextCarriesTheBrief() throws {
        let viewModel = try viewModel(drink: 30)
        let lines = viewModel.shareText.split(separator: "\n", omittingEmptySubsequences: false)

        #expect(lines.first == "Ridge Loop")
        #expect(viewModel.shareText.contains("Distance-based estimate"))
        #expect(viewModel.shareText.contains(RouteFormat.distance(20000)))
        #expect(viewModel.rows.allSatisfy { viewModel.shareText.contains($0.offset) })
        #expect(lines.count >= viewModel.rows.count + 5)
    }

    @Test("The shared text never leaks a coordinate or the GPX itself")
    func shareTextNeverLeaksGeometry() throws {
        let text = try viewModel(isSaved: false, drink: 30).shareText

        #expect(!text.contains("12.345678"))
        #expect(!text.contains("98.7654321"))
        #expect(!text.contains("<gpx"))
        #expect(!text.contains("trkpt"))
    }

    @Test("Without a start time every row stays an offset")
    func withoutAStartTimeRowsStayRelative() throws {
        let rows = try viewModel(drink: 30).rows

        #expect(rows.allSatisfy { $0.offset.hasPrefix("+") })
        #expect(rows.first?.offset == "+\(RouteFormat.offset(0))")
    }

    @Test("With a start time the rows carry arrival times instead")
    func withAStartTimeRowsCarryArrivals() throws {
        let start = Date(timeIntervalSince1970: 1_758_000_000)
        let viewModel = try viewModel(start: start)

        #expect(viewModel.rows.allSatisfy { !$0.offset.hasPrefix("+") })
        #expect(viewModel.shareText.contains("Start"))
    }

    @Test("A route with no usable waypoints says its markers are not aid stations")
    func markerNoticeAppearsOnlyForMarkers() throws {
        #expect(try viewModel(named: false).usesDistanceMarkers)
        #expect(try !viewModel(named: true).usesDistanceMarkers)
        #expect(try viewModel(named: false).shareText.contains("not aid stations"))
        #expect(try !viewModel(named: true).shareText.contains("not aid stations"))
    }

    @Test("Saving a plan on an unsaved route stores the route and the plan together")
    func savingStoresRouteAndPlan() async throws {
        let repository = FakeRouteRepository()
        let viewModel = try viewModel(isSaved: false, repository: repository)

        await viewModel.savePlan()

        let stored = try await repository.routes()

        #expect(viewModel.isSaved)
        #expect(stored.count == 1)
        #expect(stored.first?.plan?.targetDurationSeconds == 18000)
    }

    @Test("A failed save keeps the brief and never claims the plan is saved")
    func failedSaveNeverClaimsSaved() async throws {
        let repository = FakeRouteRepository()

        await repository.fail(with: .storage)

        let viewModel = try viewModel(isSaved: false, repository: repository)

        await viewModel.savePlan()

        #expect(!viewModel.isSaved)
        #expect(viewModel.saveFailure == "brief.save.failed")
        #expect(viewModel.rows.count > 1)
    }

    @Test("A brief that matches the saved plan offers no save button")
    func matchingPlanOffersNoSave() throws {
        let plan = try RoutePlan(targetDurationSeconds: 18000)
        let viewModel = RouteBriefViewModel(
            planned: PlannedRoute(opened: opened(isSaved: true, plan: plan), plan: plan),
            routes: FakeRouteRepository(),
        )

        #expect(viewModel.isSaved)
    }

    @Test("Editing a saved plan marks the brief unsaved again")
    func editedPlanIsUnsavedAgain() throws {
        let saved = try RoutePlan(targetDurationSeconds: 18000)
        let edited = try RoutePlan(targetDurationSeconds: 21600)
        let viewModel = RouteBriefViewModel(
            planned: PlannedRoute(opened: opened(isSaved: true, plan: saved), plan: edited),
            routes: FakeRouteRepository(),
        )

        #expect(!viewModel.isSaved)
    }

    @Test("A short timeline offers a card; a long one stays text-only rather than truncating")
    func imageExportIsOfferedOnlyWhenItFits() throws {
        let short = try viewModel(drink: 30)
        let long = try viewModel(seconds: 48 * 3600, drink: 5)

        #expect(short.rows.count <= RouteBriefViewModel.imageRowLimit)
        #expect(short.canExportImage)
        #expect(long.rows.count > RouteBriefViewModel.imageRowLimit)
        #expect(!long.canExportImage)
        #expect(long.briefImage().image == nil)
        #expect(long.briefImage().explanation == "brief.share.image.tooLong")
    }

    @Test("A long timeline still shares every row as text")
    func longTimelineStillSharesAsText() throws {
        let long = try viewModel(seconds: 48 * 3600, drink: 5)

        let text = long.shareText

        #expect(long.rows.allSatisfy { text.contains($0.offset) })
        #expect(text.contains("Distance-based estimate"))
    }

    @Test("Opening and cancelling the share preview changes nothing")
    func cancellingShareChangesNothing() throws {
        let viewModel = try viewModel(isSaved: true, savedPlan: RoutePlan(targetDurationSeconds: 18000))
        let before = viewModel.shareText

        viewModel.isPreviewingShare = true
        viewModel.isPreviewingShare = false

        #expect(viewModel.shareText == before)
        #expect(viewModel.isSaved)
    }
}
