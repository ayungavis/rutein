import SwiftUI

public struct RouteRowView: View {
    private let route: StoredRoute
    private let distance: String
    private let ascent: String?
    private let planDuration: String?
    private let onOpen: () -> Void
    private let onRename: () -> Void
    private let onDelete: () -> Void

    public init(
        route: StoredRoute,
        distance: String,
        ascent: String?,
        planDuration: String?,
        onOpen: @escaping () -> Void,
        onRename: @escaping () -> Void,
        onDelete: @escaping () -> Void,
    ) {
        self.route = route
        self.distance = distance
        self.ascent = ascent
        self.planDuration = planDuration
        self.onOpen = onOpen
        self.onRename = onRename
        self.onDelete = onDelete
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Spacing.xl) {
            Button(action: onOpen) {
                HStack(alignment: .top, spacing: Spacing.xl) {
                    RouteThumbnailView(outline: route.outline)

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(verbatim: route.name)
                            .font(AppFont.headline)
                            .foregroundStyle(AppColor.textPrimary)

                        metrics
                            .font(AppFont.subheadline)
                            .foregroundStyle(AppColor.textSecondary)

                        planStatus
                            .font(AppFont.footnote)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            menu
        }
    }

    @ViewBuilder
    private var metrics: some View {
        if let ascent {
            Text("library.row.metrics \(distance) \(ascent)", bundle: .module)
        } else {
            Text("library.row.metrics.unavailable \(distance)", bundle: .module)
        }
    }

    @ViewBuilder
    private var planStatus: some View {
        if let planDuration {
            Text("library.row.plan \(planDuration)", bundle: .module)
        } else {
            Text("library.row.plan.none", bundle: .module)
        }
    }

    private var menu: some View {
        Menu {
            Button(action: onRename) {
                Text("library.rename.action", bundle: .module)
            }

            Button(role: .destructive, action: onDelete) {
                Text("library.delete.action", bundle: .module)
            }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundStyle(AppColor.textPrimary)
                .frame(width: Spacing.xl4, height: Spacing.xl4)
                .contentShape(.rect)
        }
        .accessibilityLabel(Text("library.row.menu", bundle: .module))
    }
}

#Preview {
    RouteRowView(
        route: StoredRoute(
            id: UUID(),
            name: "Cascade Falls Trail",
            summary: RouteSummary(
                distanceMetres: 12437,
                elevationCoverage: .complete,
                ascentMetres: 680,
                descentMetres: 680,
                minimumElevationMetres: 100,
                maximumElevationMetres: 780,
            ),
            outline: (0 ..< 40).map { step in
                RouteOutlinePoint(
                    latitude: -8.3635 + Double(step) * 0.0006,
                    longitude: 115.4612 + sin(Double(step) / 6) * 0.01,
                )
            },
            fingerprint: "preview",
            updatedAt: .now,
        ),
        distance: "12.4 km",
        ascent: "+680 m",
        planDuration: "3 hr, 15 min",
        onOpen: {},
        onRename: {},
        onDelete: {},
    )
    .padding()
    .background(AppColor.bgBrandPrimary)
    .preferredColorScheme(.light)
}
