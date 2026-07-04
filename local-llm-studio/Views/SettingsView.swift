//
//  SettingsView.swift
//  local-llm-studio
//
//  Ventana de Ajustes nativa (⌘,): conexión con Ollama y parámetros
//  de generación. Respaldada por UserDefaults con las mismas claves
//  que usa AppSettings.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage(AppSettings.Keys.host) private var host = "127.0.0.1"
    @AppStorage(AppSettings.Keys.port) private var port = 11434
    @AppStorage(AppSettings.Keys.systemPrompt) private var systemPrompt = ""
    @AppStorage(AppSettings.Keys.temperature) private var temperature = 0.8
    @AppStorage(AppSettings.Keys.contextWindow) private var contextWindow = 0

    var body: some View {
        TabView {
            connectionTab
                .tabItem { Label("Conexión", systemImage: "network") }
            generationTab
                .tabItem { Label("Generación", systemImage: "slider.horizontal.3") }
        }
        .frame(width: 480)
        .padding()
    }

    private var connectionTab: some View {
        Form {
            Section {
                TextField("Host", text: $host, prompt: Text("127.0.0.1"))
                TextField("Puerto", value: $port, format: .number.grouping(.never))
            } footer: {
                Text("Dirección del servidor de Ollama. Salvo configuraciones avanzadas, deja los valores por defecto (127.0.0.1:11434). Los cambios se aplican al instante.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var generationTab: some View {
        Form {
            Section("Instrucciones de sistema") {
                TextEditor(text: $systemPrompt)
                    .font(.body)
                    .frame(minHeight: 80)
                Text("Se envían al modelo al inicio de cada conversación. Útil para fijar idioma, tono o rol. Vacío = sin instrucciones.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Parámetros") {
                VStack(alignment: .leading) {
                    Slider(value: $temperature, in: 0...2, step: 0.1) {
                        Text("Temperatura: \(temperature, format: .number.precision(.fractionLength(1)))")
                    }
                    Text("Baja = respuestas precisas y repetibles. Alta = más creativas.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Picker("Ventana de contexto", selection: $contextWindow) {
                    Text("Por defecto del modelo").tag(0)
                    Text("4.096 tokens").tag(4096)
                    Text("8.192 tokens").tag(8192)
                    Text("16.384 tokens").tag(16384)
                    Text("32.768 tokens").tag(32768)
                }
                Text("Ventanas grandes permiten conversaciones y documentos más largos a costa de más memoria RAM.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    SettingsView()
}
