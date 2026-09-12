import Foundation

public enum GPXParser {
    @concurrent
    public static func parse(_ data: Data) async throws -> RouteGeometry {
        let builder = GPXGeometryBuilder()
        let parser = XMLParser(data: data)
        parser.delegate = builder
        parser.shouldProcessNamespaces = true
        parser.shouldResolveExternalEntities = true
        parser.externalEntityResolvingPolicy = .never

        guard parser.parse() else {
            throw AppError.format
        }

        let usable = builder.segments.filter { $0.count >= 2 }

        guard !usable.isEmpty else {
            throw AppError.geometry
        }

        return RouteGeometry(segments: usable)
    }
}

private final class GPXGeometryBuilder: NSObject, XMLParserDelegate {
    private(set) var segments: [[TrackPoint]] = []

    private var current: [TrackPoint] = []
    private var latitude: Double?
    private var longitude: Double?
    private var elevation: Double?
    private var characters = ""

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String],
    ) {
        characters = ""

        switch elementName {
        case "trkseg":
            current = []
        case "trkpt":
            latitude = attributes["lat"].flatMap(Double.init)
            longitude = attributes["lon"].flatMap(Double.init)
            elevation = nil
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        characters += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
    ) {
        switch elementName {
        case "ele":
            elevation = Double(
                characters.trimmingCharacters(in: .whitespacesAndNewlines),
            )
        case "trkpt":
            appendCurrentPoint()
        case "trkseg":
            segments.append(current)
            current = []
        default:
            break
        }

        characters = ""
    }

    private func appendCurrentPoint() {
        guard let latitude, let longitude else { return }

        let point = TrackPoint(
            latitude: latitude,
            longitude: longitude,
            elevation: elevation,
            timestamp: nil,
        )

        if point.hasValidCoordinate {
            current.append(point)
        }

        self.latitude = nil
        self.longitude = nil
        elevation = nil
    }
}
