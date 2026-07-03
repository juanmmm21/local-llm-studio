//
//  ContentView.swift
//  local-llm-studio
//
//  Vista raíz: sidebar con los modelos locales instalados, panel central
//  de chat y selector de modelo en la barra de herramientas.
//

import SwiftUI

struct ContentView: View {
    @State private var modelList = ModelListViewModel()
    @State private var chat = ChatViewModel()
    @State private var selectedModel: OllamaModel?

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            ChatView(viewModel: chat, selectedModel: selectedModel)
        }
        .navigationTitle("local-llm-studio")
        .toolbar { toolbarContent }
        .task {
            await modelList.loadModels()
            // Preselecciona el modelo más reciente para poder chatear ya.
            if selectedModel == nil {
                selectedModel = modelList.models.first
            }
        }
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var sidebar: some View {
        switch modelList.state {
        case .idle, .loading:
            ProgressView("Buscando modelos locales…")
                .frame(maxHeight: .infinity)

        case .startingServer:
            ProgressView("Iniciando Ollama en segundo plano…")
                .frame(maxHeight: .infinity)

        case .failed(let message):
            ContentUnavailableView {
                Label("Ollama no disponible", systemImage: "bolt.horizontal.circle")
            } description: {
                Text(message)
            } actions: {
                Button("Reintentar") {
                    Task { await modelList.loadModels() }
                }
                .keyboardShortcut("r")
            }

        case .loaded where modelList.models.isEmpty:
            ContentUnavailableView(
                "Sin modelos instalados",
                systemImage: "cpu",
                description: Text("Descarga un modelo con `ollama pull llama3.2` y vuelve a intentarlo.")
            )

        case .loaded:
            List(modelList.models, selection: $selectedModel) { model in
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.name)
                        .font(.headline)
                    HStack(spacing: 10) {
                        if let parameters = model.details.parameterSize {
                            Label(parameters, systemImage: "slider.horizontal.3")
                        }
                        Label(model.formattedSize, systemImage: "internaldrive")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .tag(model)
            }
            .listStyle(.sidebar)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Picker("Modelo", selection: $selectedModel) {
                Text("Sin modelo").tag(OllamaModel?.none)
                ForEach(modelList.models) { model in
                    Text(model.name).tag(Optional(model))
                }
            }
            .pickerStyle(.menu)
            .frame(minWidth: 180)
            .help("Modelo local activo")
        }

        ToolbarItem {
            Button {
                chat.clearConversation()
            } label: {
                Label("Nueva conversación", systemImage: "square.and.pencil")
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .help("Nueva conversación (⇧⌘N)")
        }

        ToolbarItem {
            Button {
                Task { await modelList.loadModels() }
            } label: {
                Label("Recargar modelos", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r")
            .help("Recargar modelos locales (⌘R)")
        }
    }
}

#Preview {
    ContentView()
}
