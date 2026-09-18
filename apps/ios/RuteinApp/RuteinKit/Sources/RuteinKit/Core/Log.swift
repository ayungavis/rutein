import Foundation
import OSLog

public enum LogStage: String, Sendable {
    case importing
    case parsing
    case analysis
    case persistence
    case rendering
    case export

    var isInterface: Bool {
        self == .rendering || self == .export
    }
}

public enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "Rutein"

    private static let app = Logger(subsystem: subsystem, category: "app")
    private static let ui = Logger(subsystem: subsystem, category: "ui")
    private static let signposter = OSSignposter(subsystem: subsystem, category: "stage")

    public static func newOperationID() -> String {
        String(format: "%08x", UInt32.random(in: .min ... .max))
    }

    public static func measure<T>(
        _ stage: LogStage,
        count: Int = 0,
        operation: String = newOperationID(),
        isolation: isolated (any Actor)? = #isolation,
        _ work: () async throws -> T,
    ) async rethrows -> T {
        let interval = signposter.beginInterval("stage", id: signposter.makeSignpostID())
        let started = ContinuousClock.now

        do {
            let value = try await work()

            signposter.endInterval("stage", interval)
            emit(stage, operation: operation, count: count, outcome: "ok", since: started)

            return value
        } catch {
            signposter.endInterval("stage", interval)
            emit(
                stage,
                operation: operation,
                count: count,
                outcome: (error as? AppError)?.category ?? "unknown",
                since: started,
            )

            throw error
        }
    }

    public static func note(_ event: String, count: Int) {
        app.info("event=\(event, privacy: .public) count=\(count, privacy: .public)")
    }

    public static func report(_ error: AppError, operation: String = "-") {
        app.error("failure categor=\(error.category, privacy: .public) operation=\(operation, privacy: .public)")
    }

    private static func emit(
        _ stage: LogStage,
        operation: String,
        count: Int,
        outcome: String,
        since started: ContinuousClock.Instant,
    ) {
        let milliseconds = (ContinuousClock.now - started).components.attoseconds / 1_000_000_000_000_000

        (stage.isInterface ? ui : app).info(
            """
            stage=\(stage.rawValue, privacy: .public) \
            operation=\(operation, privacy: .public) \
            count=\(count, privacy: .public) \
            outcome=\(outcome, privacy: .public) \
            ms=\(milliseconds, privacy: .public)
            """,
        )
    }
}
