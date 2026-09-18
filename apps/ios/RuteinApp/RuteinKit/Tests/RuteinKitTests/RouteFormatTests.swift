import Foundation
import Testing
@testable import RuteinKit

@Suite("RouteFormat")
struct RouteFormatTests {
    private static let imperialLocales = ["en_US", "en_GB", "my_MM", "en_LR"]

    @Test("Distance stays metric in locales that prefer miles")
    func distanceStaysMetric() {
        for identifier in Self.imperialLocales {
            let formatted = RouteFormat.distance(
                12437.447,
                locale: Locale(identifier: identifier),
            )

            #expect(formatted.contains("km"), "\(identifier) produced \(formatted)")
            #expect(!formatted.contains("mi"), "\(identifier) produced \(formatted)")
        }
    }

    @Test("Elevation stays metric in locales that prefer feet")
    func elevationStaysMetric() {
        for identifier in Self.imperialLocales {
            let formatted = RouteFormat.elevation(1872.429, locale: Locale(identifier: identifier))

            #expect(formatted.contains("m"), "\(identifier) produced \(formatted)")
            #expect(!formatted.contains("ft"), "\(identifier) produced \(formatted)")
        }
    }

    @Test("Distance carries one decimal place")
    func distanceCarriesOneDecimal() {
        #expect(RouteFormat.distance(12437.447, locale: Locale(identifier: "en_US")) == "12.4 km")
        #expect(RouteFormat.distance(20000, locale: Locale(identifier: "en_US")) == "20.0 km")
    }

    @Test("Elevation rounds to whole metres and groups thousands")
    func elevationRoundsToWholeMetres() {
        #expect(RouteFormat.elevation(1872.429, locale: Locale(identifier: "en_US")) == "1,872 m")
    }

    @Test("Ascent and descent carry their direction")
    func signedElevationCarriesDirection() {
        let ascent = RouteFormat.signedElevation(1872.429, locale: Locale(identifier: "en_US"))
        let descent = RouteFormat.signedElevation(-1779.873, locale: Locale(identifier: "en_US"))

        #expect(ascent == "+1,872 m")
        #expect(descent.hasSuffix("1,780 m"))
        #expect(descent != ascent)
        #expect(!descent.hasPrefix("+"))
    }

    @Test("The decimal separator follows the locale")
    func separatorFollowsLocale() {
        let indonesian = RouteFormat.distance(12437.447, locale: Locale(identifier: "id_ID"))

        #expect(indonesian == "12,4 km")
    }

    @Test("A kilometre mark is a bare whole number, for the climb window label")
    func kilometreMarkIsBareAndWhole() {
        #expect(RouteFormat.kilometreMark(5901.744, locale: Locale(identifier: "en_US")) == "6")
        #expect(RouteFormat.kilometreMark(0, locale: Locale(identifier: "en_US")) == "0")
    }

    @Test("A grade renders as a whole percent")
    func gradeRendersAsWholePercent() {
        #expect(RouteFormat.grade(0.31497, locale: Locale(identifier: "en_US")) == "31%")
        #expect(RouteFormat.grade(0.05, locale: Locale(identifier: "en_US")) == "5%")
    }
}
