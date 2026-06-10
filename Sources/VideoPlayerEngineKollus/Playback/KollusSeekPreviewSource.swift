//
//  KollusSeekPreviewSource.swift
//  VideoPlayerModule
//
//  Created by JunyoungJung on 2026/06/10.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import CoreGraphics
import Foundation
import UIKit

/// 스프라이트 썸네일 파일명 `{이름}.{tileW}x{tileH}x{count}.{확장자}`의 그리드 메타.
/// UIKit 이미지 로드와 분리된 순수 타입 — 파싱/인덱스 계산을 단독 테스트한다.
struct KollusThumbnailSpriteLayout: Equatable, Sendable {
    let tileWidth: Int
    let tileHeight: Int
    let tileCount: Int

    /// 파일명에서 메타를 파싱한다. 콘텐츠 이름에 `.`이 포함될 수 있으므로
    /// "확장자 바로 앞 컴포넌트"만 본다. 형식이 아니면 nil.
    init?(fileName: String) {
        let withoutExtension = (fileName as NSString).deletingPathExtension
        guard let token = withoutExtension.components(separatedBy: ".").last else { return nil }
        let parts = token.components(separatedBy: "x")
        guard parts.count == 3,
              let width = Int(parts[0]), width > 0,
              let height = Int(parts[1]), height > 0,
              let count = Int(parts[2]), count > 0 else { return nil }
        self.tileWidth = width
        self.tileHeight = height
        self.tileCount = count
    }

    /// 재생 시각 → 타일 인덱스. 항상 `0..<tileCount`로 클램프.
    func tileIndex(at time: TimeInterval, duration: TimeInterval) -> Int {
        guard duration > 0 else { return 0 }
        let raw = Int((time / duration) * Double(tileCount))
        return min(max(raw, 0), tileCount - 1)
    }

    /// 타일 인덱스 → 스프라이트 안 crop 영역(픽셀 좌표).
    func tileRect(at index: Int, columns: Int) -> CGRect {
        let safeColumns = max(1, columns)
        return CGRect(
            x: (index % safeColumns) * tileWidth,
            y: (index / safeColumns) * tileHeight,
            width: tileWidth,
            height: tileHeight
        )
    }
}

/// 스프라이트 시트를 1회 로드해 캐시하고, 시각에 해당하는 타일을 crop해 돌려준다.
/// 전용 actor — 대형 스프라이트 디코드가 adapter actor의 신호 파이프라인
/// (position 폴링·delegate 소비)을 막지 않도록 격리한다.
actor KollusSeekPreviewSource {
    nonisolated let path: String
    private let layout: KollusThumbnailSpriteLayout
    private var spriteCGImage: CGImage?
    /// 파일이 아직 다운로드 중이면 로드가 실패할 수 있다. 실패도 캐시해 스크럽 틱마다
    /// 디스크를 두드리지 않는다 — `.thumbnailReady` 신호가 source 자체를 무효화해 재시도시킨다.
    private var didAttemptLoad = false

    init?(thumbnailPath: String) {
        guard thumbnailPath.isEmpty == false,
              let layout = KollusThumbnailSpriteLayout(
                  fileName: (thumbnailPath as NSString).lastPathComponent
              ) else { return nil }
        self.path = thumbnailPath
        self.layout = layout
    }

    /// 재생 준비/`.thumbnailReady` 시점에 미리 디코드 — 첫 드래그에서 디코드 지연이 보이지 않게 한다.
    func warmUp() {
        _ = loadSpriteIfNeeded()
    }

    func previewImage(at time: TimeInterval, duration: TimeInterval) -> UIImage? {
        guard duration > 0, let sprite = loadSpriteIfNeeded() else { return nil }
        let columns = max(1, sprite.width / max(1, layout.tileWidth))
        let index = layout.tileIndex(at: time, duration: duration)
        let rect = layout.tileRect(at: index, columns: columns)
        guard let cropped = sprite.cropping(to: rect) else { return nil }
        return UIImage(cgImage: cropped)
    }

    private func loadSpriteIfNeeded() -> CGImage? {
        if didAttemptLoad { return spriteCGImage }
        didAttemptLoad = true
        guard let lazyImage = UIImage(contentsOfFile: path)?.cgImage else { return nil }
        Self.applyAtRestProtection(toPath: path)
        spriteCGImage = Self.decodedBitmap(from: lazyImage) ?? lazyImage
        return spriteCGImage
    }

    /// 스프라이트는 영상과 달리 DRM 없는 평문 이미지다 — 백업 추출/잠금 상태 포렌식으로
    /// 새지 않게 보호 클래스(`.complete`)와 백업 제외를 건다. 로드에 성공한 파일(다운로드
    /// 완료)에만 적용한다 — 쓰기 중인 파일에 걸면 잠금 중 SDK 쓰기가 실패할 수 있다.
    /// 보호는 최선 노력: 실패해도 프리뷰 동작에는 영향을 주지 않는다.
    static func applyAtRestProtection(toPath path: String, fileManager: FileManager = .default) {
        try? fileManager.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: path
        )
        var url = URL(fileURLWithPath: path)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }

    /// CGImage는 lazy decode라 첫 렌더 시점에 메인 스레드가 전체 스프라이트를 디코드해
    /// 첫 드래그가 멈춘다 — 이 actor의 executor에서 비트맵으로 강제 디코드해 둔다.
    /// 이후 crop은 디코드된 메모리 참조라 렌더 비용이 타일 크기로 줄어든다.
    private static func decodedBitmap(from image: CGImage) -> CGImage? {
        let context = CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                | CGBitmapInfo.byteOrder32Little.rawValue
        )
        guard let context else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return context.makeImage()
    }
}
