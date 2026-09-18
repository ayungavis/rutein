import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
public final class RoutePlannerViewModel {
    public static let quickHours = [3, 4, 5, 6]

    public let route: ImportedRoute
    public let savedPlan: RoutePlan?

    public var hours: Int
    public var minutes: Int
    public var usesStartInstant: Bool
    public var startInstant: Date
    public var usesDrinkInterval: Bool
    public var drinkIntervalMinutes: Int
    public var usesFuelInterval: Bool
    public var fuelIntervalMinutes: Int

    public init(route: ImportedRoute, savedPlan: RoutePlan?) {
        self.route = route
        self.savedPlan = savedPlan

        let seconds = savedPlan?.targetDurationSeconds ?? 5 * 3600

        hours = Int(seconds) / 3600
        minutes = Int(seconds) % 3600 / 60
        usesStartInstant = savedPlan?.startInstant != nil
        startInstant = savedPlan?.startInstant ?? .now
        usesDrinkInterval = savedPlan?.drinkIntervalMinutes != nil
        drinkIntervalMinutes = savedPlan?.drinkIntervalMinutes ?? 30
        usesFuelInterval = savedPlan?.fuelIntervalMinutes != nil
        fuelIntervalMinutes = savedPlan?.fuelIntervalMinutes ?? 45
    }

    public var targetSeconds: Double {
        Double(hours * 3600 + minutes * 60)
    }

    public var draft: RoutePlan? {
        try? RoutePlan(
            targetDurationSeconds: targetSeconds,
            startInstant: usesStartInstant ? startInstant : nil,
            timeZoneIdentifier: usesStartInstant ? TimeZone.current.identifier : nil,
            drinkIntervalMinutes: usesDrinkInterval ? drinkIntervalMinutes : nil,
            fuelIntervalMinutes: usesFuelInterval ? fuelIntervalMinutes : nil,
        )
    }

    public var durationFailure: LocalizedStringKey? {
        RoutePlan.durationRange.contains(targetSeconds) ? nil : "plan.duration.invalid"
    }

    public var targetDuration: String {
        RouteFormat.duration(targetSeconds)
    }

    public var averagePace: String? {
        guard let pace = draft?.averagePaceSecondsPerKilometre(over: route.summary.distanceMetres) else {
            return nil
        }

        return RouteFormat.pace(secondsPerKilometre: pace)
    }

    public var paceWorking: String {
        RouteFormat.distance(route.summary.distanceMetres)
    }

    public var startZone: String {
        TimeZone.current.identifier
    }

    public func quickLabel(hours: Int) -> String {
        RouteFormat.duration(Double(hours * 3600))
    }

    public func selectQuick(hours selected: Int) {
        hours = selected
        minutes = 0
    }
}
