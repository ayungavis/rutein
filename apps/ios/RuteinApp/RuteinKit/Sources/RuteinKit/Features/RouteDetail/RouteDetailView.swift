import SwiftUI

public struct RouteDetailView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var viewModel: RouteDetailViewModel
    @State private var isPlanning = false

    private let container: AppContainer

    public init(opened: OpenedRoute, container: AppContainer) {
        self.container = container
        _viewModel = State(
            initialValue: RouteDetailViewModel(opened: opened, routes: container.routes),
        )
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl3) {
                heading

                map

                elevation

                metrics

                climb

                plan

                if let notice = viewModel.elevationNotice {
                    Text(notice, bundle: .module)
                        .font(AppFont.footnote)
                        .foregroundStyle(AppColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.xl3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.bgBrandPrimary)
        .tint(AppColor.textPrimary)
        .safeAreaInset(edge: .bottom) { actions }
        .navigationDestination(isPresented: $isPlanning) {
            RoutePlannerView(opened: viewModel.opened, container: container)
        }
        .alert(
            Text("detail.save.title", bundle: .module),
            isPresented: .constant(viewModel.saveFailure != nil),
        ) {
            Button {
                viewModel.dismissSaveFailure()
            } label: {
                Text("import.failed.dismiss", bundle: .module)
            }
        } message: {
            if let failure = viewModel.saveFailure {
                Text(failure, bundle: .module)
            }
        }
    }

    private var actions: some View {
        HStack(spacing: Spacing.md) {
            if viewModel.canSave {
                Button {
                    Task { await viewModel.save() }
                } label: {
                    if viewModel.isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("detail.save.action", bundle: .module)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                .disabled(viewModel.isSaving)
            }

            Button {
                isPlanning = true
            } label: {
                Text(
                    viewModel.savedPlan == nil ? "detail.plan.action" : "detail.plan.edit",
                    bundle: .module,
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(AppColor.bgPrimary)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.xl)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(verbatim: viewModel.name)
                .font(AppFont.display)
                .foregroundStyle(AppColor.textPrimary)

            Text(viewModel.isSaved ? "detail.status.saved" : "detail.status.unsaved", bundle: .module)
                .font(AppFont.subheadline)
                .foregroundStyle(AppColor.textSecondary)
        }
    }

    @ViewBuilder
    private var map: some View {
        if let region = viewModel.mapRegion {
            NavigationLink {
                FullScreenRouteMapView(
                    coordinates: viewModel.mapCoordinates,
                    region: region,
                    metrics: viewModel.mapMetrics,
                    selected: viewModel.selectedCoordinate,
                )
            } label: {
                RouteMapView(
                    coordinates: viewModel.mapCoordinates,
                    position: .constant(.region(region)),
                    interactionModes: [],
                    selected: viewModel.selectedCoordinate,
                )
                .frame(height: 160)
                .clipShape(.rect(cornerRadius: Radius.xl))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("detail.map.open", bundle: .module))
        } else {
            MapUnavailableView()
        }
    }

    private var elevation: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("detail.chart.title", bundle: .module)
                .font(AppFont.headline)
                .foregroundStyle(AppColor.textPrimary)

            if viewModel.profilePoints.isEmpty {
                Text("detail.chart.unavailable", bundle: .module)
                    .font(AppFont.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ElevationProfileView(
                    points: viewModel.profilePoints,
                    summary: viewModel.profileSummary,
                    readout: viewModel.profileReadout,
                    selection: $viewModel.selectedKilometres,
                )
            }
        }
    }

    @ViewBuilder
    private var plan: some View {
        if !viewModel.planSummary.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("detail.plan.title", bundle: .module)
                    .font(AppFont.headline)
                    .foregroundStyle(AppColor.textPrimary)

                ForEach(viewModel.planSummary) { entry in
                    HStack(alignment: .top, spacing: Spacing.xl) {
                        Text(entry.label, bundle: .module)
                            .font(AppFont.subheadline)
                            .foregroundStyle(AppColor.textSecondary)

                        Spacer(minLength: Spacing.md)

                        Text(verbatim: entry.value)
                            .font(AppFont.subheadlineStrong)
                            .foregroundStyle(AppColor.textPrimary)
                    }
                }
            }
            .padding(Spacing.xl)
            .background(AppColor.textPrimary.opacity(0.06))
            .clipShape(.rect(cornerRadius: Radius.xl))
        }
    }

    private var metrics: some View {
        LazyVGrid(columns: metricColumns, spacing: Spacing.xl) {
            ForEach(viewModel.metrics) { entry in
                RouteMetricView(metric: entry)
            }
        }
    }

    private var metricColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), alignment: .topLeading),
            count: dynamicTypeSize.isAccessibilitySize ? 1 : 2,
        )
    }

    @ViewBuilder
    private var climb: some View {
        if let climb = viewModel.keyClimb {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("detail.climb.title", bundle: .module)
                    .font(AppFont.headline)

                Text(
                    "detail.climb.summary \(climb.start) \(climb.end) \(climb.gain) \(climb.grade)",
                    bundle: .module,
                )
                .font(AppFont.subheadline)
            }
            .foregroundStyle(AppColor.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private func previewOpened(geometry: RouteGeometry, isSaved: Bool = false) -> OpenedRoute {
    OpenedRoute(
        route: ImportedRoute(
            name: "Ridge Loop",
            geometry: geometry,
            summary: RouteSummary(
                distanceMetres: 20000,
                elevationCoverage: .complete,
                ascentMetres: 1200,
                descentMetres: 1200,
                minimumElevationMetres: 800,
                maximumElevationMetres: 1600,
            ),
        ),
        data: isSaved ? nil : Data(),
        isSaved: isSaved,
    )
}

private let previewGeometry = RouteGeometry(
    segments: [
        (0 ..< 120).map { step in
            TrackPoint(
                latitude: -8.3635 + Double(step) * 0.0002,
                longitude: 115.4612 + sin(Double(step) / 19) * 0.01,
                elevation: 900 + 500 * sin(Double(step) / 29),
                timestamp: nil,
            )
        },
    ],
)

#Preview("Unsaved route") {
    NavigationStack {
        RouteDetailView(opened: previewOpened(geometry: previewGeometry), container: AppContainer.preview())
    }
    .preferredColorScheme(.light)
}

#Preview("Saved route") {
    NavigationStack {
        RouteDetailView(
            opened: previewOpened(geometry: previewGeometry, isSaved: true),
            container: AppContainer.preview(),
        )
    }
    .preferredColorScheme(.light)
}

#Preview("Map unavailable") {
    NavigationStack {
        RouteDetailView(
            opened: previewOpened(geometry: RouteGeometry(segments: [])),
            container: AppContainer.preview(),
        )
    }
    .preferredColorScheme(.light)
}
