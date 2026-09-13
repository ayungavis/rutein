import Foundation

enum ElevationAnalysis {
    static let reversalThresholdMetres = 3.0

    struct Result: Equatable {
        let coverage: ElevationCoverage
        let ascentMetres: Double?
        let descentMetres: Double?
        let minimumMetres: Double?
        let maximumMetres: Double?
    }

    struct TrendAccumulator {
        private(set) var ascent = 0.0
        private(set) var descent = 0.0

        private var pivot: Double
        private var candidate: Double
        private var direction = 0

        init(start: Double) {
            pivot = start
            candidate = start
        }

        mutating func add(_ value: Double) {
            switch direction {
            case 1: climb(towards: value)
            case -1: descend(towards: value)
            default: settle(towards: value)
            }
        }

        mutating func flush() {
            if direction == 1 {
                ascent += candidate - pivot
            } else if direction == -1 {
                descent += pivot - candidate
            }
        }

        private mutating func climb(towards value: Double) {
            if value > candidate {
                candidate = value
            } else if candidate - value >= reversalThresholdMetres {
                ascent += candidate - pivot
                pivot = candidate
                candidate = value
                direction = -1
            }
        }

        private mutating func descend(towards value: Double) {
            if value < candidate {
                candidate = value
            } else if value - candidate >= reversalThresholdMetres {
                descent += pivot - candidate
                pivot = candidate
                candidate = value
                direction = 1
            }
        }

        private mutating func settle(towards value: Double) {
            if value - pivot >= reversalThresholdMetres {
                direction = 1
                candidate = value
            } else if pivot - value >= reversalThresholdMetres {
                direction = -1
                candidate = value
            } else if abs(value - pivot) > abs(candidate - pivot) {
                candidate = value
            }
        }
    }

    static func of(_ geometry: RouteGeometry) -> Result {
        let points = geometry.segments.flatMap(\.self)
        let samples = points.compactMap(\.elevation)

        guard !samples.isEmpty else {
            return Result(
                coverage: .unavailable,
                ascentMetres: nil,
                descentMetres: nil,
                minimumMetres: nil,
                maximumMetres: nil,
            )
        }

        var ascent = 0.0
        var descent = 0.0

        for segment in geometry.segments {
            for run in completeRuns(in: segment) {
                var accumulator = TrendAccumulator(start: run[0])

                for value in medianFiltered(run).dropFirst() {
                    accumulator.add(value)
                }

                accumulator.flush()
                ascent += accumulator.ascent
                descent += accumulator.descent
            }
        }

        return Result(
            coverage: samples.count == points.count ? .complete : .partial,
            ascentMetres: ascent,
            descentMetres: descent,
            minimumMetres: samples.min(),
            maximumMetres: samples.max(),
        )
    }

    private static func completeRuns(in segment: [TrackPoint]) -> [[Double]] {
        var runs: [[Double]] = []
        var current: [Double] = []

        for point in segment {
            if let elevation = point.elevation {
                current.append(elevation)
            } else if !current.isEmpty {
                runs.append(current)
                current = []
            }
        }

        if !current.isEmpty {
            runs.append(current)
        }

        return runs.filter { $0.count >= 2 }
    }

    private static func medianFiltered(_ values: [Double]) -> [Double] {
        guard values.count >= 3 else { return values }

        var filtered = [values[0]]

        for index in 1 ..< values.count - 1 {
            filtered.append([values[index - 1], values[index], values[index + 1]].sorted()[1])
        }

        filtered.append(values[values.count - 1])
        return filtered
    }
}
