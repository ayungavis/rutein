import Foundation
import Testing

private struct Catalog: Decodable {
    let sourceLanguage: String
    let strings: [String: CatalogEntry]
}

private struct CatalogEntry: Decodable {
    let localizations: [String: CatalogLocalization]
}

private struct CatalogLocalization: Decodable {
    let stringUnit: CatalogUnit?
    let variations: CatalogVariations?

    var values: [String] {
        (stringUnit.map { [$0.value] } ?? []) + (variations?.values ?? [])
    }
}

private struct CatalogVariations: Decodable {
    let plural: [String: CatalogVariant]?
    let device: [String: CatalogVariant]?

    var values: [String] {
        let cases = Array((plural ?? [:]).values) + Array((device ?? [:]).values)

        return cases.compactMap { $0.stringUnit?.value }
    }
}

private struct CatalogVariant: Decodable {
    let stringUnit: CatalogUnit?
}

private struct CatalogUnit: Decodable {
    let value: String
}

@Suite("Localization")
struct LocalizationTests {
    private static let catalogURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Sources/RuteinKit/Resources/Localizable.xcstrings")

    private func loadCatalog() throws -> Catalog {
        let data = try Data(contentsOf: Self.catalogURL)
        return try JSONDecoder().decode(Catalog.self, from: data)
    }

    @Test("English is the source langauge")
    func englishIsTheSourceLanguage() throws {
        #expect(try loadCatalog().sourceLanguage == "en")
    }

    @Test("Every key ships both shipping languages")
    func everyKeyShipsBothLanguages() throws {
        for (key, entry) in try loadCatalog().strings {
            for language in ["en", "id"] {
                let values = entry.localizations[language]?.values ?? []

                #expect(!values.isEmpty, "\(key) has no \(language) value")
            }
        }
    }

    @Test("No translation is blank")
    func noTranslationIsBlank() throws {
        for (key, entry) in try loadCatalog().strings {
            for (language, localization) in entry.localizations {
                for value in localization.values {
                    #expect(!value.isEmpty, "\(key) is blank in \(language)")
                }
            }
        }
    }

    @Test("A key that takes arguments numbers them, so a translator can reorder")
    func argumentKeysArePositional() throws {
        for (key, entry) in try loadCatalog().strings where key.contains("%@") {
            for (language, localization) in entry.localizations {
                for value in localization.values where value.contains("%") {
                    #expect(
                        !value.contains("%@"),
                        "\(key) uses an unnumbered %@ in \(language): \(value)",
                    )
                }
            }
        }
    }
}
