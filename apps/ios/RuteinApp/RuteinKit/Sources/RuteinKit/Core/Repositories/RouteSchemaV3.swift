import Foundation
import SwiftData

public enum RouteSchemaV3: VersionedSchema {
    public static var versionIdentifier: Schema.Version {
        Schema.Version(3, 0, 0)
    }

    public static var models: [any PersistentModel.Type] {
        [SavedRoute.self]
    }

    @Model
    public final class SavedRoute {
        public var identifier: UUID = UUID()
        public var name: String = ""
        public var fingerprint: String = ""
        public var fileName: String = ""
        public var updatedAt: Date = Date.distantPast
        public var distanceMetres: Double = 0
        public var elevationCoverage: ElevationCoverage = ElevationCoverage.unavailable
        public var ascentMetres: Double?
        public var descentMetres: Double?
        public var minimumElevationMetres: Double?
        public var maximumElevationMetres: Double?
        public var outline: [RouteOutlinePoint] = []
        public var plan: RoutePlan?
        public var source: RouteSource?

        public init(
            identifier: UUID,
            name: String,
            fingerprint: String,
            fileName: String,
            updatedAt: Date,
            summary: RouteSummary,
            outline: [RouteOutlinePoint],
            plan: RoutePlan? = nil,
            source: RouteSource? = nil,
        ) {
            self.identifier = identifier
            self.name = name
            self.fingerprint = fingerprint
            self.fileName = fileName
            self.updatedAt = updatedAt
            distanceMetres = summary.distanceMetres
            elevationCoverage = summary.elevationCoverage
            ascentMetres = summary.ascentMetres
            descentMetres = summary.descentMetres
            minimumElevationMetres = summary.minimumElevationMetres
            maximumElevationMetres = summary.maximumElevationMetres
            self.outline = outline
            self.plan = plan
            self.source = source
        }

        public var summary: RouteSummary {
            RouteSummary(
                distanceMetres: distanceMetres,
                elevationCoverage: elevationCoverage,
                ascentMetres: ascentMetres,
                descentMetres: descentMetres,
                minimumElevationMetres: minimumElevationMetres,
                maximumElevationMetres: maximumElevationMetres,
            )
        }

        public var stored: StoredRoute {
            StoredRoute(
                id: identifier,
                name: name,
                summary: summary,
                outline: outline,
                fingerprint: fingerprint,
                updatedAt: updatedAt,
                plan: plan,
                source: source,
            )
        }
    }
}
