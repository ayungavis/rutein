import CoreText
import SwiftUI

public enum AppFont {
    public static let display = cormorant("SemiBold", size: 30, relativeTo: .title)
    public static let headline = Font.headline
    public static let body = Font.body
    public static let callout = Font.callout

    static let isCormorantRegistered: Bool = {
        guard let url = Bundle.module.url(forResource: "CormorantGaramond", withExtension: "ttf") else {
            return false
        }

        var error: Unmanaged<CFError>?

        if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
            return true
        }

        let code = error.map { CFErrorGetCode($0.takeRetainedValue()) }

        return code == CTFontManagerError.alreadyRegistered.rawValue
    }()

    private static func cormorant(_ weight: String, size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        guard isCormorantRegistered else {
            return .system(style, design: .serif)
        }

        return .custom("CormorantGaramond-\(weight)", size: size, relativeTo: style)
    }
}
