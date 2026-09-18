import Foundation

public struct SustainedClimb: Sendable, Equatable {
    public let startMetres: Double
    public let endMetres: Double
    public let gainMetres: Double

    public var distanceMetres: Double {
        endMetres - startMetres
    }

    public var grade: Double {
        gainMetres / distanceMetres
    }
}

public enum ClimbDetection {
    public static let minimumDistanceMetres = 200.0
    public static let minimumGainMetres = 20.0
    public static let minimumGrade = 0.05

    public static func keyClimb(in geometry: RouteGeometry) -> SustainedClimb? {
        climbs(in: geometry).max { $0.gainMetres < $1.gainMetres }
    }

    public static func climbs(in geometry: RouteGeometry) -> [SustainedClimb] {
        ElevationProfile.runs(from: geometry).flatMap(climbs(inRun:))
    }

    private static func climbs(inRun samples: [ElevationSample]) -> [SustainedClimb] {
        guard var low = samples.first else {
            return []
        }

        var peak = low
        var found: [SustainedClimb] = []

        for sample in samples.dropFirst() {
            if sample.elevationMetres > peak.elevationMetres {
                peak = sample
            } else if peak.elevationMetres - sample.elevationMetres > minimumGainMetres {
                found.append(contentsOf: candidate(from: low, to: peak))
                low = sample
                peak = sample
            } else if sample.elevationMetres < low.elevationMetres {
                low = sample
                peak = sample
            }
        }

        found.append(contentsOf: candidate(from: low, to: peak))

        return found
    }

    private static func candidate(from low: ElevationSample, to peak: ElevationSample) -> [SustainedClimb] {
        let climb = SustainedClimb(
            startMetres: low.distanceMetres,
            endMetres: peak.distanceMetres,
            gainMetres: peak.elevationMetres - low.elevationMetres,
        )

        guard climb.distanceMetres >= minimumDistanceMetres,
              climb.gainMetres >= minimumGainMetres,
              climb.grade >= minimumGrade
        else {
            return []
        }

        return [climb]
    }
}
