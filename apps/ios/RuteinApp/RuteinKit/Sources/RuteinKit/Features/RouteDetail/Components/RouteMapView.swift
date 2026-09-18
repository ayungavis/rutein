import MapKit
import SwiftUI

public struct RouteMapView: View {
    @Binding private var position: MapCameraPosition

    private let coordinates: [CLLocationCoordinate2D]
    private let interactionModes: MapInteractionModes
    private let selected: CLLocationCoordinate2D?

    public init(
        coordinates: [CLLocationCoordinate2D],
        position: Binding<MapCameraPosition>,
        interactionModes: MapInteractionModes,
        selected: CLLocationCoordinate2D? = nil,
    ) {
        self.coordinates = coordinates
        _position = position
        self.interactionModes = interactionModes
        self.selected = selected
    }

    public var body: some View {
        Map(position: $position, interactionModes: interactionModes) {
            MapPolyline(coordinates: coordinates)
                .stroke(AppColor.textPrimary, lineWidth: 4)

            if let start = coordinates.first {
                Annotation(
                    String(localized: "detail.map.start", bundle: .module),
                    coordinate: start,
                    anchor: .bottomTrailing,
                ) {
                    terminus(solid: true)
                }
            }

            if let selected {
                Annotation(
                    String(localized: "detail.chart.selected", bundle: .module),
                    coordinate: selected,
                    anchor: .bottom,
                ) {
                    Circle()
                        .fill(AppColor.bgBrandPrimary)
                        .overlay(Circle().strokeBorder(AppColor.textPrimary, lineWidth: 4))
                        .frame(width: Spacing.xl2, height: Spacing.xl2)
                }
            }

            if let finish = coordinates.last {
                Annotation(
                    String(localized: "detail.map.finish", bundle: .module),
                    coordinate: finish,
                    anchor: .bottomLeading,
                ) {
                    terminus(solid: false)
                }
            }
        }
    }

    private func terminus(solid: Bool) -> some View {
        Circle()
            .fill(solid ? AppColor.textPrimary : AppColor.bgBrandPrimary)
            .overlay(Circle().strokeBorder(AppColor.textPrimary, lineWidth: 3))
            .frame(width: Spacing.xl, height: Spacing.xl)
    }
}

#Preview {
    RouteMapView(
        coordinates: (0 ..< 40).map { step in
            CLLocationCoordinate2D(
                latitude: -8.3635 + Double(step) * 0.0006,
                longitude: 115.4612 + sin(Double(step) / 6) * 0.01,
            )
        },
        position: .constant(
            .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: -8.3519, longitude: 115.4823),
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.06),
                ),
            ),
        ),
        interactionModes: [],
    )
    .frame(height: 160)
    .clipShape(.rect(cornerRadius: Radius.xl))
    .padding()
    .background(AppColor.bgBrandPrimary)
    .preferredColorScheme(.light)
}
