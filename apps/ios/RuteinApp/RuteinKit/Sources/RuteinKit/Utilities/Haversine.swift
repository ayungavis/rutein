import Foundation

public enum Haversine {
    public static let earthRadiusMetres = 6_371_008.8

    public static func metres(from origin: TrackPoint, to destination: TrackPoint) -> Double {
        let originLatitude = origin.latitude * .pi / 180
        let destinationLatitude = destination.latitude * .pi / 180
        let deltaLatitude = destinationLatitude - originLatitude
        let deltaLongitude = normalisedDegrees(destination.longitude - origin.longitude) * .pi / 180

        let haversine = sin(deltaLatitude / 2) * sin(deltaLatitude / 2)
            + cos(originLatitude) * cos(destinationLatitude)
            * sin(deltaLongitude / 2) * sin(deltaLongitude / 2)

        return 2 * earthRadiusMetres * asin(min(1, haversine.squareRoot()))
    }

    private static func normalisedDegrees(_ degrees: Double) -> Double {
        var normalised = degrees

        if normalised > 180 {
            normalised -= 360
        }

        if normalised < -180 {
            normalised += 360
        }

        return normalised
    }
}
