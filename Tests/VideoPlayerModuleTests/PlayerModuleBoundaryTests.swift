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
            "AISummary",
            // Core 도메인에 벤더 케이스 재유입 금지 (PlaybackSource는 .mediaKey로 중립화됨)
            "case kollus"
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

    @Test("Kollus AI 배속 설정은 setter 메서드를 사용")
    func kollusAIRateUsesSetter() throws {
        let packageRoot = try Self.findPackageRoot()
        let adapterURL = packageRoot.appendingPathComponent("Sources/VideoPlayerEngineKollus/KollusPlayerAdapter.swift")
        let source = try String(contentsOf: adapterURL, encoding: .utf8)
        let forbiddenAssignment = "aiRateEnable = " + "environment.aiPlaybackRateEnabled"

        #expect(source.contains("setAIRate(environment.aiPlaybackRateEnabled)"))
        #expect(source.contains(forbiddenAssignment) == false)
    }

    @Test("Example 앱은 background audio mode를 선언")
    func exampleAppDeclaresBackgroundAudioMode() throws {
        let packageRoot = try Self.findPackageRoot()
        let projectURL = packageRoot.appendingPathComponent("Project.swift")
        let source = try String(contentsOf: projectURL, encoding: .utf8)

        #expect(source.contains("\"UIBackgroundModes\""))
        #expect(source.contains("\"audio\""))
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
