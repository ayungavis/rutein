import Observation

@MainActor
@Observable
public final class RouteLibraryViewModel {
    public private(set) var routes: Loadable<[RouteSummary]> = .loaded([])

    public init() {}
}
