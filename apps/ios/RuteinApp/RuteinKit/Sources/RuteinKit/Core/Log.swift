import Foundation
import OSLog

public enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "Rutein"

    private static let app = Logger(subsystem: subsystem, category: "app")
    private static let ui = Logger(subsystem: subsystem, category: "ui")

    public static func report(_ error: AppError, operation: String = "-") {
        app.error("failure categor=\(error.category, privacy: .public) operation=\(operation, privacy: .public)")
    }
}
