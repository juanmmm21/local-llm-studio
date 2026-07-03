//
//  ChatView.swift
//  local-llm-studio
//
//  Panel central de conversación: historial con auto-scroll durante el
//  streaming y campo de entrada con botón de enviar/detener.
//

import SwiftUI

struct ChatView: View {
    @Bindable var viewModel: ChatViewModel
    let selectedModel: OllamaModel?

    var body: some View {
        VStack(spacing: 0) {
            messageHistory
            Divider()
            composer
        }
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

            HStack(alignment: .bottom, spacing: 8) {
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
