//
//  ChatView.swift
//  local-llm-studio
//
//  Panel central de conversación: historial con auto-scroll durante el
//  streaming y campo de entrada con botón de enviar/detener.
//

import SwiftUI
import UniformTypeIdentifiers

struct ChatView: View {
    @Bindable var viewModel: ChatViewModel
    let selectedModel: OllamaModel?
    /// Recibe los documentos (PDF, TXT, MD) soltados sobre el chat para
    /// añadirlos a la biblioteca RAG.
    var onDropDocuments: ([URL]) -> Void = { _ in }

    @State private var isImageImporterPresented = false
    @State private var isDropTargeted = false

    private static let imageExtensions: Set<String> = ["png", "jpg", "jpeg"]

    var body: some View {
        VStack(spacing: 0) {
            messageHistory
            Divider()
            composer
        }
        .dropDestination(for: URL.self) { urls, _ in
            handleDrop(of: urls)
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .background(Color.accentColor.opacity(0.08))
                    .overlay {
                        Label("Suelta imágenes para el mensaje o documentos para la biblioteca", systemImage: "arrow.down.doc")
                            .font(.headline)
                            .padding(12)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(8)
                    .allowsHitTesting(false)
            }
        }
    }

    /// Reparte lo soltado: imágenes al borrador del mensaje, documentos
    /// compatibles a la biblioteca. La lectura de la imagen es inmediata
    /// por el permiso efímero del sandbox.
    private func handleDrop(of urls: [URL]) -> Bool {
        var handled = false
        var documents: [URL] = []

        for url in urls {
            let ext = url.pathExtension.lowercased()
            if Self.imageExtensions.contains(ext) {
                let accessGranted = url.startAccessingSecurityScopedResource()
                defer { if accessGranted { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url) {
                    viewModel.draftImage = data
                    handled = true
                }
            } else if DocumentIndexer.supportedExtensions.contains(ext) {
                documents.append(url)
            }
        }

        if !documents.isEmpty {
            onDropDocuments(documents)
            handled = true
        }
        return handled
    }

    // MARK: - Historial

    private var messageHistory: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if viewModel.messages.isEmpty {
                        emptyState
                    }
                    ForEach(viewModel.messages) { message in
                        MessageBubbleView(
                            message: message,
                            isStreaming: viewModel.isGenerating && message.id == viewModel.messages.last?.id
                        )
                        .id(message.id)
                        .contextMenu {
                            Button("Copiar texto") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(message.content, forType: .string)
                            }
                            if message.role == .user && !viewModel.isGenerating {
                                Button("Editar y reenviar") {
                                    viewModel.editAndResend(message)
                                }
                            }
                        }
                    }

                    if viewModel.canRegenerate, let model = selectedModel {
                        Button {
                            viewModel.regenerate(model: model.name)
                        } label: {
                            Label("Regenerar respuesta", systemImage: "arrow.clockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Descarta la última respuesta y genera otra con \(model.name)")
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.messages.last?.content) {
                // Auto-scroll mientras llegan tokens del modelo local.
                if let lastID = viewModel.messages.last?.id {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "Conversación privada",
            systemImage: "lock.shield",
            description: Text("Todo se procesa en tu Mac. Elige un modelo y escribe tu primer mensaje.")
        )
        .padding(.top, 80)
    }

    // MARK: - Entrada

    private var composer: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let errorMessage = viewModel.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if let imageData = viewModel.draftImage, let preview = NSImage(data: imageData) {
                HStack(alignment: .top, spacing: 6) {
                    Image(nsImage: preview)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Button {
                        viewModel.draftImage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Quitar la imagen")
                }
            }

            HStack(alignment: .bottom, spacing: 8) {
                Toggle(isOn: $viewModel.useLibrary) {
                    Image(systemName: viewModel.useLibrary ? "books.vertical.fill" : "books.vertical")
                }
                .toggleStyle(.button)
                .buttonStyle(.borderless)
                .help(viewModel.useLibrary
                      ? "El asistente consultará tu biblioteca local (RAG)"
                      : "Biblioteca desactivada para esta conversación")
                .padding(.bottom, 6)

                Toggle(isOn: $viewModel.isWebSearchEnabled) {
                    Image(systemName: "globe")
                        .foregroundStyle(viewModel.isWebSearchEnabled ? Color.accentColor : Color.secondary)
                }
                .toggleStyle(.button)
                .buttonStyle(.borderless)
                .help(viewModel.isWebSearchEnabled
                      ? "Búsqueda web activada: tus preguntas se enviarán a DuckDuckGo para buscar contexto"
                      : "Búsqueda web desactivada: todo se procesa en tu Mac")
                .padding(.bottom, 6)

                Button {
                    isImageImporterPresented = true
                } label: {
                    Image(systemName: "photo.badge.plus")
                }
                .buttonStyle(.borderless)
                .help("Adjuntar una imagen (requiere un modelo con visión, como LLaVA)")
                .padding(.bottom, 6)
                .fileImporter(
                    isPresented: $isImageImporterPresented,
                    allowedContentTypes: [.png, .jpeg]
                ) { result in
                    guard case .success(let url) = result else { return }
                    // Lectura inmediata dentro del ámbito de seguridad del sandbox.
                    let accessGranted = url.startAccessingSecurityScopedResource()
                    defer { if accessGranted { url.stopAccessingSecurityScopedResource() } }
                    viewModel.draftImage = try? Data(contentsOf: url)
                }

                TextField(
                    selectedModel.map { "Mensaje para \($0.name)…" } ?? "Selecciona un modelo para empezar",
                    text: $viewModel.draft,
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .lineLimit(1...8)
                .padding(10)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
                .onSubmit(sendDraft)
                .disabled(selectedModel == nil)

                if viewModel.isGenerating {
                    Button {
                        viewModel.stopGeneration()
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    .help("Detener la generación")
                } else {
                    Button(action: sendDraft) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(viewModel.canSend && selectedModel != nil ? Color.accentColor : Color.secondary)
                    .disabled(!viewModel.canSend || selectedModel == nil)
                    .keyboardShortcut(.return, modifiers: .command)
                    .help("Enviar (⌘↩)")
                }
            }
        }
        .padding(12)
    }

    private func sendDraft() {
        guard let model = selectedModel, viewModel.canSend else { return }
        viewModel.send(to: model.name)
    }
}
