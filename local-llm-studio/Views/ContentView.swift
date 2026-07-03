//
//  ContentView.swift
//  local-llm-studio
//
//  Vista raíz: sidebar con el historial de conversaciones persistido,
//  panel central de chat y selector de modelo en la barra superior.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChatSession.updatedAt, order: .reverse) private var sessions: [ChatSession]

    @State private var modelList = ModelListViewModel()
    @State private var chat = ChatViewModel()
    @State private var catalog = ModelCatalogViewModel()
    @State private var library = LibraryViewModel()

    @State private var selectedSession: ChatSession?
    @State private var selectedModel: OllamaModel?
    @State private var isCatalogPresented = false
    @State private var isLibraryPresented = false

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            ChatView(viewModel: chat, selectedModel: selectedModel)
        }
        .navigationTitle("local-llm-studio")
        .toolbar { toolbarContent }
        .sheet(isPresented: $isCatalogPresented) {
            ModelCatalogView(viewModel: catalog, installedModels: modelList.models)
        }
        .sheet(isPresented: $isLibraryPresented) {
            LibraryView(viewModel: library)
        }
        .onChange(of: selectedSession) {
            if let selectedSession {
                chat.attach(session: selectedSession)
            }
        }
        .task {
            chat.configure(context: modelContext)

            // Al terminar cada descarga del catálogo, refresca el sidebar
            // y selecciona un modelo si aún no había ninguno.
            catalog.onModelInstalled = {
                await modelList.loadModels()
                if selectedModel == nil {
                    selectedModel = modelList.models.first
                }
            }

            // Retoma la conversación más reciente o crea la primera.
            if selectedSession == nil {
                selectedSession = sessions.first ?? newSession()
            }

            await modelList.loadModels()
            if selectedModel == nil {
                selectedModel = modelList.models.first
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: $selectedSession) {
                Section("Conversaciones") {
                    ForEach(sessions) { session in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.title)
                                .lineLimit(1)
                            Text(session.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(session)
                        .contextMenu {
                            Button("Eliminar conversación", role: .destructive) {
                                delete(session)
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()
            serverStatusFooter
        }
    }

    /// Estado del servidor local de Ollama, siempre visible al pie.
    @ViewBuilder
    private var serverStatusFooter: some View {
        HStack(spacing: 8) {
            switch modelList.state {
            case .idle, .loading:
                ProgressView().controlSize(.mini)
                Text("Conectando con Ollama…")

            case .startingServer:
                ProgressView().controlSize(.mini)
                Text("Iniciando Ollama…")

            case .failed:
                Image(systemName: "bolt.horizontal.circle")
                    .foregroundStyle(.red)
                Text("Ollama no disponible")
                Spacer()
                Button("Reintentar") {
                    Task { await modelList.loadModels() }
                }
                .controlSize(.small)

            case .loaded where modelList.models.isEmpty:
                Image(systemName: "cpu")
                    .foregroundStyle(.orange)
                Text("Sin modelos")
                Spacer()
                Button("Catálogo") { isCatalogPresented = true }
                    .controlSize(.small)

            case .loaded:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("\(modelList.models.count) modelos locales")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Sesiones

    @discardableResult
    private func newSession() -> ChatSession {
        let session = ChatSession()
        modelContext.insert(session)
        try? modelContext.save()
        selectedSession = session
        return session
    }

    private func delete(_ session: ChatSession) {
        let wasSelected = session === selectedSession
        modelContext.delete(session)
        try? modelContext.save()
        if wasSelected {
            selectedSession = sessions.first(where: { $0 !== session }) ?? newSession()
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
                isLibraryPresented = true
            } label: {
                Label("Biblioteca", systemImage: "books.vertical")
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])
            .help("Biblioteca de documentos para RAG (⇧⌘L)")
        }

        ToolbarItem {
            Button {
                isCatalogPresented = true
            } label: {
                Label("Catálogo de modelos", systemImage: "arrow.down.circle")
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
            .help("Descargar nuevos modelos (⇧⌘D)")
        }

        ToolbarItem {
            Button {
                newSession()
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
        .modelContainer(for: [ChatSession.self, LibraryDocument.self], inMemory: true)
}
