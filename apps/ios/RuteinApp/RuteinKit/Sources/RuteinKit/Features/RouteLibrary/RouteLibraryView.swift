import SwiftUI
import UniformTypeIdentifiers

public struct RouteLibraryView: View {
    @State private var viewModel: RouteLibraryViewModel
    @State private var renameText = ""

    private let container: AppContainer

    public init(container: AppContainer) {
        self.container = container
        _viewModel = State(initialValue: RouteLibraryViewModel(routes: container.routes))
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColor.bgBrandPrimary)
            .tint(AppColor.textPrimary)
            .safeAreaInset(edge: .bottom) { actions }
            .task { await viewModel.load() }
            .onChange(of: viewModel.openedRoute) { _, opened in
                if opened == nil {
                    Task { await viewModel.load() }
                }
            }
            .onChange(of: viewModel.renaming) { _, target in
                renameText = target?.name ?? ""
            }
            .fileImporter(
                isPresented: $viewModel.isPickingFile,
                allowedContentTypes: [.gpx],
            ) { result in
                viewModel.importRoute(result)
            }
            .navigationDestination(item: $viewModel.openedRoute) { opened in
                RouteDetailView(opened: opened, container: container)
            }
            .sheet(item: $viewModel.pendingImport) { pending in
                TrackSelectionView(pending: pending) { candidate in
                    Task { await viewModel.choose(candidate) }
                } onCancel: {
                    viewModel.cancelImport()
                }
            }
            .modifier(RouteFailureAlerts(viewModel: viewModel))
            .modifier(RouteManagementDialogs(viewModel: viewModel, renameText: $renameText))
        #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    @ViewBuilder
    private var content: some View {
        if let failure = viewModel.libraryFailure {
            storageFailure(failure)
        } else if viewModel.savedRoutes.isEmpty {
            empty
        } else {
            list
        }
    }

    private func storageFailure(_ failure: LocalizedStringKey) -> some View {
        VStack(spacing: Spacing.xl) {
            Text(failure, bundle: .module)
                .font(AppFont.subheadline)
                .foregroundStyle(AppColor.textPrimary)
                .multilineTextAlignment(.center)

            Button {
                Task { await viewModel.load() }
            } label: {
                Text("library.failed.retry", bundle: .module)
            }
            .buttonStyle(.glass)
        }
        .padding(Spacing.xl4)
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl3) {
                heading

                LazyVStack(spacing: Spacing.xl3) {
                    ForEach(viewModel.savedRoutes) { route in
                        RouteRowView(
                            route: route,
                            distance: RouteFormat.distance(route.summary.distanceMetres),
                            ascent: route.summary.ascentMetres.map { RouteFormat.signedElevation($0) },
                            planDuration: route.plan.map {
                                RouteFormat.duration($0.targetDurationSeconds)
                            },
                            onOpen: { Task { await viewModel.open(route) } },
                            onRename: { viewModel.renaming = route },
                            onDelete: { viewModel.deleting = route },
                        )
                    }
                }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.xl6)
        }
    }

    private var empty: some View {
        VStack(spacing: 0) {
            heading
                .padding(.horizontal, Spacing.xl)

            Spacer(minLength: Spacing.xl)

            Image("libraryEmpty", bundle: .module)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 284)
                .accessibilityHidden(true)

            Spacer(minLength: Spacing.xl)
        }
        .padding(.top, Spacing.xl6)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("library.empty.title", bundle: .module)
                .font(AppFont.display)
                .foregroundStyle(AppColor.textPrimary)

            subhead
                .font(AppFont.subheadline)
                .foregroundStyle(AppColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var subhead: some View {
        if viewModel.savedRoutes.isEmpty {
            Text("library.empty.description", bundle: .module)
        } else {
            Text("library.subhead \(viewModel.savedRoutes.count)", bundle: .module)
        }
    }

    private var actions: some View {
        VStack(spacing: Spacing.md) {
            if viewModel.isImporting {
                Button {
                    viewModel.cancelImport()
                } label: {
                    HStack(spacing: Spacing.md) {
                        ProgressView()

                        Text("library.import.cancel", bundle: .module)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
            } else {
                Button {
                    viewModel.isPickingFile = true
                } label: {
                    Text("library.import.action", bundle: .module)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .tint(AppColor.bgPrimary)
            }

            Text("library.privacy.footnote", bundle: .module)
                .font(AppFont.footnote)
                .foregroundStyle(AppColor.textPrimary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Spacing.xl4)
        .padding(.top, Spacing.xl)
    }
}

extension UTType {
    static let gpx = UTType(importedAs: "com.topografix.gpx")
}

#Preview("Empty") {
    NavigationStack {
        RouteLibraryView(container: AppContainer.preview())
    }
    .preferredColorScheme(.light)
}
