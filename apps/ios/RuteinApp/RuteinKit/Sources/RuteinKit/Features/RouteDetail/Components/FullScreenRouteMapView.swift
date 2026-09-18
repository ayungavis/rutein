import MapKit
import SwiftUI

public struct FullScreenRouteMapView: View {
    @State private var position: MapCameraPosition

    private let coordinates: [CLLocationCoordinate2D]
    private let region: MKCoordinateRegion
    private let metrics: [RouteMetric]
    private let selected: CLLocationCoordinate2D?

    public init(
        coordinates: [CLLocationCoordinate2D],
        region: MKCoordinateRegion,
        metrics: [RouteMetric],
        selected: CLLocationCoordinate2D? = nil,
    ) {
        self.coordinates = coordinates
        self.region = region
        self.metrics = metrics
        self.selected = selected
        _position = State(initialValue: .region(region))
    }

    public var body: some View {
        RouteMapView(
            coordinates: coordinates,
            position: $position,
            interactionModes: .all,
            selected: selected,
        )
        .ignoresSafeArea(edges: .bottom)
        .overlay(alignment: .bottom) {
            VStack(spacing: Spacing.xl) {
                fitButton
                summary
            }
            .padding(Spacing.xl)
        }
    }

    private var fitButton: some View {
        Button {
            position = .region(region)
        } label: {
            Text("detail.map.fit", bundle: .module)
        }
        .buttonStyle(.glassProminent)
        .tint(AppColor.bgPrimary)
    }

    private var summary: some View {
        HStack(alignment: .top, spacing: Spacing.xl3) {
            ForEach(metrics) { metric in
                RouteMetricView(metric: metric)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(Spacing.xl2)
        .background(AppColor.bgBrandPrimary)
        .clipShape(.rect(cornerRadius: Radius.xl))
    }
}

#Preview {
    NavigationStack {
        FullScreenRouteMapView(
            coordinates: (0 ..< 40).map { step in
                CLLocationCoordinate2D(
                    latitude: -8.3635 + Double(step) * 0.0006,
                    longitude: 115.4612 + sin(Double(step) / 6) * 0.01,
                )
            },
            region: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: -8.3519, longitude: 115.4823),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.06),
            ),
            metrics: [
                RouteMetric(id: "distance", label: "detail.metric.distance", value: "20.0 km"),
                RouteMetric(id: "ascent", label: "detail.metric.ascent", value: "+1,200 m"),
            ],
        )
    }
    .preferredColorScheme(.light)
}
