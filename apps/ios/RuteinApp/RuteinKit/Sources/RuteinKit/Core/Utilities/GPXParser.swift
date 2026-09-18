import Foundation

public enum GPXParser {
    @concurrent
    public static func parse(_ data: Data) async throws -> GPXDocument {
        let builder = GPXDocumentBuilder()
        let parser = XMLParser(data: data)
        parser.delegate = builder
        parser.shouldProcessNamespaces = true
        parser.shouldResolveExternalEntities = false
        parser.externalEntityResolvingPolicy = .never

        let parsed = parser.parse()

        if builder.wasCancelled {
            throw AppError.cancelled
        }

        if let breached = builder.breachedLimit {
            throw breached
        }

        guard parsed else {
            throw AppError.format
        }

        let document = GPXDocument(candidates: builder.candidates, waypoints: builder.waypoints)

        guard !document.usable.isEmpty else {
            throw AppError.geometry
        }

        return document
    }

    public static func geometry(_ data: Data) async throws -> RouteGeometry {
        let document = try await parse(data)

        guard let candidate = document.preferred.first else {
            throw AppError.geometry
        }

        return document.geometry(for: candidate)
    }
}

private final class GPXDocumentBuilder: NSObject, XMLParserDelegate {
    private enum Scope {
        case none
        case trackPoint
        case routePoint
        case waypoint
    }

    private(set) var candidates: [RouteCandidate] = []
    private(set) var waypoints: [Waypoint] = []
    private(set) var breachedLimit: AppError?
    private(set) var wasCancelled = false

    private var segments: [[TrackPoint]] = []
    private var current: [TrackPoint] = []
    private var containerName: String?
    private var scope = Scope.none
    private var latitude: Double?
    private var longitude: Double?
    private var elevation: Double?
    private var pointName: String?
    private var characters = ""
    private var geometryPoints = 0

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI _: String?,
        qualifiedName _: String?,
        attributes: [String: String],
    ) {
        characters = ""

        if Task.isCancelled {
            wasCancelled = true
            parser.abortParsing()
            return
        }

        switch elementName {
        case "trk", "rte":
            segments = []
            current = []
            containerName = nil
        case "trkseg":
            current = []
        case "trkpt", "rtept", "wpt":
            scope = switch elementName {
            case "trkpt": .trackPoint
            case "rtept": .routePoint
            default: .waypoint
            }
            latitude = attributes["lat"].flatMap(Double.init)
            longitude = attributes["lon"].flatMap(Double.init)
            elevation = nil
            pointName = nil
        default:
            break
        }
    }

    func parser(_: XMLParser, foundCharacters string: String) {
        characters += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI _: String?,
        qualifiedName _: String?,
    ) {
        let text = characters.trimmingCharacters(in: .whitespacesAndNewlines)

        characters = ""

        switch elementName {
        case "ele" where scope != .none:
            elevation = Double(text)
        case "name" where scope == .waypoint:
            pointName = text
        case "name" where scope == .none && containerName == nil:
            containerName = text.isEmpty ? nil : text
        case "trkpt", "rtept":
            appendGeometryPoint(parser)
        case "wpt":
            appendWaypoint(parser)
        case "trkseg":
            segments.append(current)
            current = []
        case "trk", "rte":
            closeCandidate(kind: elementName == "trk" ? .track : .route)
        default:
            break
        }
    }

    private func appendGeometryPoint(_ parser: XMLParser) {
        defer { reset() }

        guard let latitude, let longitude else { return }

        geometryPoints += 1

        guard geometryPoints <= GPXLimits.maximumGeometryPoints else {
            breachedLimit = .capacity
            parser.abortParsing()
            return
        }

        let point = TrackPoint(
            latitude: latitude,
            longitude: longitude,
            elevation: elevation,
            timestamp: nil,
        )

        if point.hasValidCoordinate {
            current.append(point)
        }
    }

    private func appendWaypoint(_ parser: XMLParser) {
        defer { reset() }

        guard waypoints.count < GPXLimits.maximumWaypoints else {
            breachedLimit = .capacity
            parser.abortParsing()
            return
        }

        guard let latitude, let longitude, let pointName, !pointName.isEmpty else { return }

        let waypoint = Waypoint(
            name: pointName,
            latitude: latitude,
            longitude: longitude,
            elevation: elevation,
        )

        if waypoint.hasValidCoordinate {
            waypoints.append(waypoint)
        }
    }

    private func closeCandidate(kind: RouteSourceKind) {
        if !current.isEmpty {
            segments.append(current)
        }

        candidates.append(
            RouteCandidate(
                id: candidates.count,
                kind: kind,
                name: containerName,
                segments: segments,
            ),
        )

        segments = []
        current = []
        containerName = nil
    }

    private func reset() {
        scope = .none
        latitude = nil
        longitude = nil
        elevation = nil
        pointName = nil
    }
}
