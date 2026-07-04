//
//  OllamaLauncher.swift
//  local-llm-studio
//
//  Arranque automático de la app de Ollama en segundo plano cuando el
//  servidor local no está en ejecución. Usa NSWorkspace (AppKit nativo),
//  compatible con el sandbox: solo abre una app ya instalada en el Mac.
//

import AppKit

enum OllamaLauncher {

    /// Resultado del intento de arranque, para decidir qué mostrar en la UI.
    enum LaunchResult {
        case launched
        case notInstalled
    }

    /// `true` si la app de escritorio de Ollama está instalada en el Mac.
    static var isAppInstalled: Bool {
        candidateURLs.contains { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// Rutas habituales donde vive la app de escritorio de Ollama.
    private static var candidateURLs: [URL] {
        var urls = [URL(filePath: "/Applications/Ollama.app")]
        if let home = FileManager.default.homeDirectoryForCurrentUser as URL? {
            urls.append(home.appending(path: "Applications/Ollama.app"))
        }
        return urls
    }

    /// Abre Ollama.app en segundo plano (sin activarla ni robar el foco).
    /// La propia app de Ollama levanta el servidor en localhost:11434.
    @MainActor
    static func launchInBackground() async -> LaunchResult {
        guard let appURL = candidateURLs.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            return .notInstalled
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.hides = true
        configuration.addsToRecentItems = false

        do {
            _ = try await NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
            return .launched
        } catch {
            return .notInstalled
        }
    }
}
