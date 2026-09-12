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
    let stringUnit: CatalogUnit
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

    @Test("Every key carries an English value")
    func everyKeyCarriesEnglish() throws {
        for (key, entry) in try loadCatalog().strings {
            #expect(entry.localizations["en"] != nil, "\(key) has no English value")
        }
    }

    @Test("No translation is blank")
    func noTranslationIsBlank() throws {
        for (key, entry) in try loadCatalog().strings {
            for (language, localization) in entry.localizations {
                #expect(!localization.stringUnit.value.isEmpty, "\(key) is blank in \(language)")
            }
        }
    }
}
