import Foundation
import Testing
@testable import RuteinKit

private struct Swatch {
    let red: Double
    let green: Double
    let blue: Double

    var relativeLuminance: Double {
        func channel(_ value: Double) -> Double {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }

    func contrast(against other: Swatch) -> Double {
        let lighter = max(relativeLuminance, other.relativeLuminance)
        let darker = min(relativeLuminance, other.relativeLuminance)

        return (lighter + 0.05) / (darker + 0.05)
    }
}

private struct Appearance: Decodable {
    let value: String
}

private struct Payload: Decodable {
    let components: [String: String]
}

private struct Entry: Decodable {
    let appearances: [Appearance]?
    let color: Payload
}

private struct ColorSet: Decodable {
    let colors: [Entry]
}

@Suite("AppColor")
struct AppColorTests {
    private static let catalogURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Sources/RuteinKit/DesignSystem/Resources/Colors.xcassets")

    private static let textTokens = ["textPrimary", "textSecondary"]

    private func swatch(_ name: String) throws -> Swatch {
        let url = Self.catalogURL.appending(path: "\(name).colorset/Contents.json")
        let set = try JSONDecoder().decode(
            ColorSet.self,
            from: Data(contentsOf: url),
        )
        let entry = try #require(set.colors.first)

        #expect(entry.appearances == nil, "\(name) carries a dark appearance")

        func channel(_ key: String) throws -> Double {
            let raw = try #require(entry.color.components[key])
            let byte = try #require(
                UInt8(raw.replacingOccurrences(of: "0x", with: ""), radix: 16),
            )

            return Double(byte) / 255
        }

        return try Swatch(red: channel("red"), green: channel("green"), blue: channel("blue"))
    }

    @Test("Every token ships one appearance")
    func everyTokenShipsOneAppearance() throws {
        for name in Self.textTokens + ["bgBrandPrimary", "bgPrimary"] {
            _ = try swatch(name)
        }
    }

    @Test("Text meets WCAG AA against the ground")
    func textContrastPassesAA() throws {
        let ground = try swatch("bgBrandPrimary")

        for name in Self.textTokens {
            #expect(try swatch(name).contrast(against: ground) >= 4.5, "\(name)")
        }
    }

    @Test("Secondary text is quieter than primary")
    func secondaryIsQuieterThanPrimary() throws {
        let ground = try swatch("bgBrandPrimary")

        #expect(
            try swatch("textSecondary").contrast(against: ground)
                < swatch("textPrimary").contrast(against: ground),
        )
    }
}
