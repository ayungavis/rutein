import Foundation
import Observation
import SwiftUI

@MainActor
public struct BriefRow: Identifiable {
    public let id: Int
    public let offset: String
    public let label: String
    public let name: String?
    public let detail: String
    public let isGenerated: Bool
}

@MainActor
@Observable
public final class RouteBriefViewModel {
    public static let imageRowLimit = 24

    private let routes: any RouteRepository
    private let planned: PlannedRoute
    private let checkpoints: CheckpointSet

    public private(set) var saveState: Loadable<StoredRoute> = .idle
    public private(set) var isSaved: Bool
    public var isPreviewingShare = false

    public let events: [TimelineEvent]
    public let rows: [BriefRow]

    public init(planned: PlannedRoute, routes: any RouteRepository) {
        self.planned = planned
        self.routes = routes
        isSaved = planned.opened.isSaved && planned.opened.plan == planned.plan

        let set = CheckpointAssociation.checkpoints(
            in: planned.opened.route.geometry,
            totalDistanceMetres: planned.opened.route.summary.distanceMetres,
        )

        checkpoints = set
        events = RouteTimeline.events(
            for: planned.plan,
            checkpoints: set.checkpoints,
            totalDistanceMetres: planned.opened.route.summary.distanceMetres,
        )
        rows = Self.rows(for: events, plan: planned.plan)
    }

    private static func rows(for events: [TimelineEvent], plan: RoutePlan) -> [BriefRow] {
        events.map { event in
            BriefRow(
                id: event.id,
                offset: offset(for: event, plan: plan),
                label: label(for: event),
                name: event.name,
                detail: detail(for: event),
                isGenerated: event.kind == .distanceMarker,
            )
        }
    }

    public var name: String {
        planned.opened.route.name
    }

    public var distance: String {
        RouteFormat.distance(planned.opened.route.summary.distanceMetres)
    }

    public var targetDuration: String {
        RouteFormat.duration(planned.plan.targetDurationSeconds)
    }

    public var averagePace: String {
        let pace = planned.plan.averagePaceSecondsPerKilometre(
            over: planned.opened.route.summary.distanceMetres,
        )

        return pace.map { RouteFormat.pace(secondsPerKilometre: $0) } ?? ""
    }

    public var usesDistanceMarkers: Bool {
        checkpoints.usesDistanceMarkers
    }

    public var dataQualityNote: LocalizedStringKey? {
        guard checkpoints.hasDataQualityNote else { return nil }

        return checkpoints.ambiguous.isEmpty
            ? "brief.quality.unassociated"
            : "brief.quality.ambiguous"
    }

    public var isSaving: Bool {
        if case .loading = saveState {
            return true
        }

        return false
    }

    public var saveFailure: LocalizedStringKey? {
        guard case .failed = saveState else { return nil }

        return "brief.save.failed"
    }

    public func dismissSaveFailure() {
        saveState = .idle
    }

    public func savePlan() async {
        saveState = .loading(previous: saveState.value)

        do {
            if !planned.opened.isSaved, let data = planned.opened.data {
                _ = try await routes.save(ImportedFile(route: planned.opened.route, data: data))
            }

            saveState = try await .loaded(
                routes.savePlan(planned.plan, for: planned.opened.route.id),
            )
            isSaved = true
        } catch let error as AppError {
            Log.report(error)
            saveState = .failed(error, previous: saveState.value)
        } catch {
            Log.report(AppError.storage)
            saveState = .failed(.storage, previous: saveState.value)
        }
    }

    public var canExportImage: Bool {
        rows.count <= Self.imageRowLimit
    }

    public var shareSummary: String {
        localized("brief.subhead \(distance) \(targetDuration) \(averagePace)")
    }

    public func briefImage(scale: CGFloat = 3) -> BriefImage {
        guard canExportImage else {
            return .timelineTooLong
        }

        let renderer = ImageRenderer(
            content: BriefCardView(
                name: name,
                summary: shareSummary,
                rows: rows,
                showsMarkerNotice: usesDistanceMarkers,
            ),
        )

        renderer.scale = scale

        guard let rendered = renderer.cgImage else {
            Log.report(.export)

            return .failed(.export)
        }

        return .ready(Image(decorative: rendered, scale: scale))
    }

    public var shareText: String {
        var lines = [
            name,
            localized("brief.share.summary \(distance) \(targetDuration) \(averagePace)"),
        ]

        if let elevation = elevationLine {
            lines.append(elevation)
        }

        if let start = startLine {
            lines.append(start)
        }

        lines.append(localized("brief.share.method"))

        if usesDistanceMarkers {
            lines.append(localized("brief.share.markers"))
        }

        lines.append("")
        lines.append(contentsOf: rows.map(shareLine))

        return lines.joined(separator: "\n")
    }

    private var elevationLine: String? {
        let summary = planned.opened.route.summary

        guard let ascent = summary.ascentMetres else {
            return localized("brief.share.elevation.unavailable")
        }

        let value = RouteFormat.signedElevation(ascent)

        return summary.elevationCoverage == .complete
            ? localized("brief.share.elevation \(value)")
            : localized("brief.share.elevation.partial \(value)")
    }

    private var startLine: String? {
        guard let instant = planned.plan.startInstant, let zone = planned.plan.timeZone else {
            return localized("brief.share.relative")
        }

        return localized("brief.share.start \(RouteFormat.arrival(instant, in: zone))")
    }

    private func shareLine(_ row: BriefRow) -> String {
        let label = row.name ?? row.label

        return row.detail.isEmpty
            ? localized("brief.share.row.plain \(row.offset) \(label)")
            : localized("brief.share.row \(row.offset) \(label) \(row.detail)")
    }

    private static func offset(for event: TimelineEvent, plan: RoutePlan) -> String {
        guard let instant = plan.startInstant, let zone = plan.timeZone else {
            return String(
                localized: "brief.offset \(RouteFormat.offset(event.elapsedSeconds))",
                bundle: .module,
            )
        }

        return RouteFormat.arrival(instant.addingTimeInterval(event.elapsedSeconds), in: zone)
    }

    private static func label(for event: TimelineEvent) -> String {
        switch event.kind {
        case .start: String(localized: "brief.event.start", bundle: .module)
        case .finish: String(localized: "brief.event.finish", bundle: .module)
        case .checkpoint: String(localized: "brief.event.checkpoint", bundle: .module)
        case .distanceMarker: String(localized: "brief.event.marker", bundle: .module)
        case .drink: String(localized: "brief.event.drink", bundle: .module)
        case .fuel: String(localized: "brief.event.fuel", bundle: .module)
        }
    }

    private static func detail(for event: TimelineEvent) -> String {
        [
            event.distanceMetres.map { RouteFormat.distance($0) },
            event.elevationMetres.map { RouteFormat.elevation($0) },
        ]
        .compactMap(\.self)
        .formatted(.list(type: .and))
    }

    private func localized(_ key: String.LocalizationValue) -> String {
        String(localized: key, bundle: .module)
    }
}
