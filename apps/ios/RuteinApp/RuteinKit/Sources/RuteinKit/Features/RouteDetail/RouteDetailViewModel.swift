import Foundation
import MapKit
import Observation
import SwiftUI

@MainActor
public struct RouteMetric: Identifiable {
    public let id: String
    public let label: LocalizedStringKey
    public let value: String
}

@MainActor
public struct KeyClimb {
    public let start: String
    public let end: String
    public let gain: String
    public let grade: String
}

@MainActor
@Observable
public final class RouteDetailViewModel {
    private let routes: any RouteRepository
    private let data: Data?

    public let route: ImportedRoute
    public let profilePoints: [ElevationProfilePoint]
    public let profileRuns: [[ElevationSample]]
    public let mapCoordinates: [CLLocationCoordinate2D]
    public let mapRegion: MKCoordinateRegion?
    public let checkpoints: CheckpointSet
    public let sustainedClimb: SustainedClimb?

    public private(set) var saveState: Loadable<StoredRoute> = .idle
    public private(set) var isSaved: Bool
    public private(set) var savedPlan: RoutePlan?
    public var selectedKilometres: Double?

    public init(opened: OpenedRoute, routes: any RouteRepository) {
        self.routes = routes
        data = opened.data
        isSaved = opened.isSaved
        savedPlan = opened.plan
        route = opened.route
        profilePoints = ElevationProfile.points(from: route.geometry)
        profileRuns = ElevationProfile.runs(from: route.geometry)
        mapCoordinates = RouteRegion.coordinates(from: route.geometry)
        mapRegion = RouteRegion.region(fitting: mapCoordinates)
        sustainedClimb = ClimbDetection.keyClimb(in: route.geometry)
        checkpoints = CheckpointAssociation.checkpoints(
            in: route.geometry,
            totalDistanceMetres: route.summary.distanceMetres,
        )
    }

    public var name: String {
        route.name
    }

    public var planSummary: [RouteMetric] {
        guard let plan = savedPlan else { return [] }

        var entries = [
            RouteMetric(
                id: "target",
                label: "detail.plan.target",
                value: RouteFormat.duration(plan.targetDurationSeconds),
            ),
        ]

        if let pace = plan.averagePaceSecondsPerKilometre(over: route.summary.distanceMetres) {
            entries.append(
                RouteMetric(
                    id: "pace",
                    label: "detail.plan.pace",
                    value: RouteFormat.pace(secondsPerKilometre: pace),
                ),
            )
        }

        if let instant = plan.startInstant, let zone = plan.timeZone {
            entries.append(
                RouteMetric(
                    id: "start",
                    label: "detail.plan.start",
                    value: RouteFormat.arrival(instant, in: zone),
                ),
            )
        }

        for (id, label, minutes) in [
            ("drink", LocalizedStringKey("detail.plan.drink"), plan.drinkIntervalMinutes),
            ("fuel", LocalizedStringKey("detail.plan.fuel"), plan.fuelIntervalMinutes),
        ] {
            guard let minutes else { continue }

            entries.append(
                RouteMetric(
                    id: id,
                    label: label,
                    value: RouteFormat.duration(Double(minutes) * 60),
                ),
            )
        }

        return entries
    }

    public var opened: OpenedRoute {
        OpenedRoute(route: route, data: data, isSaved: isSaved, plan: savedPlan)
    }

    public var isSaving: Bool {
        if case .loading = saveState {
            return true
        }

        return false
    }

    public var canSave: Bool {
        !isSaved && data != nil
    }

    public var saveFailure: LocalizedStringKey? {
        guard case let .failed(error, _) = saveState else { return nil }

        return error == .dataQuality ? "detail.save.invalidName" : "detail.save.failed"
    }

    public func dismissSaveFailure() {
        saveState = .idle
    }

    public func save() async {
        guard let data, !isSaved else { return }

        saveState = .loading(previous: saveState.value)

        do {
            saveState = try await .loaded(routes.save(ImportedFile(route: route, data: data)))
            isSaved = true
        } catch let error as AppError {
            Log.report(error)
            saveState = .failed(error, previous: saveState.value)
        } catch {
            Log.report(AppError.storage)
            saveState = .failed(.storage, previous: saveState.value)
        }
    }

    public var metrics: [RouteMetric] {
        var entries = [
            RouteMetric(
                id: "distance",
                label: "detail.metric.distance",
                value: RouteFormat.distance(route.summary.distanceMetres),
            ),
        ]

        if let ascent = route.summary.ascentMetres {
            entries.append(
                RouteMetric(
                    id: "ascent",
                    label: "detail.metric.ascent",
                    value: RouteFormat.signedElevation(ascent),
                ),
            )
        }

        if let descent = route.summary.descentMetres {
            entries.append(
                RouteMetric(
                    id: "descent",
                    label: "detail.metric.descent",
                    value: RouteFormat.signedElevation(-descent),
                ),
            )
        }

        if let lowest = route.summary.minimumElevationMetres {
            entries.append(
                RouteMetric(
                    id: "lowest",
                    label: "detail.metric.lowest",
                    value: RouteFormat.elevation(lowest),
                ),
            )
        }

        if let highest = route.summary.maximumElevationMetres {
            entries.append(
                RouteMetric(
                    id: "highest",
                    label: "detail.metric.highest",
                    value: RouteFormat.elevation(highest),
                ),
            )
        }

        return entries
    }

    public var keyClimb: KeyClimb? {
        sustainedClimb.map { climb in
            KeyClimb(
                start: RouteFormat.kilometreMark(climb.startMetres),
                end: RouteFormat.kilometreMark(climb.endMetres),
                gain: RouteFormat.signedElevation(climb.gainMetres),
                grade: RouteFormat.grade(climb.grade),
            )
        }
    }

    public var mapMetrics: [RouteMetric] {
        metrics.filter { ["distance", "ascent"].contains($0.id) } + [
            RouteMetric(
                id: "checkpoints",
                label: checkpoints.usesDistanceMarkers
                    ? "detail.metric.markers"
                    : "detail.metric.checkpoints",
                value: checkpoints.checkpoints.count.formatted(),
            ),
        ]
    }

    public var profileSummary: String {
        [
            route.summary.minimumElevationMetres,
            route.summary.maximumElevationMetres,
        ]
        .compactMap(\.self)
        .map { RouteFormat.elevation($0) }
        .formatted(.list(type: .and))
    }

    public var selectedMetres: Double? {
        selectedKilometres.map { $0 * 1000 }
    }

    public var selectedCoordinate: CLLocationCoordinate2D? {
        selectedMetres.flatMap { RoutePosition.coordinate(at: $0, in: route.geometry) }
    }

    public var profileReadout: String? {
        guard let metres = selectedMetres,
              let elevation = RoutePosition.elevation(at: metres, in: route.geometry)
        else {
            return nil
        }

        let distance = RouteFormat.distance(metres)
        let height = RouteFormat.elevation(elevation)

        guard let grade = GradeWindow.grade(at: metres, in: profileRuns) else {
            return String(localized: "detail.chart.readout.noGrade \(distance) \(height)", bundle: .module)
        }

        return String(
            localized: "detail.chart.readout \(distance) \(height) \(RouteFormat.grade(grade))",
            bundle: .module,
        )
    }

    public var elevationNotice: LocalizedStringKey? {
        switch route.summary.elevationCoverage {
        case .complete: nil
        case .partial: "detail.elevation.partial"
        case .unavailable: "detail.elevation.unavailable"
        }
    }
}
