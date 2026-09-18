import SwiftData

public enum RouteMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [RouteSchemaV1.self, RouteSchemaV2.self, RouteSchemaV3.self]
    }

    public static var stages: [MigrationStage] {
        [addPlan, addSource]
    }

    static let addPlan = MigrationStage.lightweight(
        fromVersion: RouteSchemaV1.self,
        toVersion: RouteSchemaV2.self,
    )

    static let addSource = MigrationStage.lightweight(
        fromVersion: RouteSchemaV2.self,
        toVersion: RouteSchemaV3.self,
    )
}
