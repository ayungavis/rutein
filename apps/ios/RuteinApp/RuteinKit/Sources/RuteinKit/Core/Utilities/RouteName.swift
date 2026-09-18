import Foundation

public enum RouteName {
    public static let maximumCharacters = 80

    public static func validated(_ raw: String) throws -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        guard (1 ... maximumCharacters).contains(trimmed.count) else {
            throw AppError.dataQuality
        }

        return trimmed
    }
}
