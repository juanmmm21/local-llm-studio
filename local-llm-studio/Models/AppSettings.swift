//
//  AppSettings.swift
//  local-llm-studio
//
//  Configuración de la app respaldada por UserDefaults. Las mismas claves
//  se usan desde la ventana de Ajustes (@AppStorage) y desde los servicios.
//

import Foundation

enum AppSettings {

    enum Keys {
        static let host = "settings.ollamaHost"
        static let port = "settings.ollamaPort"
        static let systemPrompt = "settings.systemPrompt"
        static let temperature = "settings.temperature"
        static let contextWindow = "settings.contextWindow"
    }

    private static var defaults: UserDefaults { .standard }

    /// Host del servidor de Ollama. Por defecto, la propia máquina.
    static var host: String {
        let value = defaults.string(forKey: Keys.host) ?? ""
        return value.isEmpty ? "127.0.0.1" : value
    }

    /// Puerto del servidor de Ollama.
    static var port: Int {
        let value = defaults.integer(forKey: Keys.port)
        return value > 0 ? value : 11434
    }

    static var baseURL: URL {
        URL(string: "http://\(host):\(port)") ?? URL(string: "http://127.0.0.1:11434")!
    }

    /// Instrucciones de sistema que se anteponen a cada conversación.
    static var systemPrompt: String {
        defaults.string(forKey: Keys.systemPrompt)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// Temperatura de muestreo (0 = determinista, 2 = muy creativo).
    static var temperature: Double {
        defaults.object(forKey: Keys.temperature) == nil
            ? 0.8
            : defaults.double(forKey: Keys.temperature)
    }

    /// Ventana de contexto en tokens. 0 = usar el valor propio del modelo.
    static var contextWindow: Int {
        defaults.integer(forKey: Keys.contextWindow)
    }
}
