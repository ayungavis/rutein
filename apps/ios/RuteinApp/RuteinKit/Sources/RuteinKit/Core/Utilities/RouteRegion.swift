import CoreLocation
import MapKit

public enum RouteRegion {
    public static let minimumSpanDegrees = 0.004
    public static let paddingFactor = 1.3

    public static func coordinates(from geometry: RouteGeometry) -> [CLLocationCoordinate2D] {
        geometry.segments.flatMap { segment in
            segment
                .filter(\.hasValidCoordinate)
                .map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        }
    }

    public static func region(fitting coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion? {
        guard let first = coordinates.first else {
            return nil
        }

        var southernmost = first.latitude
        var northernmost = first.latitude

        for coordinate in coordinates.dropFirst() {
            southernmost = min(southernmost, coordinate.latitude)
            northernmost = max(northernmost, coordinate.latitude)
        }

        let longitudes = longitudeFit(coordinates.map(\.longitude).sorted())

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (southernmost + northernmost) / 2,
                longitude: longitudes.centre,
            ),
            span: MKCoordinateSpan(
                latitudeDelta: padded(northernmost - southernmost, ceiling: 180),
                longitudeDelta: padded(longitudes.span, ceiling: 360),
            ),
        )
    }

    private static func longitudeFit(_ sorted: [Double]) -> (centre: Double, span: Double) {
        var widestGap = sorted[0] + 360 - sorted[sorted.count - 1]
        var gapStart = sorted[sorted.count - 1]

        for index in 1 ..< sorted.count where sorted[index] - sorted[index - 1] > widestGap {
            widestGap = sorted[index] - sorted[index - 1]
            gapStart = sorted[index - 1]
        }

        return (normalised(gapStart + widestGap / 2 + 180), 360 - widestGap)
    }

    private static func padded(_ span: Double, ceiling: Double) -> Double {
        min(max(span * paddingFactor, minimumSpanDegrees), ceiling)
    }

    private static func normalised(_ longitude: Double) -> Double {
        let wrapped = (longitude + 180).truncatingRemainder(dividingBy: 360)

        return (wrapped < 0 ? wrapped + 360 : wrapped) - 180
    }
}
