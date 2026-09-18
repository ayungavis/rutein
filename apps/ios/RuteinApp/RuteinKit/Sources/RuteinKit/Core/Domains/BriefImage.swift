import SwiftUI

public enum BriefImage: Sendable {
    case ready(Image)
    case timelineTooLong
    case failed(AppError)

    public var image: Image? {
        guard case let .ready(image) = self else {
            return nil
        }

        return image
    }

    public var explanation: LocalizedStringKey? {
        switch self {
        case .ready: nil
        case .timelineTooLong: "brief.share.image.tooLong"
        case .failed: "brief.share.image.failed"
        }
    }
}
