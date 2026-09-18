import CoreText
import SwiftUI

public enum AppFont {
    public static let display = cormorant("Medium", size: 36, relativeTo: .title)
    public static let headline = Font.headline
    public static let subheadline = Font.subheadline
    public static let subheadlineStrong = Font.subheadline.weight(.semibold)
    public static let footnote = Font.footnote

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
