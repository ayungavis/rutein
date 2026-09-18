import Foundation

@MainActor
public final class AppContainer {
    public let routes: any RouteRepository

    public init(routes: any RouteRepository) {
        self.routes = routes
    }

    public static func live() -> AppContainer {
        do {
            return try AppContainer(
                routes: SwiftDataRouteRepository(
                    container: SwiftDataRouteRepository.container(),
                    files: RouteFileStore(),
                ),
            )
        } catch {
            Log.report(AppError.storage)

            return AppContainer(routes: UnavailableRouteRepository())
        }
    }

    public static func preview() -> AppContainer {
        do {
            return try AppContainer(
                routes: SwiftDataRouteRepository(
                    container: SwiftDataRouteRepository.container(inMemory: true),
                    files: RouteFileStore(root: URL.temporaryDirectory.appending(path: UUID().uuidString)),
                ),
            )
        } catch {
            return AppContainer(routes: UnavailableRouteRepository())
        }
    }
}
