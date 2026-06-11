//
//  PlayerSeekPreviewPresenter.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/06/10.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import UIKit

/// 스크럽 프리뷰 모달의 표시/이동/이미지 로드 상태머신.
/// AssembledPlayerSkin 내부 협력자 — 액션 가로채기(begin/move/request/end)로만 구동된다.
@MainActor
final class PlayerSeekPreviewPresenter {
    let view = PlayerSeekPreviewView()

    /// host가 주입하는 썸네일 공급자. nil이면 라벨-only 모달로 동작.
    var imageProvider: ((TimeInterval) async -> UIImage?)?
    /// false면 begin()이 무시된다(모달 자체가 뜨지 않음).
    var isEnabled = true

    private(set) var isActive = false
    private var inflightTask: Task<Void, Never>?
    /// in-flight 중 도착한 최신 요청 시각 — 완료 후 1건으로 합쳐 요청한다.
    private var pendingRequestTime: TimeInterval?
    /// 세션 종료/취소 후 늦게 끝난 요청이 상태를 만지지 못하게 하는 세대 토큰.
    private var requestGeneration = 0
    /// 이미지 도착으로 모달 크기가 바뀔 때 같은 anchor로 재배치하기 위한 마지막 위치.
    private var lastAnchor: CGPoint?
    private var lastBounds: CGRect = .zero

    private enum Metric {
        static let edgeMargin: CGFloat = 8
        static let anchorGap: CGFloat = 8
        static let fadeDuration: TimeInterval = 0.15
        /// 연속 nil 응답이 이 횟수에 도달해야 placeholder를 컴팩트로 축소한다 —
        /// 공급 준비 지연(스프라이트 다운로드/디코드 중)을 실패로 단정하지 않기 위한 유예.
        static let nilCollapseThreshold = 4
    }

    private var consecutiveNilResponses = 0

    init() {
        view.alpha = 0
        view.isHidden = true
    }

    func begin() {
        guard isEnabled else { return }
        isActive = true
        consecutiveNilResponses = 0
        view.beginSession(showsPlaceholder: imageProvider != nil)
        view.isHidden = false
        UIView.animate(withDuration: Metric.fadeDuration) { self.view.alpha = 1 }
    }

    /// 매 스크럽 틱 호출 — 시간 라벨 갱신 + 모달 frame 재배치.
    func move(time: TimeInterval, anchor: CGPoint, in bounds: CGRect) {
        guard isActive else { return }
        view.setTime(PlayerSkinState.formatTime(time))
        lastAnchor = anchor
        lastBounds = bounds
        reposition()
    }

    /// throttle된 틱에서 호출. cancel 후 재생성 대신 in-flight 1건 + 최신 시각 coalescing —
    /// 공급 지연(스프라이트 미준비) 중 요청이 엔진으로 폭주해 메인 스레드 hop이 쌓이는 것을 막는다.
    func requestImage(at time: TimeInterval) {
        guard isActive, imageProvider != nil else { return }
        if inflightTask != nil {
            pendingRequestTime = time
            return
        }
        startImageRequest(at: time)
    }

    private func startImageRequest(at time: TimeInterval) {
        guard let imageProvider else { return }
        requestGeneration += 1
        let generation = requestGeneration
        inflightTask = Task { [weak self] in
            let image = await imageProvider(time)
            guard let self, generation == self.requestGeneration else { return }
            self.inflightTask = nil
            guard self.isActive else {
                self.pendingRequestTime = nil
                return
            }
            if image == nil {
                self.consecutiveNilResponses += 1
                // 유예 도달 전의 nil은 view에 전달하지 않는다 — placeholder 유지.
                if self.consecutiveNilResponses >= Metric.nilCollapseThreshold {
                    self.view.setImage(nil)
                    self.reposition()
                }
            } else {
                self.consecutiveNilResponses = 0
                self.view.setImage(image)
                // placeholder ↔ 이미지/컴팩트 전환 시 크기가 바뀐다 — 같은 anchor로 재배치.
                self.reposition()
            }
            if let pending = self.pendingRequestTime {
                self.pendingRequestTime = nil
                self.startImageRequest(at: pending)
            }
        }
    }

    func end() {
        isActive = false
        requestGeneration += 1
        inflightTask?.cancel()
        inflightTask = nil
        pendingRequestTime = nil
        lastAnchor = nil
        UIView.animate(
            withDuration: Metric.fadeDuration,
            animations: { self.view.alpha = 0 },
            completion: { _ in
                if self.isActive == false { self.view.isHidden = true }
            }
        )
    }

    private func reposition() {
        guard let anchor = lastAnchor else { return }
        let size = view.contentSize
        let halfWidth = size.width / 2
        let minX = halfWidth + Metric.edgeMargin
        let maxX = lastBounds.width - halfWidth - Metric.edgeMargin
        let centerX = maxX < minX ? lastBounds.midX : min(max(anchor.x, minX), maxX)
        let centerY = max(anchor.y - size.height / 2 - Metric.anchorGap, size.height / 2 + Metric.edgeMargin)
        view.bounds = CGRect(origin: .zero, size: size)
        view.center = CGPoint(x: centerX, y: centerY)
    }
}
