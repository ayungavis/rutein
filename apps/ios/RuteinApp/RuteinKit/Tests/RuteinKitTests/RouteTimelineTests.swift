import Foundation
import Testing
@testable import RuteinKit

@Suite("RouteTimeline")
struct RouteTimelineTests {
    private func checkpoint(_ name: String?, at distance: Double, generated: Bool = false) -> Checkpoint {
        Checkpoint(
            id: 0,
            name: name,
            distanceMetres: distance,
            elevationMetres: nil,
            origin: generated ? .distanceMarker : .waypoint,
            elevationSource: .unavailable,
        )
    }

    private func events(
        seconds: Double = 5 * 3600,
        drink: Int? = nil,
        fuel: Int? = nil,
        checkpoints: [Checkpoint] = [],
        total: Double = 20000,
    ) throws -> [TimelineEvent] {
        try RouteTimeline.events(
            for: RoutePlan(
                targetDurationSeconds: seconds,
                drinkIntervalMinutes: drink,
                fuelIntervalMinutes: fuel,
            ),
            checkpoints: checkpoints,
            totalDistanceMetres: total,
        )
    }

    @Test("A five-hour target with a 30-minute drink interval gives nine entries, minute 30 to 270")
    func drinkIntervalMatchesTheStatedCount() throws {
        let drinks = try events(drink: 30).filter { $0.kind == .drink }

        #expect(drinks.count == 9)
        #expect(drinks.map { $0.elapsedSeconds / 60 } == [30, 60, 90, 120, 150, 180, 210, 240, 270])
    }

    @Test("A 45-minute fuel interval for the same target gives six entries, ending at minute 270")
    func fuelIntervalMatchesTheStatedCount() throws {
        let fuel = try events(fuel: 45).filter { $0.kind == .fuel }

        #expect(fuel.count == 6)
        #expect(fuel.last?.elapsedSeconds == Double(270 * 60))
    }

    @Test("Intervals left off produce no drink or fuel entries anywhere")
    func intervalsOffProduceNothing() throws {
        let timeline = try events()

        #expect(timeline.allSatisfy { $0.kind != .drink && $0.kind != .fuel })
        #expect(timeline.map(\.kind) == [.start, .finish])
    }

    @Test("Offsets never decrease and Finish equals the target exactly")
    func offsetsAreNondecreasingAndFinishIsExact() throws {
        let timeline = try events(
            drink: 30,
            fuel: 45,
            checkpoints: [checkpoint("Water point", at: 5000), checkpoint("Saddle", at: 14000)],
        )
        let offsets = timeline.map(\.elapsedSeconds)

        #expect(offsets == offsets.sorted())
        #expect(timeline.last?.kind == .finish)
        #expect(timeline.last?.elapsedSeconds == Double(5 * 3600))
    }

    @Test("Two events at the same instant are both kept and stay distinguishable")
    func simultaneousEventsAreGroupedNotDropped() throws {
        let timeline = try events(drink: 30, fuel: 30)
        let atThirtyMinutes = timeline.filter { $0.elapsedSeconds == 1800 }

        #expect(atThirtyMinutes.count == 2)
        #expect(Set(atThirtyMinutes.map(\.kind)) == [.drink, .fuel])
        #expect(Set(atThirtyMinutes.map(\.id)).count == 2)
    }

    @Test("A GPX checkpoint keeps its provenance; a generated marker keeps its own")
    func provenanceIsPreserved() throws {
        let timeline = try events(
            checkpoints: [checkpoint("Water point", at: 5000), checkpoint(nil, at: 10000, generated: true)],
        )

        #expect(timeline.map(\.kind) == [.start, .checkpoint, .distanceMarker, .finish])
        #expect(timeline[1].name == "Water point")
        #expect(timeline[2].name == nil)
    }

    @Test("A checkpoint's elapsed estimate is the distance ratio of the target")
    func checkpointElapsedIsTheDistanceRatio() throws {
        let timeline = try events(checkpoints: [checkpoint("Water point", at: 5000)])

        #expect(timeline[1].elapsedSeconds == 4500)
        #expect(timeline[1].distanceMetres == 5000)
    }

    @Test("Every event carries a unique identity even across kinds")
    func identitiesAreUnique() throws {
        let timeline = try events(drink: 30, fuel: 30, checkpoints: [checkpoint("Water point", at: 5000)])

        #expect(Set(timeline.map(\.id)).count == timeline.count)
    }
}
