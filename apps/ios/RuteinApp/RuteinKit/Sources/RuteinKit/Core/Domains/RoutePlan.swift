import Foundation

public struct RoutePlan: Sendable, Equatable, Codable {
    public static let durationRange = 60.0 ... 48 * 3600.0
    public static let intervalRange = 5 ... 240

    public let targetDurationSeconds: Double
    public let startInstant: Date?
    public let timeZoneIdentifier: String?
    public let drinkIntervalMinutes: Int?
    public let fuelIntervalMinutes: Int?

    public init(
        targetDurationSeconds: Double,
        startInstant: Date? = nil,
        timeZoneIdentifier: String? = nil,
        drinkIntervalMinutes: Int? = nil,
        fuelIntervalMinutes: Int? = nil,
    ) throws {
        guard Self.durationRange.contains(targetDurationSeconds) else {
            throw AppError.dataQuality
        }

        for interval in [drinkIntervalMinutes, fuelIntervalMinutes].compactMap(\.self) {
            guard Self.intervalRange.contains(interval) else {
                throw AppError.dataQuality
            }
        }

        guard (startInstant == nil) == (timeZoneIdentifier == nil) else {
            throw AppError.dataQuality
        }

        self.targetDurationSeconds = targetDurationSeconds
        self.startInstant = startInstant
        self.timeZoneIdentifier = timeZoneIdentifier
        self.drinkIntervalMinutes = drinkIntervalMinutes
        self.fuelIntervalMinutes = fuelIntervalMinutes
    }

    public var timeZone: TimeZone? {
        timeZoneIdentifier.flatMap(TimeZone.init(identifier:))
    }

    public func averagePaceSecondsPerKilometre(over distanceMetres: Double) -> Double? {
        guard distanceMetres > 0 else {
            return nil
        }

        return targetDurationSeconds / (distanceMetres / 1000)
    }

    public func elapsedSeconds(at distanceMetres: Double, over totalMetres: Double) -> Double? {
        guard totalMetres > 0 else {
            return nil
        }

        return targetDurationSeconds * distanceMetres / totalMetres
    }
}
