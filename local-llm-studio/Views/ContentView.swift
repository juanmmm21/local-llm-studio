//
//  ContentView.swift
//  local-llm-studio
//
//  Vista raíz provisional de la Fase 1: lista los modelos instalados
//  localmente mediante Ollama, con estados de carga fluidos.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = ModelListViewModel()

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView("Buscando modelos locales…")
                    .controlSize(.large)

            case .failed(let message):
                ContentUnavailableView {
                    Label("Ollama no disponible", systemImage: "bolt.horizontal.circle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Reintentar") {
                        Task { await viewModel.loadModels() }
                    }
                    .keyboardShortcut("r")
                }

            case .loaded where viewModel.models.isEmpty:
                ContentUnavailableView(
                    "Sin modelos instalados",
                    systemImage: "cpu",
                    description: Text("Descarga un modelo con `ollama pull llama3.2` y vuelve a intentarlo.")
                )

            case .loaded:
                modelList
            }
        }
        .animation(.default, value: viewModel.state)
        .frame(minWidth: 480, minHeight: 360)
        .navigationTitle("local-llm-studio")
        .task { await viewModel.loadModels() }
    }

    private var modelList: some View {
        List(viewModel.models) { model in
            VStack(alignment: .leading, spacing: 4) {
                Text(model.name)
                    .font(.headline)
                HStack(spacing: 12) {
                    if let family = model.details.family {
                        Label(family, systemImage: "brain")
                    }
                    if let parameters = model.details.parameterSize {
                        Label(parameters, systemImage: "slider.horizontal.3")
                    }
                    Label(model.formattedSize, systemImage: "internaldrive")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .refreshable { await viewModel.loadModels() }
    }
}

#Preview {
    ContentView()
}
