import CoreLocation
import Foundation

public enum RoutePosition {
    public static func coordinate(
        at distanceMetres: Double,
        in geometry: RouteGeometry,
    ) -> CLLocationCoordinate2D? {
        locate(distanceMetres, in: geometry) { edge, along in
            CLLocationCoordinate2D(
                latitude: edge.start.latitude + (edge.end.latitude - edge.start.latitude) * along,
                longitude: edge.start.longitude
                    + Haversine.normalisedDegrees(edge.end.longitude - edge.start.longitude) * along,
            )
        }
    }

    public static func elevation(at distanceMetres: Double, in geometry: RouteGeometry) -> Double? {
        locate(distanceMetres, in: geometry) { edge, along in
            guard let start = edge.start.elevation, let end = edge.end.elevation else {
                return nil
            }

            return start + (end - start) * along
        }
    }

    private static func locate<Value>(
        _ distanceMetres: Double,
        in geometry: RouteGeometry,
        _ transform: (_ edge: (start: TrackPoint, end: TrackPoint), _ along: Double) -> Value?,
    ) -> Value? {
        var travelled = 0.0

        for segment in geometry.segments {
            for index in segment.indices.dropFirst() {
                let edge = (start: segment[index - 1], end: segment[index])
                let length = Haversine.metres(from: edge.start, to: edge.end)

                if travelled + length >= distanceMetres, length > 0 {
                    return transform(edge, (distanceMetres - travelled) / length)
                }

                travelled += length
            }
        }

        return nil
    }
}
