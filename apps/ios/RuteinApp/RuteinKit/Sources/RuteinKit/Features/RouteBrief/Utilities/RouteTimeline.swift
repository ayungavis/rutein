import Foundation

public enum RouteTimeline {
    public static func events(
        for plan: RoutePlan,
        checkpoints: [Checkpoint],
        totalDistanceMetres: Double,
    ) -> [TimelineEvent] {
        let start = TimelineEvent(
            id: 0,
            kind: .start,
            name: nil,
            elapsedSeconds: 0,
            distanceMetres: 0,
            elevationMetres: nil,
        )
        let finish = TimelineEvent(
            id: 0,
            kind: .finish,
            name: nil,
            elapsedSeconds: plan.targetDurationSeconds,
            distanceMetres: totalDistanceMetres,
            elevationMetres: nil,
        )

        return ordered(
            [start]
                + checkpointEvents(plan, checkpoints, totalDistanceMetres)
                + intervalEvents(.drink, every: plan.drinkIntervalMinutes, within: plan)
                + intervalEvents(.fuel, every: plan.fuelIntervalMinutes, within: plan)
                + [finish],
        )
    }

    private static func checkpointEvents(
        _ plan: RoutePlan,
        _ checkpoints: [Checkpoint],
        _ totalDistanceMetres: Double,
    ) -> [TimelineEvent] {
        checkpoints.compactMap { checkpoint in
            guard let elapsed = plan.elapsedSeconds(
                at: checkpoint.distanceMetres,
                over: totalDistanceMetres,
            ) else {
                return nil
            }

            return TimelineEvent(
                id: 0,
                kind: checkpoint.origin == .waypoint ? .checkpoint : .distanceMarker,
                name: checkpoint.name,
                elapsedSeconds: elapsed,
                distanceMetres: checkpoint.distanceMetres,
                elevationMetres: checkpoint.elevationMetres,
            )
        }
    }

    private static func intervalEvents(
        _ kind: TimelineEventKind,
        every minutes: Int?,
        within plan: RoutePlan,
    ) -> [TimelineEvent] {
        guard let minutes, minutes > 0 else {
            return []
        }

        let step = Double(minutes) * 60

        return stride(from: step, to: plan.targetDurationSeconds, by: step).map { elapsed in
            TimelineEvent(
                id: 0,
                kind: kind,
                name: nil,
                elapsedSeconds: elapsed,
                distanceMetres: nil,
                elevationMetres: nil,
            )
        }
    }

    private static func ordered(_ events: [TimelineEvent]) -> [TimelineEvent] {
        events
            .enumerated()
            .sorted { left, right in
                if left.element.elapsedSeconds != right.element.elapsedSeconds {
                    return left.element.elapsedSeconds < right.element.elapsedSeconds
                }

                if left.element.kind.rank != right.element.kind.rank {
                    return left.element.kind.rank < right.element.kind.rank
                }

                return left.offset < right.offset
            }
            .enumerated()
            .map { position, entry in
                TimelineEvent(
                    id: position,
                    kind: entry.element.kind,
                    name: entry.element.name,
                    elapsedSeconds: entry.element.elapsedSeconds,
                    distanceMetres: entry.element.distanceMetres,
                    elevationMetres: entry.element.elevationMetres,
                )
            }
    }
}
