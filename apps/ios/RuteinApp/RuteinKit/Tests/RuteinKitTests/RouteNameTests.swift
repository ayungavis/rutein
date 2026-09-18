import Foundation
import Testing
@testable import RuteinKit

@Suite("RouteName and RouteFingerprint")
struct RouteNameTests {
    @Test("One to eighty characters after trimming is accepted")
    func boundariesAreAccepted() throws {
        #expect(try RouteName.validated("a") == "a")
        #expect(try RouteName.validated(String(repeating: "a", count: 80)).count == 80)
        #expect(try RouteName.validated("\n  Ridge Loop \t") == "Ridge Loop")
    }

    @Test("Blank, whitespace-only and eighty-one characters are refused")
    func boundariesAreRefused() {
        #expect(throws: AppError.dataQuality) { _ = try RouteName.validated("") }
        #expect(throws: AppError.dataQuality) { _ = try RouteName.validated("  \n ") }
        #expect(throws: AppError.dataQuality) {
            _ = try RouteName.validated(String(repeating: "a", count: 81))
        }
    }

    @Test("The limit counts user-perceived characters, not UTF-16 units")
    func limitCountsGraphemeClusters() throws {
        let flags = String(repeating: "🇮🇩", count: 80)

        #expect(flags.utf16.count == 320)
        #expect(try RouteName.validated(flags).count == 80)
    }

    @Test("A fingerprint is stable for identical bytes and differs for any change")
    func fingerprintIsStableAndSensitive() {
        let data = Data("<gpx/>".utf8)

        #expect(RouteFingerprint.of(data) == RouteFingerprint.of(Data("<gpx/>".utf8)))
        #expect(RouteFingerprint.of(data) != RouteFingerprint.of(Data("<gpx />".utf8)))
        #expect(RouteFingerprint.of(data).count == 64)
    }
}
