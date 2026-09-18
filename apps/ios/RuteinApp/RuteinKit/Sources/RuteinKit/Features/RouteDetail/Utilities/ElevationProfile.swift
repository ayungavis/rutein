import Foundation

public struct ElevationSample: Sendable, Equatable {
    public let distanceMetres: Double
    public let elevationMetres: Double
}

public struct ElevationProfilePoint: Identifiable, Sendable, Equatable {
    public let id: Int
    public let run: Int
    public let distanceKilometres: Double
    public let elevationMetres: Double
}

public enum ElevationProfile {
    public static let sampleBudget = 400

    public static func runs(from geometry: RouteGeometry) -> [[ElevationSample]] {
        var travelled = 0.0
        var runs: [[ElevationSample]] = []
        var current: [ElevationSample] = []

        for segment in geometry.segments {
            for index in segment.indices {
                if index > 0 {
                    travelled += Haversine.metres(from: segment[index - 1], to: segment[index])
                }

                guard let elevation = segment[index].elevation else {
                    runs.append(current)
                    current = []
                    continue
                }

                current.append(
                    ElevationSample(distanceMetres: travelled, elevationMetres: elevation),
                )
            }

            runs.append(current)
            current = []
        }

        return runs.filter { !$0.isEmpty }
    }

    public static func points(from geometry: RouteGeometry) -> [ElevationProfilePoint] {
        let runs = runs(from: geometry)
        let total = runs.reduce(0) { $0 + $1.count }

        guard total > 1 else {
            return []
        }

        var identifier = 0

        return runs.enumerated().flatMap { index, run in
            thin(run, budget: budget(for: run.count, of: total)).map { sample in
                defer { identifier += 1 }

                return ElevationProfilePoint(
                    id: identifier,
                    run: index,
                    distanceKilometres: sample.distanceMetres / 1000,
                    elevationMetres: sample.elevationMetres,
                )
            }
        }
    }

    private static func budget(for count: Int, of total: Int) -> Int {
        guard total > sampleBudget else {
            return count
        }

        let share = Double(count) / Double(total) * Double(sampleBudget)

        return max(2, Int(share.rounded()))
    }

    private static func thin(_ samples: [ElevationSample], budget: Int) -> [ElevationSample] {
        guard samples.count > budget, budget > 1 else {
            return samples
        }

        let stride = Double(samples.count - 1) / Double(budget - 1)

        return (0 ..< budget).map { step in
            samples[min(samples.count - 1, Int((Double(step) * stride).rounded()))]
        }
    }
}
