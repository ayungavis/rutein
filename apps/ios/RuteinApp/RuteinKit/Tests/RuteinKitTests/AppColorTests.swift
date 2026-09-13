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

    private static let tokens = ["background", "textPrimary", "textSecondary"]

    private func swatches(_ name: String) throws -> (light: Swatch, dark: Swatch) {
        let url = Self.catalogURL.appending(path: "\(name).colorset/Contents.json")
        let set = try JSONDecoder().decode(
            ColorSet.self,
            from: Data(contentsOf: url),
        )

        func swatch(dark: Bool) throws -> Swatch {
            let entry = try #require(set.colors.first { entry in
                (entry.appearances?.contains { $0.value == "dark" } ?? false) == dark
            })

            func channel(_ key: String) throws -> Double {
                let raw = try #require(entry.color.components[key])
                let byte = try #require(
                    UInt8(raw.replacingOccurrences(of: "0x", with: ""), radix: 16),
                )

                return Double(byte) / 255
            }

            return try Swatch(red: channel("red"), green: channel("green"), blue: channel("blue"))
        }

        return try (swatch(dark: false), swatch(dark: true))
    }

    @Test("Every token defines both appearances")
    func everyTokenDefinesBothAppearances() throws {
        for name in Self.tokens {
            _ = try swatches(name)
        }
    }

    @Test("Text meets WCAG AA agains the background in both appearances")
    func textContrastPassesAA() throws {
        let background = try swatches("background")

        for name in ["textPrimary", "textSecondary"] {
            let text = try swatches(name)

            #expect(text.light.contrast(against: background.light) >= 4.5, "\(name) light")
            #expect(text.dark.contrast(against: background.dark) >= 4.5, "\(name) dark")
        }
    }

    @Test("The hierarchy is the same strength in light and dark")
    func hierarchyMatchesAcrossAppearances() throws {
        let background = try swatches("background")
        let secondary = try swatches("textSecondary")

        let light = secondary.light.contrast(against: background.light)
        let dark = secondary.dark.contrast(against: background.dark)

        #expect(abs(light - dark) < 0.5, "light \(light), dark \(dark)")
    }
}
