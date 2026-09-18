import Foundation
import Testing
@testable import RuteinKit

@Suite("RoutePlan")
struct RoutePlanTests {
    @Test("Twenty kilometres in five hours is 15:00 per kilometre")
    func twentyInFiveIsFifteenMinutePace() throws {
        let plan = try RoutePlan(targetDurationSeconds: 5 * 3600)
        let pace = try #require(plan.averagePaceSecondsPerKilometre(over: 20000))

        #expect(pace == 900)
        #expect(RouteFormat.pace(secondsPerKilometre: pace, locale: Locale(identifier: "en_US")) == "15:00")
    }

    @Test("A checkpoint at 5 km on a 20 km five-hour route lands at 1 hour 15")
    func checkpointElapsedFollowsTheRatio() throws {
        let plan = try RoutePlan(targetDurationSeconds: 5 * 3600)
        let elapsed = try #require(plan.elapsedSeconds(at: 5000, over: 20000))

        #expect(elapsed == 4500)
        #expect(RouteFormat.offset(elapsed, locale: Locale(identifier: "en_US")) == "01:15")
    }

    @Test("One minute and forty-eight hours are the accepted extremes")
    func durationBoundariesAreAccepted() throws {
        #expect(try RoutePlan(targetDurationSeconds: 60).targetDurationSeconds == 60)
        #expect(try RoutePlan(targetDurationSeconds: 48 * 3600).targetDurationSeconds == 172_800)
    }

    @Test("Zero, under a minute and over forty-eight hours are refused")
    func durationBoundariesAreRefused() {
        for seconds in [0.0, 59, 172_801, -60] {
            #expect(throws: AppError.dataQuality) {
                _ = try RoutePlan(targetDurationSeconds: seconds)
            }
        }
    }

    @Test("An interval outside 5 to 240 whole minutes is refused")
    func intervalBoundaries() throws {
        #expect(try RoutePlan(targetDurationSeconds: 3600, drinkIntervalMinutes: 5) != nil)
        #expect(try RoutePlan(targetDurationSeconds: 3600, fuelIntervalMinutes: 240) != nil)

        #expect(throws: AppError.dataQuality) {
            _ = try RoutePlan(targetDurationSeconds: 3600, drinkIntervalMinutes: 4)
        }

        #expect(throws: AppError.dataQuality) {
            _ = try RoutePlan(targetDurationSeconds: 3600, fuelIntervalMinutes: 241)
        }
    }

    @Test("A start instant without its time zone cannot be written")
    func startInstantRequiresItsZone() {
        #expect(throws: AppError.dataQuality) {
            _ = try RoutePlan(targetDurationSeconds: 3600, startInstant: .now, timeZoneIdentifier: nil)
        }

        #expect(throws: AppError.dataQuality) {
            _ = try RoutePlan(
                targetDurationSeconds: 3600,
                startInstant: nil,
                timeZoneIdentifier: "Asia/Makassar",
            )
        }
    }

    @Test("A zero-distance route yields no pace rather than an infinite one")
    func zeroDistanceYieldsNoPace() throws {
        let plan = try RoutePlan(targetDurationSeconds: 3600)

        #expect(plan.averagePaceSecondsPerKilometre(over: 0) == nil)
        #expect(plan.elapsedSeconds(at: 100, over: 0) == nil)
    }

    @Test("A plan survives a round trip through its stored form")
    func planRoundTripsThroughCoding() throws {
        let plan = try RoutePlan(
            targetDurationSeconds: 18000,
            startInstant: Date(timeIntervalSince1970: 1_758_000_000),
            timeZoneIdentifier: "Asia/Makassar",
            drinkIntervalMinutes: 30,
            fuelIntervalMinutes: 45,
        )
        let decoded = try JSONDecoder().decode(RoutePlan.self, from: JSONEncoder().encode(plan))

        #expect(decoded == plan)
        #expect(decoded.timeZone?.identifier == "Asia/Makassar")
    }
}
