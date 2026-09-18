import Foundation
import Testing
@testable import RuteinKit

@MainActor
@Suite("RouteDetailViewModel")
struct RouteDetailViewModelTests {
    private func opened(isSaved: Bool) -> OpenedRoute {
        OpenedRoute(
            route: ImportedRoute(
                name: "Ridge Loop",
                geometry: RouteGeometry(segments: []),
                summary: RouteSummary(
                    distanceMetres: 20000,
                    elevationCoverage: .complete,
                    ascentMetres: 1200,
                    descentMetres: 1200,
                    minimumElevationMetres: 800,
                    maximumElevationMetres: 1600,
                ),
            ),
            data: isSaved ? nil : Data("<gpx/>".utf8),
            isSaved: isSaved,
        )
    }

    @Test("A saved route offers no save button")
    func savedRouteOffersNoSaveButton() {
        let viewModel = RouteDetailViewModel(opened: opened(isSaved: true), routes: FakeRouteRepository())

        #expect(!viewModel.canSave)
        #expect(viewModel.isSaved)
    }

    @Test("Saving a draft flips it to saved and hides the button")
    func savingADraftFlipsItToSaved() async {
        let viewModel = RouteDetailViewModel(opened: opened(isSaved: false), routes: FakeRouteRepository())

        #expect(viewModel.canSave)

        await viewModel.save()

        #expect(viewModel.isSaved)
        #expect(!viewModel.canSave)
        #expect(viewModel.saveFailure == nil)
    }

    @Test("A failed save keeps the metrics and never claims the route is saved")
    func failedSaveNeverClaimsSaved() async {
        let repository = FakeRouteRepository()

        await repository.fail(with: .storage)

        let viewModel = RouteDetailViewModel(opened: opened(isSaved: false), routes: repository)

        await viewModel.save()

        #expect(viewModel.saveFailure == "detail.save.failed")
        #expect(!viewModel.isSaved)
        #expect(viewModel.canSave)
        #expect(viewModel.metrics.count == 5)
    }

    @Test("Retrying after a failed save succeeds")
    func retryingAfterAFailedSaveSucceeds() async {
        let repository = FakeRouteRepository()

        await repository.fail(with: .storage)

        let viewModel = RouteDetailViewModel(opened: opened(isSaved: false), routes: repository)

        await viewModel.save()
        await repository.fail(with: nil)
        viewModel.dismissSaveFailure()
        await viewModel.save()

        #expect(viewModel.isSaved)
        #expect(viewModel.saveFailure == nil)
    }
}
