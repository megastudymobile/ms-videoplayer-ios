//
//  ShortURLResolverTests.swift
//  VideoPlayerExampleTests
//
//  Created by JunyoungJung on 2026/06/05.
//

import Testing
@testable import VideoPlayerExample

@Suite("ShortURLResolver 재생 URL 추출")
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

    @Test("Kollus launcher scheme에서 실제 /si 재생 URL 추출")
    func extractsPlaybackURLFromLauncherScheme() {
        let html = #"""
        <kollus-player-launcher :player-policy="{&quot;mobile&quot;:{&quot;scheme&quot;:{&quot;general&quot;:&quot;kollus:\/\/path?url=https%3A%2F%2Fv.kr.kollus.com%2Fsi%3Fjwt%3Dabc%26custom_key%3Dxyz%26normalized_hash%3DAF%25252F4D%25253D%25253D%26expire_time%3D30&quot;}}}}"></kollus-player-launcher>
        """#

        let url = ShortURLResolver.extractPlaybackURL(from: html)

        #expect(
            url?.absoluteString ==
                "https://v.kr.kollus.com/si?jwt=abc&custom_key=xyz&normalized_hash=AF%252F4D%253D%253D&expire_time=30"
        )
    }

    @Test("scheme_uri가 있으면 launcher scheme보다 우선 사용")
    func prefersSchemeURIWhenMultipleCandidatesExist() {
        let html = #"""
        {"scheme_uri&quot;:&quot;https:\/\/v.kr.kollus.com\/s?jwt=primary&amp;custom_key=one&quot;}
        <kollus-player-launcher :player-policy="{&quot;mobile&quot;:{&quot;scheme&quot;:{&quot;general&quot;:&quot;kollus:\/\/path?url=https%3A%2F%2Fv.kr.kollus.com%2Fsi%3Fjwt%3Dsecondary%26custom_key%3Dtwo&quot;}}}}"></kollus-player-launcher>
        """#

        let url = ShortURLResolver.extractPlaybackURL(from: html)

        #expect(url?.absoluteString == "https://v.kr.kollus.com/s?jwt=primary&custom_key=one")
    }

    @Test("빈 문자열 → nil")
    func returnsNilForEmpty() {
        #expect(ShortURLResolver.extractSchemeURI(from: "") == nil)
        #expect(ShortURLResolver.extractPlaybackURL(from: "") == nil)
    }
}
