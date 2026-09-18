import Foundation

public enum GradeWindow {
    public static let windowMetres = 100.0

    public static func grade(
        at distanceMetres: Double,
        in runs: [[ElevationSample]],
    ) -> Double? {
        let half = windowMetres / 2
        let start = distanceMetres - half
        let end = distanceMetres + half

        guard let run = runs.first(where: { candidate in
            guard let first = candidate.first, let last = candidate.last else {
                return false
            }

            return first.distanceMetres <= start && last.distanceMetres >= end
        }) else {
            return nil
        }

        guard let low = elevation(at: start, in: run), let high = elevation(at: end, in: run) else {
            return nil
        }

        return (high - low) / windowMetres
    }

    private static func elevation(at distanceMetres: Double, in run: [ElevationSample]) -> Double? {
        guard run.count > 1 else {
            return nil
        }

        for index in run.indices.dropFirst() {
            let start = run[index - 1]
            let end = run[index]

            guard end.distanceMetres >= distanceMetres else {
                continue
            }

            let span = end.distanceMetres - start.distanceMetres

            guard span > 0 else {
                return start.elevationMetres
            }

            let along = (distanceMetres - start.distanceMetres) / span

            return start.elevationMetres + (end.elevationMetres - start.elevationMetres) * along
        }

        return run.last?.elevationMetres
    }
}
