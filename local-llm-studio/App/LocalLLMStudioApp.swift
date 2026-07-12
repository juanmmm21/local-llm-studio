//
//  LocalLLMStudioApp.swift
//  local-llm-studio
//
//  Punto de entrada de la aplicación. 100% local: la única red permitida
//  es HTTP hacia el servidor de Ollama en localhost.
//

import SwiftData
import SwiftUI

@main
struct LocalLLMStudioApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.automatic)
        .modelContainer(for: [ChatSession.self, LibraryDocument.self, WatchedFolder.self])

        Settings {
            SettingsView()
        }

        // Pregunta rápida desde la barra de menús, sin abrir la ventana
        // principal ni guardar historial.
        MenuBarExtra {
            QuickAskView()
        } label: {
            SlashIconView()
        }
        .menuBarExtraStyle(.window)
    }
}
