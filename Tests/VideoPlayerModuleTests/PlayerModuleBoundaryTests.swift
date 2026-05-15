import Foundation
import Testing

@Suite("Player module boundary")
struct PlayerModuleBoundaryTests {
    @Test("Package source does not contain service app vocabulary")
    func packageSourceDoesNotContainServiceAppVocabulary() throws {
        let packageRoot = try Self.findPackageRoot()
        let sourceRoot = packageRoot.appendingPathComponent("Sources/VideoPlayerModule")
        let bannedTerms = [
            "SmartLearning",
            "MegaStudy",
            "SLLecture",
            "RemoteConfig",
            "QnA",
            "Megaling",
            "AISummary"
        ]
        let swiftFiles = FileManager.default.enumerator(
            at: sourceRoot,
            includingPropertiesForKeys: nil
        )?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" } ?? []

        var matches: [String] = []
        for file in swiftFiles {
            let source = try String(contentsOf: file, encoding: .utf8)
            for term in bannedTerms where source.contains(term) {
                matches.append("\(file.path): \(term)")
            }
        }

        if !matches.isEmpty {
            throw NSError(
                domain: "PlayerModuleBoundaryTests",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: matches.joined(separator: "\n")]
            )
        }
    }

    private static func findPackageRoot() throws -> URL {
        var current = URL(fileURLWithPath: #filePath)

        while current.path != "/" {
            current.deleteLastPathComponent()
            if FileManager.default.fileExists(
                atPath: current.appendingPathComponent("Package.swift").path
            ) {
                return current
            }
        }

        throw NSError(
            domain: "PlayerModuleBoundaryTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Package.swift not found"]
        )
    }
}
