public enum AppError: Error, Sendable, Equatable {
    case access
    case format
    case geometry
    case capacity
    case dataQuality
    case storage
    case rendering
    case export
    case cancelled
}
