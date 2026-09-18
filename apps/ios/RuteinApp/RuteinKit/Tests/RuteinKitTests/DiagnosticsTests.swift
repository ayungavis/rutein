import Darwin
import Foundation
import SwiftUI
import Testing
@testable import RuteinKit

@MainActor
@Suite("Diagnostics")
struct DiagnosticsTests {
    private static let secrets = [
        "Mount Agung via Pura Pengubengan",
        "-8.363483",
        "115.461238",
        "/private/var/mobile/Containers/Shared/AppGroup/route.gpx",
    ]

    @Test("Every error category is a fixed word, never anything a file supplied")
    func errorCategoriesAreFixedWords() {
        let categories = [
            AppError.access, .format, .geometry, .capacity,
            .dataQuality, .storage, .rendering, .export, .cancelled,
        ].map(\.category)

        #expect(Set(categories).count == 9)
        #expect(categories.allSatisfy { $0.allSatisfy(\.isLetter) })
    }

    @Test("A failure's own description never carries the route it failed on")
    func errorDescriptionsCarryNoRouteData() {
        for secret in Self.secrets {
            for error in [AppError.access, .format, .geometry, .capacity, .storage] {
                #expect(!error.localizedDescription.contains(secret))
                #expect(!error.category.contains(secret))
            }
        }
    }

    @Test("Every import failure the user can see is a fixed catalogue key")
    func importFailureCopyIsAlwaysAFixedKey() {
        let known: [LocalizedStringKey] = [
            "import.failed.access",
            "import.failed.format",
            "import.failed.geometry",
            "import.failed.capacity",
            "import.failed.unknown",
        ]

        for error in [
            AppError.access, .format, .geometry, .capacity,
            .dataQuality, .storage, .rendering, .export, .cancelled,
        ] {
            let copy = RouteLibraryViewModel.importFailureKey(for: error)

            #expect(known.contains(copy), "\(error.category) produced unexpected copy")
        }
    }

    @Test("A stage measurement returns its value and rethrows its failure")
    func measurementIsTransparent() async throws {
        let value = await Log.measure(.parsing, count: 3) { 42 }

        #expect(value == 42)

        await #expect(throws: AppError.export) {
            try await Log.measure(.export) {
                throw AppError.export
            }
        }
    }

    @Test("An operation identifier is ephemeral and reveals nothing")
    func operationIdentifiersAreEphemeral() {
        let identifiers = (0 ..< 64).map { _ in Log.newOperationID() }

        #expect(Set(identifiers).count > 1)
        #expect(identifiers.allSatisfy { $0.count == 8 })
        #expect(identifiers.allSatisfy { $0.allSatisfy(\.isHexDigit) })
    }
}

@Suite("Off-main execution")
struct OffMainExecutionTests {
    private static var onMainThread: Bool {
        pthread_main_np() != 0
    }

    @concurrent
    private static func concurrentThread() async -> Bool {
        onMainThread
    }

    private static func inheritedThread() async -> Bool {
        onMainThread
    }

    @MainActor
    @Test("A @concurrent function leaves the main actor; a plain async one inherits it")
    func concurrentLeavesTheMainActor() async {
        #expect(Self.onMainThread)
        #expect(await Self.concurrentThread() == false)
        #expect(await Self.inheritedThread() == true)
    }
}
