//
//  WebSearchService.swift
//  local-llm-studio
//
//  Búsqueda web opcional (Fase 4). Es el ÚNICO punto de la app que sale
//  a internet además de las descargas de modelos, y solo se ejecuta si
//  el usuario activa el interruptor de búsqueda web (off por defecto).
//
//  Usa el endpoint HTML de DuckDuckGo, que no requiere claves de API ni
//  cuentas, y se parsea de forma nativa sin dependencias externas.
//

import Foundation

/// Un resultado de búsqueda listo para inyectar como contexto.
struct WebSearchResult: Hashable, Sendable {
    let title: String
    let url: URL
    let snippet: String
}

enum WebSearchError: LocalizedError {
    case unavailable
    case noResults

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "No se pudo completar la búsqueda web. Comprueba tu conexión a internet."
        case .noResults:
            return "La búsqueda web no devolvió resultados."
        }
    }
}

actor WebSearchService {

    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        // DuckDuckGo rechaza el User-Agent por defecto de URLSession.
        configuration.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"
        ]
        session = URLSession(configuration: configuration)
    }

    /// Busca en la web y devuelve los primeros resultados con su resumen.
    func search(_ query: String, maxResults: Int = 4) async throws -> [WebSearchResult] {
        var components = URLComponents(string: "https://html.duckduckgo.com/html/")!
        components.queryItems = [URLQueryItem(name: "q", value: query)]

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: components.url!)
        } catch {
            throw WebSearchError.unavailable
        }

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let html = String(data: data, encoding: .utf8) else {
            throw WebSearchError.unavailable
        }

        let results = Self.parseResults(from: html, limit: maxResults)
        guard !results.isEmpty else {
            throw WebSearchError.noResults
        }
        return results
    }

    // MARK: - Parsing

    /// Extrae título, URL y resumen de cada resultado del HTML de DuckDuckGo.
    static func parseResults(from html: String, limit: Int) -> [WebSearchResult] {
        let links = matches(of: #"class="result__a"[^>]*href="([^"]+)"[^>]*>(.*?)</a>"#, in: html)
        let snippets = matches(of: #"class="result__snippet"[^>]*>(.*?)</a>"#, in: html)

        var results: [WebSearchResult] = []
        for (index, link) in links.enumerated() {
            guard results.count < limit, link.count >= 2 else { break }
            guard let url = resolveURL(from: link[0]) else { continue }

            let title = plainText(fromHTML: link[1])
            let snippet = index < snippets.count ? plainText(fromHTML: snippets[index][0]) : ""
            guard !title.isEmpty else { continue }

            results.append(WebSearchResult(title: title, url: url, snippet: snippet))
        }
        return results
    }

    /// DuckDuckGo a veces envuelve el destino en un enlace de redirección
    /// (/l/?uddg=<url codificada>); se extrae la URL real en ese caso.
    private static func resolveURL(from href: String) -> URL? {
        var absolute = href
        if absolute.hasPrefix("//") {
            absolute = "https:" + absolute
        } else if absolute.hasPrefix("/") {
            absolute = "https://duckduckgo.com" + absolute
        }

        guard let components = URLComponents(string: absolute) else { return nil }
        if components.path.hasPrefix("/l/"),
           let target = components.queryItems?.first(where: { $0.name == "uddg" })?.value {
            return URL(string: target)
        }
        return components.url
    }

    private static func matches(of pattern: String, in text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) else {
            return []
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).map { match in
            (1..<match.numberOfRanges).compactMap { index in
                Range(match.range(at: index), in: text).map { String(text[$0]) }
            }
        }
    }

    /// Elimina etiquetas HTML y decodifica las entidades más comunes.
    private static func plainText(fromHTML fragment: String) -> String {
        var text = fragment.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let entities: [String: String] = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"",
            "&#x27;": "'", "&#39;": "'", "&nbsp;": " "
        ]
        for (entity, character) in entities {
            text = text.replacingOccurrences(of: entity, with: character)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
