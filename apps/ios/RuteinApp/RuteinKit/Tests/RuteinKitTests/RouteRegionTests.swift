import CoreLocation
import Foundation
import Testing
@testable import RuteinKit

@Suite("RouteRegion")
struct RouteRegionTests {
    private func point(latitude: Double, longitude: Double) -> TrackPoint {
        TrackPoint(latitude: latitude, longitude: longitude, elevation: nil, timestamp: nil)
    }

    private func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "gpx"))
        return try Data(contentsOf: url)
    }

    @Test("Coordinates skip points a parser accepted but a map cannot plot")
    func coordinatesSkipUnplottablePoints() {
        let geometry = RouteGeometry(
            segments: [
                [
                    point(latitude: -8.36, longitude: 115.46),
                    point(latitude: 91, longitude: 115.46),
                    point(latitude: -8.35, longitude: 181),
                    point(latitude: .nan, longitude: 115.46),
                    point(latitude: -8.34, longitude: 115.5),
                ],
            ],
        )

        let coordinates = RouteRegion.coordinates(from: geometry)

        #expect(coordinates.count == 2)
        #expect(coordinates.map(\.latitude) == [-8.36, -8.34])
    }

    @Test("An empty route has no region to fit")
    func emptyRouteHasNoRegion() {
        #expect(RouteRegion.region(fitting: []) == nil)
    }

    @Test("A region centres on the route and pads its span")
    func regionCentresAndPads() throws {
        let region = try #require(
            RouteRegion.region(fitting: [
                CLLocationCoordinate2D(latitude: 10, longitude: 20),
                CLLocationCoordinate2D(latitude: 11, longitude: 24),
            ]),
        )

        #expect(abs(region.center.latitude - 10.5) < 0.000001)
        #expect(abs(region.center.longitude - 22) < 0.000001)
        #expect(abs(region.span.latitudeDelta - 1 * RouteRegion.paddingFactor) < 0.000001)
        #expect(abs(region.span.longitudeDelta - 4 * RouteRegion.paddingFactor) < 0.000001)
    }

    @Test("A single point still yields a usable span rather than a zero one")
    func singlePointYieldsMinimumSpan() throws {
        let region = try #require(
            RouteRegion.region(fitting: [CLLocationCoordinate2D(latitude: -8.35, longitude: 115.48)]),
        )

        #expect(region.span.latitudeDelta == RouteRegion.minimumSpanDegrees)
        #expect(region.span.longitudeDelta == RouteRegion.minimumSpanDegrees)
        #expect(abs(region.center.longitude - 115.48) < 0.000001)
    }

    @Test("A route across the antimeridian does not fit to a global view")
    func antimeridianRouteStaysLocal() throws {
        let region = try #require(
            RouteRegion.region(fitting: [
                CLLocationCoordinate2D(latitude: -17.5, longitude: 179.9),
                CLLocationCoordinate2D(latitude: -17.6, longitude: -179.9),
            ]),
        )

        #expect(region.span.longitudeDelta < 1)
        #expect(abs(abs(region.center.longitude) - 180) < 0.000001)
    }

    @Test("The real climb fits its own valley, not the island")
    func realClimbFitsItsValley() async throws {
        let geometry = try await GPXParser.geometry(fixture("wikiloc-mt-agung"))
        let coordinates = RouteRegion.coordinates(from: geometry)
        let region = try #require(RouteRegion.region(fitting: coordinates))

        #expect(coordinates.count == 256)
        #expect(abs(region.center.latitude - -8.3519) < 0.01)
        #expect(abs(region.center.longitude - 115.4823) < 0.01)
        #expect(region.span.latitudeDelta < 0.1)
        #expect(region.span.longitudeDelta < 0.1)
    }
}
