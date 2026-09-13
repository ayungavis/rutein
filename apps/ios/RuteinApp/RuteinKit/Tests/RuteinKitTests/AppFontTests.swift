import CoreText
import Foundation
import Testing
@testable import RuteinKit

@Suite("AppFont")
struct AppFontTests {
    @Test("The bundled font registers")
    func bundledFontRegisters() {
        #expect(AppFont.isCormorantRegistered)
    }

    @Test("Evvery weight AppFont names exists in the font file")
    func namedWeightResolve() {
        #expect(AppFont.isCormorantRegistered)

        for weight in ["Light", "Regular", "Medium", "SemiBold", "Bold"] {
            let name = "CormorantGaramond-\(weight)"
            let font = CTFontCreateWithName(name as CFString, 24, nil)

            #expect(CTFontCopyPostScriptName(font) as String == name)
        }
    }

    @Test("A misspelled weight does not silently resolve")
    func misspelledWeightFallsBack() {
        let font = CTFontCreateWithName("CormorantGaramond-Semibold" as CFString, 24, nil)

        #expect(CTFontCopyPostScriptName(font) as String != "CormorantGaramond-Semibold")
    }
}
