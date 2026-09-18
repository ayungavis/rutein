import Foundation
import SwiftData
import Testing
@testable import RuteinKit

@Suite("RouteMigration", .serialized)
struct RouteMigrationTests {
    private func summary() -> RouteSummary {
        RouteSummary(
            distanceMetres: 12437.447,
            elevationCoverage: .complete,
            ascentMetres: 1872.429,
            descentMetres: 1779.873,
            minimumElevationMetres: 1205.135,
            maximumElevationMetres: 3070.767,
        )
    }

    @Test("A version 1 store opens as version 2 with its routes intact and no plan")
    func versionOneStoreMigratesForward() async {
        await #expect(processExitsWith: .success) {
            let url = URL.temporaryDirectory.appending(path: "rutein-migration-\(UUID().uuidString).store")
            let identifier = UUID()

            defer { try? FileManager.default.removeItem(at: url) }

            let writing = try ModelContext(
                ModelContainer(
                    for: Schema(versionedSchema: RouteSchemaV1.self),
                    configurations: ModelConfiguration(url: url),
                ),
            )

            writing.insert(
                RouteSchemaV1.SavedRoute(
                    identifier: identifier,
                    name: "Agung Summit",
                    fingerprint: "abc",
                    fileName: "\(identifier.uuidString).gpx",
                    updatedAt: Date(timeIntervalSince1970: 1_758_000_000),
                    summary: RouteSummary(
                        distanceMetres: 12437.447,
                        elevationCoverage: .complete,
                        ascentMetres: 1872.429,
                        descentMetres: 1779.873,
                        minimumElevationMetres: 1205.135,
                        maximumElevationMetres: 3070.767,
                    ),
                    outline: [RouteOutlinePoint(latitude: -8.36, longitude: 115.46)],
                ),
            )

            try writing.save()

            let reading = try ModelContext(
                ModelContainer(
                    for: RouteSchemaV3.SavedRoute.self,
                    migrationPlan: RouteMigrationPlan.self,
                    configurations: ModelConfiguration(url: url),
                ),
            )
            let migrated = try reading.fetch(FetchDescriptor<RouteSchemaV3.SavedRoute>())

            precondition(migrated.count == 1)
            precondition(migrated[0].identifier == identifier)
            precondition(migrated[0].name == "Agung Summit")
            precondition(abs(migrated[0].distanceMetres - 12437.447) < 0.001)
            precondition(migrated[0].outline.count == 1)
            precondition(migrated[0].plan == nil)
            precondition(migrated[0].elevationCoverage == .complete)
        }
    }

    @Test("Every version hop the app has shipped is declared")
    func migrationPlanCoversEveryVersion() {
        #expect(RouteMigrationPlan.schemas.count == 3)
        #expect(RouteMigrationPlan.stages.count == 2)
        #expect(RouteSchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
        #expect(RouteSchemaV2.versionIdentifier == Schema.Version(2, 0, 0))
        #expect(RouteSchemaV3.versionIdentifier == Schema.Version(3, 0, 0))
    }

    @Test("A plan written through the current version reopens with every field")
    func planPersistsAcrossReopen() throws {
        let url = URL.temporaryDirectory.appending(path: "rutein-plan-\(UUID().uuidString).store")
        let identifier = UUID()
        let plan = try RoutePlan(
            targetDurationSeconds: 18000,
            startInstant: Date(timeIntervalSince1970: 1_758_000_000),
            timeZoneIdentifier: "Asia/Makassar",
            drinkIntervalMinutes: 30,
            fuelIntervalMinutes: 45,
        )

        defer { try? FileManager.default.removeItem(at: url) }

        let first = try ModelContainer(
            for: RouteSchemaV3.SavedRoute.self,
            migrationPlan: RouteMigrationPlan.self,
            configurations: ModelConfiguration(url: url),
        )
        let writing = ModelContext(first)

        writing.insert(
            RouteSchemaV3.SavedRoute(
                identifier: identifier,
                name: "Agung Summit",
                fingerprint: "abc",
                fileName: "\(identifier.uuidString).gpx",
                updatedAt: .now,
                summary: summary(),
                outline: [],
                plan: plan,
            ),
        )

        try writing.save()

        let second = try ModelContainer(
            for: RouteSchemaV3.SavedRoute.self,
            migrationPlan: RouteMigrationPlan.self,
            configurations: ModelConfiguration(url: url),
        )
        let reopened = try ModelContext(second)
            .fetch(FetchDescriptor<RouteSchemaV3.SavedRoute>())
            .first?
            .plan

        #expect(reopened == plan)
        #expect(reopened?.timeZoneIdentifier == "Asia/Makassar")
        #expect(reopened?.drinkIntervalMinutes == 30)
    }
}
