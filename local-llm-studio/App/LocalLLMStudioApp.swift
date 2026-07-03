//
//  LocalLLMStudioApp.swift
//  local-llm-studio
//
//  Punto de entrada de la aplicación. 100% local: la única red permitida
//  es HTTP hacia el servidor de Ollama en localhost.
//

import SwiftUI

@main
struct LocalLLMStudioApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.automatic)
    }
}
