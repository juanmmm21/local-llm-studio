//
//  OllamaService.swift
//  local-llm-studio
//
//  Cliente HTTP asíncrono para la API local de Ollama.
//  Zero-Network: solo se comunica con localhost:11434. Ninguna petición
//  sale de la máquina del usuario.
//

import Foundation

/// Errores del cliente local de Ollama, con mensajes aptos para la UI.
enum OllamaServiceError: LocalizedError {
    /// No se pudo conectar: Ollama no está en ejecución en el Mac.
    case serverUnavailable
    /// El servidor respondió con un código HTTP inesperado.
    case unexpectedStatusCode(Int)
    /// La respuesta JSON no coincide con el contrato esperado.
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .serverUnavailable:
            return "No se pudo conectar con Ollama en localhost:11434. Asegúrate de que Ollama está en ejecución (`ollama serve`)."
        case .unexpectedStatusCode(let code):
            return "Ollama respondió con un código inesperado: \(code)."
        case .decodingFailed:
            return "No se pudo interpretar la respuesta de Ollama."
        }
    }
}

/// Servicio de acceso a la API REST local de Ollama.
///
/// Diseñado como `actor` para garantizar acceso concurrente seguro sin
/// bloquear el hilo principal; todas las llamadas usan `async/await`.
actor OllamaService {

    /// URL base del servidor local de Ollama.
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(host: String = "127.0.0.1", port: Int = 11434) {
        // Construida a partir de valores fijos locales: nunca apunta a internet.
        self.baseURL = URL(string: "http://\(host):\(port)")!

        // Configuración efímera: sin caché en disco ni cookies persistentes.
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.waitsForConnectivity = false
        self.session = URLSession(configuration: configuration)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(Self.decodeOllamaDate)
        self.decoder = decoder
    }

    // MARK: - API pública

    /// Lista los modelos instalados localmente en el Mac (`GET /api/tags`),
    /// ordenados por fecha de modificación descendente.
    func listLocalModels() async throws -> [OllamaModel] {
        let response: OllamaTagsResponse = try await get("/api/tags")
        return response.models.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    /// Comprueba si el servidor local de Ollama está disponible.
    func isServerRunning() async -> Bool {
        do {
            _ = try await listLocalModels()
            return true
        } catch {
            return false
        }
    }

    /// Envía una conversación al modelo indicado (`POST /api/chat`) y devuelve
    /// los fragmentos de texto generados como un stream asíncrono.
    ///
    /// Ollama responde en NDJSON (un objeto JSON por línea); cada línea se
    /// decodifica y se emite su `message.content` en cuanto llega, lo que
    /// permite pintar la respuesta token a token sin bloquear la UI.
    func streamChat(model: String, messages: [ChatMessage]) async throws -> AsyncThrowingStream<String, Error> {
        let url = baseURL.appending(path: "/api/chat")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // La generación puede tardar minutos en modelos grandes; el timeout
        // corto de la sesión solo debe aplicar a peticiones de metadatos.
        request.timeoutInterval = 600

        let body = OllamaChatRequest(
            model: model,
            messages: messages.map(\.asRequestMessage),
            stream: true
        )
        request.httpBody = try JSONEncoder().encode(body)

        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await session.bytes(for: request)
        } catch {
            throw OllamaServiceError.serverUnavailable
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaServiceError.serverUnavailable
        }
        guard httpResponse.statusCode == 200 else {
            throw OllamaServiceError.unexpectedStatusCode(httpResponse.statusCode)
        }

        let decoder = self.decoder
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await line in bytes.lines {
                        guard !line.isEmpty, let data = line.data(using: .utf8) else { continue }
                        let chunk: OllamaChatChunk
                        do {
                            chunk = try decoder.decode(OllamaChatChunk.self, from: data)
                        } catch {
                            throw OllamaServiceError.decodingFailed(error)
                        }
                        if let content = chunk.message?.content, !content.isEmpty {
                            continuation.yield(content)
                        }
                        if chunk.done {
                            break
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                // Cancela la lectura del socket si la UI deja de consumir
                // el stream (p. ej. el usuario pulsa "Detener").
                task.cancel()
            }
        }
    }

    // MARK: - Transporte

    private func get<Response: Decodable>(_ path: String) async throws -> Response {
        let url = baseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw OllamaServiceError.serverUnavailable
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaServiceError.serverUnavailable
        }
        guard httpResponse.statusCode == 200 else {
            throw OllamaServiceError.unexpectedStatusCode(httpResponse.statusCode)
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw OllamaServiceError.decodingFailed(error)
        }
    }

    // MARK: - Fechas

    /// Ollama serializa fechas con precisión de nanosegundos
    /// (p. ej. "2024-05-01T14:56:49.277302595+02:00"), que el
    /// `ISO8601DateFormatter` estándar no acepta. Se trunca la fracción
    /// a milisegundos antes de parsear.
    private static func decodeOllamaDate(_ decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: truncateFractionalSeconds(of: rawValue)) {
            return date
        }

        // Reintento sin fracción por si el servidor omite los decimales.
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: rawValue) {
            return date
        }

        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Formato de fecha no reconocido: \(rawValue)"
        )
    }

    /// Reduce la parte fraccionaria de una fecha ISO8601 a 3 dígitos.
    private static func truncateFractionalSeconds(of value: String) -> String {
        guard let dotIndex = value.firstIndex(of: ".") else { return value }
        let fractionStart = value.index(after: dotIndex)
        guard let fractionEnd = value[fractionStart...].firstIndex(where: { !$0.isNumber }) else {
            return value
        }
        let fraction = value[fractionStart..<fractionEnd].prefix(3)
        return String(value[..<dotIndex]) + "." + fraction + String(value[fractionEnd...])
    }
}
