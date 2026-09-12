public enum Loadable<T: Sendable>: Sendable {
    case idle
    case loading(previous: T?)
    case loaded(T)
    case failed(AppError, previous: T?)

    public var value: T? {
        switch self {
        case .idle: nil
        case let .loading(previous): previous
        case let .loaded(value): value
        case let .failed(_, previous): previous
        }
    }
}
