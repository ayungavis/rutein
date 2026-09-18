import Foundation
import Testing
@testable import RuteinKit

@Suite("ClimbDetection")
struct ClimbDetectionTests {
    private static let stepMetres = 111.19492664455873

    private func segment(_ elevations: [Double]) -> [TrackPoint] {
        elevations.enumerated().map { index, elevation in
            TrackPoint(
                latitude: Double(index) * 0.001,
                longitude: 0,
                elevation: elevation,
                timestamp: nil,
            )
        }
    }

    private func climbs(_ elevations: [Double]...) -> [SustainedClimb] {
        ClimbDetection.climbs(in: RouteGeometry(segments: elevations.map(segment)))
    }

    private func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "gpx"))
        return try Data(contentsOf: url)
    }

    @Test("A flat route has no sustained climb")
    func flatRouteHasNoClimb() {
        #expect(climbs([100, 100, 100, 100, 100]).isEmpty)
    }

    @Test("A steep rise shorter than the minimum distance is not a climb")
    func tooShortIsNotAClimb() {
        #expect(climbs([100, 200]).isEmpty)
    }

    @Test("A rise smaller than the minimum gain is not a climb")
    func tooSmallIsNotAClimb() {
        #expect(climbs([100, 104, 108, 112, 115]).isEmpty)
    }

    @Test("A long drag below the minimum grade is not a climb")
    func tooShallowIsNotAClimb() {
        let elevations = (0 ..< 21).map { 100 + Double($0) * 1.5 }
        let found = climbs(elevations)

        #expect(found.isEmpty)
    }

    @Test("A dip within the drawdown tolerance does not split a climb")
    func shallowDipDoesNotSplit() throws {
        let found = climbs([100, 150, 200, 185, 240, 300])
        let climb = try #require(found.first)

        #expect(found.count == 1)
        #expect(climb.gainMetres == 200)
        #expect(abs(climb.distanceMetres - 5 * Self.stepMetres) < 0.001)
    }

    @Test("A dip past the drawdown tolerance splits one climb into two")
    func deepDipSplits() {
        let found = climbs([100, 150, 200, 170, 220, 260])

        #expect(found.map(\.gainMetres) == [100, 90])
        #expect(found.allSatisfy { $0.distanceMetres >= ClimbDetection.minimumDistanceMetres })
    }

    @Test("A segment break contributes no distance and no climb spans it")
    func segmentBreakIsNeverSpanned() {
        let found = climbs([100, 150, 200], [300, 400, 500])

        #expect(found.count == 2)
        #expect(found.map(\.gainMetres) == [100, 200])
        #expect(found[1].startMetres == found[0].endMetres)
    }

    @Test("The key climb is the largest gain, not the first one found")
    func keyClimbIsTheLargestGain() throws {
        let geometry = RouteGeometry(segments: [[100, 150, 200], [300, 400, 500]].map(segment))
        let climb = try #require(ClimbDetection.keyClimb(in: geometry))

        #expect(climb.gainMetres == 200)
    }

    @Test("A route with no elevation has no climb rather than a zero one")
    func noElevationHasNoClimb() {
        let segment = (0 ..< 5).map { index in
            TrackPoint(latitude: Double(index) * 0.001, longitude: 0, elevation: nil, timestamp: nil)
        }

        #expect(ClimbDetection.climbs(in: RouteGeometry(segments: [segment])).isEmpty)
    }

    @Test("The real climb is found end to end")
    func realClimbIsFound() async throws {
        let geometry = try await GPXParser.geometry(fixture("wikiloc-mt-agung"))
        let climb = try #require(ClimbDetection.keyClimb(in: geometry))

        #expect(climb.startMetres == 0)
        #expect(abs(climb.endMetres - 5901.744) < 0.01)
        #expect(abs(climb.gainMetres - 1858.882) < 0.001)
        #expect(abs(climb.grade - 0.3150) < 0.0001)
    }
}
