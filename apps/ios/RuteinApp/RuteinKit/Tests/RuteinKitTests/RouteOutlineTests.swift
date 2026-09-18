import Foundation
import Testing
@testable import RuteinKit

@Suite("RouteOutline")
struct RouteOutlineTests {
    private func point(_ index: Int) -> TrackPoint {
        TrackPoint(latitude: Double(index) * 0.001, longitude: 0.5, elevation: nil, timestamp: nil)
    }

    @Test("A short route keeps every point")
    func shortRouteKeepsEveryPoint() {
        let geometry = RouteGeometry(segments: [(0 ..< 10).map(point)])

        #expect(RouteOutline.points(from: geometry).count == 10)
    }

    @Test("A long route thins to the budget and keeps both ends")
    func longRouteThinsToBudget() {
        let geometry = RouteGeometry(segments: [(0 ..< 5000).map(point)])
        let outline = RouteOutline.points(from: geometry)

        #expect(outline.count == RouteOutline.pointBudget)
        #expect(outline.first?.latitude == 0)
        #expect(abs((outline.last?.latitude ?? 0) - 4.999) < 0.000001)
    }

    @Test("Unplottable points never reach the outline")
    func unplottablePointsAreDropped() {
        let geometry = RouteGeometry(
            segments: [
                [
                    TrackPoint(latitude: 10, longitude: 20, elevation: nil, timestamp: nil),
                    TrackPoint(latitude: 91, longitude: 20, elevation: nil, timestamp: nil),
                    TrackPoint(latitude: 11, longitude: 21, elevation: nil, timestamp: nil),
                ],
            ],
        )

        #expect(RouteOutline.points(from: geometry).count == 2)
    }
}
