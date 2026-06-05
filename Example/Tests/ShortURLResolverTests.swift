//
//  ShortURLResolverTests.swift
//  VideoPlayerExampleTests
//
//  Created by JunyoungJung on 2026/06/05.
//

import Testing
@testable import VideoPlayerExample

@Suite("ShortURLResolver scheme_uri 추출")
struct ShortURLResolverTests {
    @Test("HTML 엔티티 인코딩된 scheme_uri 추출 + 디코드")
    func extractsAndDecodesSchemeURI() {
        let html = #"""
        {"result":{"scheme_uri&quot;:&quot;https:\/\/v.kr.kollus.com\/s?jwt=abc&amp;custom_key=xyz&quot;,"other":1}}
        """#
        // 샘플 앱 정규식 패턴과 동일한 입력 형태 (scheme_uri&quot;:&quot;...&quot;)
        let url = ShortURLResolver.extractSchemeURI(from: html)

        #expect(url?.absoluteString == "https://v.kr.kollus.com/s?jwt=abc&custom_key=xyz")
    }

    @Test("scheme_uri 없는 HTML → nil")
    func returnsNilWhenMissing() {
        let html = "<html><body>no player data</body></html>"

        #expect(ShortURLResolver.extractSchemeURI(from: html) == nil)
    }

    @Test("빈 문자열 → nil")
    func returnsNilForEmpty() {
        #expect(ShortURLResolver.extractSchemeURI(from: "") == nil)
    }
}
