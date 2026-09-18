import Charts
import SwiftUI

public struct ElevationProfileView: View {
    @Binding private var selection: Double?

    private let points: [ElevationProfilePoint]
    private let summary: String
    private let readout: String?

    public init(
        points: [ElevationProfilePoint],
        summary: String,
        readout: String?,
        selection: Binding<Double?>,
    ) {
        self.points = points
        self.summary = summary
        self.readout = readout
        _selection = selection
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            chart
            legend
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("detail.chart.label", bundle: .module))
        .accessibilityValue(Text(verbatim: readout ?? summary))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: step(by: 1)
            case .decrement: step(by: -1)
            @unknown default: break
            }
        }
    }

    private var chart: some View {
        Chart(points) { point in
            AreaMark(
                x: .value("detail.chart.distance", point.distanceKilometres),
                y: .value("detail.chart.elevation", point.elevationMetres),
            )
            .foregroundStyle(by: .value("detail.chart.run", point.run))

            LineMark(
                x: .value("detail.chart.distance", point.distanceKilometres),
                y: .value("detail.chart.elevation", point.elevationMetres),
                series: .value("detail.chart.run", point.run),
            )
            .foregroundStyle(AppColor.textPrimary)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        .chartForegroundStyleScale(mapping: { (_: Int) in fill })
        .chartLegend(.hidden)
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisValueLabel {
                    if let kilometres = value.as(Double.self) {
                        Text(kilometres, format: .number.precision(.fractionLength(0)))
                            .font(AppFont.footnote)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                }
            }
        }
        .chartYAxis(.hidden)
        .chartXSelection(value: $selection)
        .frame(minHeight: 140, maxHeight: 220)
    }

    private var fill: LinearGradient {
        .linearGradient(
            colors: [AppColor.textPrimary.opacity(0.24), AppColor.textPrimary.opacity(0.02)],
            startPoint: .top,
            endPoint: .bottom,
        )
    }

    @ViewBuilder
    private var legend: some View {
        if let readout {
            Text(verbatim: readout)
                .font(AppFont.footnote)
                .foregroundStyle(AppColor.textPrimary)
        } else {
            Text("detail.chart.hint", bundle: .module)
                .font(AppFont.footnote)
                .foregroundStyle(AppColor.textSecondary)
        }
    }

    private func step(by offset: Int) {
        guard let first = points.first, let last = points.last else {
            return
        }

        guard let current = selection else {
            selection = first.distanceKilometres
            return
        }

        let index = points.firstIndex { $0.distanceKilometres >= current } ?? 0
        let next = min(max(0, index + offset), points.count - 1)

        selection = min(max(points[next].distanceKilometres, first.distanceKilometres), last.distanceKilometres)
    }
}

#Preview {
    @Previewable @State var selection: Double?

    return ElevationProfileView(
        points: (0 ..< 60).map { step in
            ElevationProfilePoint(
                id: step,
                run: step < 30 ? 0 : 1,
                distanceKilometres: Double(step) * 0.35,
                elevationMetres: 900 + 500 * sin(Double(step) / 9),
            )
        },
        summary: "Climbs from 900 m to 1,400 m over 20.7 km",
        readout: nil,
        selection: $selection,
    )
    .padding()
    .background(AppColor.bgBrandPrimary)
    .preferredColorScheme(.light)
}
