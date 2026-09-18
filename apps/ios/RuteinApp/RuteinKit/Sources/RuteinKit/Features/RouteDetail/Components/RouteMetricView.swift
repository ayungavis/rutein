import SwiftUI

public struct RouteMetricView: View {
    private let metric: RouteMetric

    public init(metric: RouteMetric) {
        self.metric = metric
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(verbatim: metric.value)
                .font(AppFont.headline)
                .foregroundStyle(AppColor.textPrimary)

            Text(metric.label, bundle: .module)
                .font(AppFont.footnote)
                .foregroundStyle(AppColor.textSecondary)
        }
    }
}

#Preview {
    RouteMetricView(metric: RouteMetric(id: "distance", label: "detail.metric.distance", value: "20.0 km"))
        .padding()
        .background(AppColor.bgBrandPrimary)
        .preferredColorScheme(.light)
}
