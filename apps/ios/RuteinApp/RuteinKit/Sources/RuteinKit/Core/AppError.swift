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

    public var category: String {
        switch self {
        case .access: "access"
        case .format: "format"
        case .geometry: "geometry"
        case .capacity: "capacity"
        case .dataQuality: "dataQuality"
        case .storage: "storage"
        case .rendering: "rendering"
        case .export: "export"
        case .cancelled: "cancelled"
        }
    }
}
