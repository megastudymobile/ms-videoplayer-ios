import Foundation
import Testing

@Suite("Player module 경계 검증")
struct PlayerModuleBoundaryTests {
    @Test("Package source에 서비스 앱 용어가 포함되지 않음")
    func packageSourceDoesNotContainServiceAppVocabulary() throws {
        let packageRoot = try Self.findPackageRoot()
        // 재사용 패키지의 모든 타겟(Core/ShellSupport/Engine*/Skin)을 스캔한다.
        let sourceRoot = packageRoot.appendingPathComponent("Sources")
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
