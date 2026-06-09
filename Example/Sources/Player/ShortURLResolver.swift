//
//  ShortURLResolver.swift
//  VideoPlayerExample
//
//  Created by JunyoungJung on 2026/06/05.
//
//  Kollus short URL의 HTML에서 scheme_uri(서명된 재생 URL)를 추출한다.
//  샘플 앱 AppDelegate.autoPlayFromShortURL / extractSchemeURI 로직 이식.
//

import Foundation

struct ShortURLResolver {
    enum ResolveError: LocalizedError {
        case invalidURL
        case httpError(statusCode: Int)
        case htmlDecodingFailed
        case schemeURINotFound

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "short URL 형식이 올바르지 않습니다."
            case .httpError(let statusCode):
                return "short URL 요청 실패 (HTTP \(statusCode))."
            case .htmlDecodingFailed:
                return "short URL 응답을 해석할 수 없습니다."
            case .schemeURINotFound:
                return "응답에서 재생 URL(scheme_uri)을 찾지 못했습니다."
            }
        }
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func resolve(_ shortURLString: String) async throws -> URL {
        guard let shortURL = URL(string: shortURLString) else {
            throw ResolveError.invalidURL
        }
        var request = URLRequest(url: shortURL)
        request.setValue("Mozilla/5.0 (iPhone)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           (200..<300).contains(httpResponse.statusCode) == false {
            throw ResolveError.httpError(statusCode: httpResponse.statusCode)
        }
        guard let html = String(data: data, encoding: .utf8) else {
            throw ResolveError.htmlDecodingFailed
        }
        guard let streamingURL = Self.extractPlaybackURL(from: html) else {
            throw ResolveError.schemeURINotFound
        }
        return streamingURL
    }

    static func extractPlaybackURL(from html: String) -> URL? {
        extractSchemeURI(from: html) ?? extractLauncherPlaybackURL(from: html)
    }

    /// HTML 내 JSON의 "scheme_uri" 값(HTML 엔티티 인코딩)을 추출·디코드해 반환.
    static func extractSchemeURI(from html: String) -> URL? {
        guard let regex = try? NSRegularExpression(pattern: "scheme_uri&quot;:&quot;(.+?)&quot;") else {
            return nil
        }
        let range = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, options: [], range: range),
              let valueRange = Range(match.range(at: 1), in: html) else {
            return nil
        }

        var value = String(html[valueRange])
        value = value.replacingOccurrences(of: "\\/", with: "/")
        value = value.replacingOccurrences(of: "&amp;", with: "&")
        return URL(string: value)
    }

    /// `/s?jwt=...` 페이지의 launcher scheme에서 SDK가 사용할 `/si?...` 재생 URL을 추출한다.
    static func extractLauncherPlaybackURL(from html: String) -> URL? {
        let decodedHTML = html
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "\\/", with: "/")
            .replacingOccurrences(of: "&amp;", with: "&")

        guard let regex = try? NSRegularExpression(pattern: ##"kollus://path\?url=([^"#]+)"##) else {
            return nil
        }
        let range = NSRange(decodedHTML.startIndex..., in: decodedHTML)
        guard let match = regex.firstMatch(in: decodedHTML, options: [], range: range),
              let valueRange = Range(match.range(at: 1), in: decodedHTML) else {
            return nil
        }

        let encodedURLString = String(decodedHTML[valueRange])
        return encodedURLString.removingPercentEncoding.flatMap(URL.init(string:))
    }
}
