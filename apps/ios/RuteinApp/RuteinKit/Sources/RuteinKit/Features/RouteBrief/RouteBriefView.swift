import SwiftUI

public struct RouteBriefView: View {
    @State private var viewModel: RouteBriefViewModel

    public init(planned: PlannedRoute, container: AppContainer) {
        _viewModel = State(
            initialValue: RouteBriefViewModel(planned: planned, routes: container.routes),
        )
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl3) {
                heading

                BriefNoticeView(
                    title: "brief.estimate.title",
                    detail: "brief.estimate.detail",
                    symbol: "info.circle",
                )

                BriefTimelineView(rows: viewModel.rows)

                if viewModel.usesDistanceMarkers {
                    BriefNoticeView(
                        title: "brief.markers.title",
                        detail: "brief.markers.detail",
                        symbol: "exclamationmark.circle",
                    )
                }

                if let note = viewModel.dataQualityNote {
                    Text(note, bundle: .module)
                        .font(AppFont.footnote)
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.xl3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.bgBrandPrimary)
        .tint(AppColor.textPrimary)
        .safeAreaInset(edge: .bottom) { actions }
        .sheet(isPresented: $viewModel.isPreviewingShare) {
            SharePreviewView(
                text: viewModel.shareText,
                card: viewModel.briefImage(),
                imageName: viewModel.name,
            )
        }
        .alert(
            Text("brief.save.title", bundle: .module),
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

    private var heading: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("brief.title", bundle: .module)
                .font(AppFont.display)
                .foregroundStyle(AppColor.textPrimary)

            Text(
                "brief.subhead \(viewModel.distance) \(viewModel.targetDuration) \(viewModel.averagePace)",
                bundle: .module,
            )
            .font(AppFont.subheadline)
            .foregroundStyle(AppColor.textSecondary)
        }
    }

    private var actions: some View {
        HStack(spacing: Spacing.md) {
            Button {
                viewModel.isPreviewingShare = true
            } label: {
                Text("brief.share.action", bundle: .module)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .controlSize(.large)

            if !viewModel.isSaved {
                Button {
                    Task { await viewModel.savePlan() }
                } label: {
                    if viewModel.isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("brief.save.action", bundle: .module)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .tint(AppColor.bgPrimary)
                .disabled(viewModel.isSaving)
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.xl)
    }
}

#Preview {
    if let plan = try? RoutePlan(targetDurationSeconds: 18000, drinkIntervalMinutes: 30) {
        NavigationStack {
            RouteBriefView(
                planned: PlannedRoute(opened: briefPreviewRoute, plan: plan),
                container: AppContainer.preview(),
            )
        }
        .preferredColorScheme(.light)
    }
}

private let briefPreviewRoute = OpenedRoute(
    route: ImportedRoute(
        name: "Ridge Loop",
        geometry: RouteGeometry(
            segments: [
                (0 ..< 180).map { step in
                    TrackPoint(
                        latitude: Double(step) * 0.001,
                        longitude: 0,
                        elevation: 900 + Double(step) * 4,
                        timestamp: nil,
                    )
                },
            ],
        ),
        summary: RouteSummary(
            distanceMetres: 20000,
            elevationCoverage: .complete,
            ascentMetres: 1200,
            descentMetres: 1200,
            minimumElevationMetres: 800,
            maximumElevationMetres: 1600,
        ),
    ),
    data: nil,
    isSaved: true,
)
