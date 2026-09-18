import SwiftUI

public struct RoutePlannerView: View {
    @State private var viewModel: RoutePlannerViewModel
    @State private var brief: PlannedRoute?

    private let container: AppContainer
    private let opened: OpenedRoute

    public init(opened: OpenedRoute, container: AppContainer) {
        self.opened = opened
        self.container = container
        _viewModel = State(
            initialValue: RoutePlannerViewModel(route: opened.route, savedPlan: opened.plan),
        )
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl3) {
                heading
                DurationWheelView(hours: $viewModel.hours, minutes: $viewModel.minutes)
                quickPicks
                durationNotice
                pace
                optional
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.xl3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.bgBrandPrimary)
        .tint(AppColor.textPrimary)
        .safeAreaInset(edge: .bottom) { generate }
        .navigationDestination(item: $brief) { planned in
            RouteBriefView(planned: planned, container: container)
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("plan.title", bundle: .module)
                .font(AppFont.display)
                .foregroundStyle(AppColor.textPrimary)

            Text("plan.subtitle", bundle: .module)
                .font(AppFont.subheadline)
                .foregroundStyle(AppColor.textSecondary)
        }
    }

    private var quickPicks: some View {
        Picker(selection: quickSelection) {
            ForEach(RoutePlannerViewModel.quickHours, id: \.self) { hours in
                Text(verbatim: viewModel.quickLabel(hours: hours)).tag(hours)
            }
        } label: {
            Text("plan.quick.label", bundle: .module)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var quickSelection: Binding<Int> {
        Binding(
            get: { viewModel.minutes == 0 ? viewModel.hours : -1 },
            set: { viewModel.selectQuick(hours: $0) },
        )
    }

    @ViewBuilder
    private var durationNotice: some View {
        if let failure = viewModel.durationFailure {
            Text(failure, bundle: .module)
                .font(AppFont.footnote)
                .foregroundStyle(AppColor.textPrimary)
        }
    }

    @ViewBuilder
    private var pace: some View {
        if let averagePace = viewModel.averagePace {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack {
                    Text("plan.pace.label", bundle: .module)

                    Spacer(minLength: Spacing.xl)

                    Text("plan.pace \(averagePace)", bundle: .module)
                }
                .font(AppFont.headline)
                .foregroundStyle(AppColor.textPrimary)

                Text(
                    "plan.pace.working \(viewModel.paceWorking) \(viewModel.targetDuration)",
                    bundle: .module,
                )
                .font(AppFont.footnote)
                .foregroundStyle(AppColor.textSecondary)
            }
        }
    }

    private var optional: some View {
        VStack(alignment: .leading, spacing: Spacing.xl3) {
            Text("plan.optional", bundle: .module)
                .font(AppFont.headline)
                .foregroundStyle(AppColor.textPrimary)

            PlanOptionRow(
                title: "plan.start.title",
                note: "plan.start.note",
                isOn: $viewModel.usesStartInstant,
            ) {
                DatePicker(
                    selection: $viewModel.startInstant,
                    displayedComponents: [.date, .hourAndMinute],
                ) {
                    Text("plan.start.title", bundle: .module)
                }
                .labelsHidden()

                Text("plan.start.zone \(viewModel.startZone)", bundle: .module)
                    .font(AppFont.footnote)
                    .foregroundStyle(AppColor.textSecondary)
            }

            PlanOptionRow(
                title: "plan.drink.title",
                note: "plan.drink.note",
                isOn: $viewModel.usesDrinkInterval,
            ) {
                intervalStepper(minutes: $viewModel.drinkIntervalMinutes, label: "plan.drink.title")
            }

            PlanOptionRow(
                title: "plan.fuel.title",
                note: "plan.fuel.note",
                isOn: $viewModel.usesFuelInterval,
            ) {
                intervalStepper(minutes: $viewModel.fuelIntervalMinutes, label: "plan.fuel.title")
            }
        }
    }

    private func intervalStepper(minutes: Binding<Int>, label: LocalizedStringKey) -> some View {
        Stepper(value: minutes, in: RoutePlan.intervalRange, step: 5) {
            Text("plan.interval.value \(minutes.wrappedValue)", bundle: .module)
                .font(AppFont.subheadline)
                .foregroundStyle(AppColor.textPrimary)
        }
        .accessibilityLabel(Text(label, bundle: .module))
    }

    private var generate: some View {
        Button {
            if let draft = viewModel.draft {
                brief = PlannedRoute(opened: opened, plan: draft)
            }
        } label: {
            Text("plan.generate", bundle: .module)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .tint(AppColor.bgPrimary)
        .disabled(viewModel.draft == nil)
        .padding(.horizontal, Spacing.xl4)
        .padding(.top, Spacing.xl)
    }
}

#Preview {
    NavigationStack {
        RoutePlannerView(opened: plannerPreviewRoute, container: AppContainer.preview())
    }
    .preferredColorScheme(.light)
}

private let plannerPreviewRoute = OpenedRoute(
    route: ImportedRoute(
        name: "Ridge Loop",
        geometry: RouteGeometry(segments: []),
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
