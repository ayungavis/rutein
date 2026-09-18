import Foundation
import Testing
@testable import RuteinKit

@Suite("GradeWindow and RoutePosition")
struct GradeWindowTests {
    private static let stepMetres = 111.19492664455873

    private func run(count: Int, from offset: Double = 0, gradient: Double = 0.1) -> [ElevationSample] {
        (0 ..< count).map { index in
            ElevationSample(
                distanceMetres: offset + Double(index) * Self.stepMetres,
                elevationMetres: 100 + offset * gradient + Double(index) * Self.stepMetres * gradient,
            )
        }
    }

    private func ladder(_ count: Int, elevation: @escaping (Int) -> Double?) -> RouteGeometry {
        RouteGeometry(
            segments: [
                (0 ..< count).map { index in
                    TrackPoint(
                        latitude: Double(index) * 0.001,
                        longitude: 0,
                        elevation: elevation(index),
                        timestamp: nil,
                    )
                },
            ],
        )
    }

    @Test("A constant ten per cent slope reads ten per cent")
    func constantSlopeReadsItsGradient() throws {
        let grade = try #require(GradeWindow.grade(at: 1000, in: [run(count: 180)]))

        #expect(abs(grade - 0.1) < 0.000001)
    }

    @Test("A flat run reads zero rather than nothing")
    func flatRunReadsZero() throws {
        let grade = try #require(GradeWindow.grade(at: 1000, in: [run(count: 180, gradient: 0)]))

        #expect(grade == 0)
    }

    @Test("A window that would run off either end of the route is suppressed")
    func windowOffTheEndsIsSuppressed() {
        let samples = run(count: 180)
        let total = samples.last?.distanceMetres ?? 0

        #expect(GradeWindow.grade(at: 25, in: [samples]) == nil)
        #expect(GradeWindow.grade(at: total - 25, in: [samples]) == nil)
        #expect(GradeWindow.grade(at: GradeWindow.windowMetres / 2, in: [samples]) != nil)
    }

    @Test("A window that would cross a gap between runs is suppressed")
    func windowAcrossAGapIsSuppressed() {
        let runs = [run(count: 10), run(count: 10, from: 1500)]

        #expect(GradeWindow.grade(at: 1000, in: runs) == nil)
        #expect(GradeWindow.grade(at: 500, in: runs) != nil)
    }

    @Test("A gap inside one segment splits the profile into separate runs")
    func gapInsideASegmentSplitsRuns() {
        let geometry = ladder(9) { index in index == 4 ? nil : 100 + Double(index) * 10 }
        let runs = ElevationProfile.runs(from: geometry)
        let points = ElevationProfile.points(from: geometry)

        #expect(runs.count == 2)
        #expect(runs.map(\.count) == [4, 4])
        #expect(Set(points.map(\.run)) == [0, 1])
    }

    @Test("Two track segments never share a run, so the chart cannot join them")
    func segmentsNeverShareARun() {
        let segment = (0 ..< 4).map { index in
            TrackPoint(latitude: Double(index) * 0.001, longitude: 0, elevation: 100, timestamp: nil)
        }
        let runs = ElevationProfile.runs(from: RouteGeometry(segments: [segment, segment]))

        #expect(runs.count == 2)
    }

    @Test("A complete route is a single run")
    func completeRouteIsOneRun() async throws {
        let url = try #require(Bundle.module.url(forResource: "wikiloc-mt-agung", withExtension: "gpx"))
        let runs = try await ElevationProfile.runs(from: GPXParser.geometry(Data(contentsOf: url)))

        #expect(runs.count == 1)
        #expect(runs.first?.count == 256)
    }

    @Test("A position resolves to the coordinate the route actually has there")
    func positionResolvesToTheRouteCoordinate() throws {
        let geometry = ladder(180) { _ in 100 }
        let start = try #require(RoutePosition.coordinate(at: 0, in: geometry))
        let midpoint = try #require(RoutePosition.coordinate(at: 5000, in: geometry))

        #expect(start.latitude == 0)
        #expect(abs(midpoint.latitude - 0.04496601818622689) < 0.000001)
        #expect(midpoint.longitude == 0)
    }

    @Test("A position past the end of the route resolves to nothing")
    func positionPastTheEndResolvesToNothing() {
        let geometry = ladder(10) { _ in 100 }

        #expect(RoutePosition.coordinate(at: 99999, in: geometry) == nil)
        #expect(RoutePosition.elevation(at: 99999, in: geometry) == nil)
    }

    @Test("Elevation at a position interpolates between the samples around it")
    func elevationInterpolates() throws {
        let geometry = ladder(180) { index in 100 + Double(index) * 4 }
        let elevation = try #require(RoutePosition.elevation(at: 5000, in: geometry))

        #expect(abs(elevation - 279.86407274490756) < 0.000001)
    }
}
