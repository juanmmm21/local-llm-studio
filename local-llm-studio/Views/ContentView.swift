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

    @State private var sessionSearchText = ""
    @State private var sessionToRename: ChatSession?
    @State private var renameDraft = ""
    @State private var sessionToExport: ChatSession?

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            if case .failed = modelList.state, !OllamaLauncher.isAppInstalled {
                // Primer arranque sin Ollama: guía en lugar de error.
                OnboardingView {
                    Task { await modelList.loadModels() }
                }
            } else {
                ChatView(viewModel: chat, selectedModel: selectedModel) { urls in
                    // Documentos soltados sobre el chat: a la biblioteca RAG,
                    // abriéndola para que se vea el progreso de indexación.
                    library.importDocuments(at: urls, context: modelContext)
                    isLibraryPresented = true
                }
            }
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

            // Al cambiar los modelos instalados (descarga o borrado),
            // refresca el sidebar y valida la selección actual.
            catalog.onModelsChanged = {
                await modelList.loadModels()
                normalizeModelSelection()
            }

            // Retoma la conversación más reciente o crea la primera.
            if selectedSession == nil {
                selectedSession = sessions.first ?? newSession()
            }

            await modelList.loadModels()
            normalizeModelSelection()

            // Deja listo el índice semántico de la biblioteca desde el
            // primer arranque, sin pasos manuales.
            await modelList.ensureEmbeddingModel()
        }
    }

    // MARK: - Sidebar

    /// Conversaciones filtradas por el texto de búsqueda: coincide con el
    /// título o con el contenido de cualquier mensaje del historial.
    private var filteredSessions: [ChatSession] {
        let query = sessionSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return sessions }
        return sessions.filter { session in
            session.title.localizedCaseInsensitiveContains(query)
                || session.messages.contains { $0.content.localizedCaseInsensitiveContains(query) }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: $selectedSession) {
                Section("Conversaciones") {
                    ForEach(filteredSessions) { session in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.title)
                                .lineLimit(1)
                            Text(session.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(session)
                        .contextMenu {
                            Button("Renombrar…") {
                                renameDraft = session.title
                                sessionToRename = session
                            }
                            Button("Exportar como Markdown…") {
                                sessionToExport = session
                            }
                            Button("Eliminar conversación", role: .destructive) {
                                delete(session)
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .searchable(text: $sessionSearchText, placement: .sidebar, prompt: "Buscar en el historial")
            .overlay {
                if filteredSessions.isEmpty && !sessionSearchText.isEmpty {
                    ContentUnavailableView.search(text: sessionSearchText)
                }
            }

            Divider()
            serverStatusFooter
        }
        .fileExporter(
            isPresented: Binding(
                get: { sessionToExport != nil },
                set: { if !$0 { sessionToExport = nil } }
            ),
            document: MarkdownFile(text: sessionToExport.map(ConversationExporter.markdown) ?? ""),
            contentType: .plainText,
            defaultFilename: sessionToExport.map(ConversationExporter.suggestedFileName).map { $0 + ".md" }
        ) { _ in
            sessionToExport = nil
        }
        .alert("Renombrar conversación", isPresented: Binding(
            get: { sessionToRename != nil },
            set: { if !$0 { sessionToRename = nil } }
        )) {
            TextField("Título", text: $renameDraft)
            Button("Guardar") {
                let title = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                if let sessionToRename, !title.isEmpty {
                    sessionToRename.title = title
                    try? modelContext.save()
                }
                sessionToRename = nil
            }
            Button("Cancelar", role: .cancel) { sessionToRename = nil }
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

            case .loaded where modelList.isInstallingEmbedder:
                ProgressView().controlSize(.mini)
                Text("Preparando índice semántico…")
                    .help("Descargando nomic-embed-text para la biblioteca RAG")

            case .loaded:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("\(modelList.chatModels.count) modelos locales")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Garantiza que el modelo seleccionado sigue instalado y es de chat;
    /// si no, selecciona el primero disponible.
    private func normalizeModelSelection() {
        if let selectedModel, modelList.chatModels.contains(selectedModel) {
            return
        }
        selectedModel = modelList.chatModels.first
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
                ForEach(modelList.chatModels) { model in
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
