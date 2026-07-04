//
//  QuickAskView.swift
//  local-llm-studio
//
//  Pregunta rápida desde la barra de menús: una consulta puntual al
//  modelo local sin abrir la ventana principal ni guardar historial.
//

import SwiftUI

struct QuickAskView: View {
    @State private var question = ""
    @State private var answer = ""
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var models: [OllamaModel] = []
    @State private var selectedModel: String?
    @State private var generationTask: Task<Void, Never>?

    private let service = OllamaService()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Pregunta rápida", systemImage: "bolt.fill")
                    .font(.headline)
                Spacer()
                if !models.isEmpty {
                    Picker("Modelo", selection: $selectedModel) {
                        ForEach(models) { model in
                            Text(model.name).tag(Optional(model.name))
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                    .frame(maxWidth: 160)
                }
            }

            HStack(spacing: 8) {
                TextField("Pregunta al modelo local…", text: $question)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(ask)
                    .disabled(isGenerating || selectedModel == nil)

                if isGenerating {
                    Button {
                        generationTask?.cancel()
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: ask) {
                        Image(systemName: "arrow.up.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(canAsk ? Color.accentColor : Color.secondary)
                    .disabled(!canAsk)
                }
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if !answer.isEmpty || isGenerating {
                Divider()
                ScrollView {
                    if answer.isEmpty {
                        ProgressView()
                            .controlSize(.small)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 12)
                    } else {
                        MessageContentView(content: answer)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxHeight: 260)

                if !answer.isEmpty && !isGenerating {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(answer, forType: .string)
                    } label: {
                        Label("Copiar respuesta", systemImage: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            }

            Divider()

            HStack {
                Text(models.isEmpty ? "Ollama no disponible" : "Se procesa en tu Mac, sin historial")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Abrir la app") {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.windows.first { $0.canBecomeMain }?.makeKeyAndOrderFront(nil)
                }
                .controlSize(.small)
            }
        }
        .padding(14)
        .frame(width: 380)
        .task {
            await loadModels()
        }
    }

    private var canAsk: Bool {
        !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && selectedModel != nil
            && !isGenerating
    }

    private func loadModels() async {
        let all = (try? await service.listLocalModels()) ?? []
        models = all.filter { !$0.name.localizedCaseInsensitiveContains("embed") }
        if selectedModel == nil || !models.contains(where: { $0.name == selectedModel }) {
            selectedModel = models.first?.name
        }
    }

    private func ask() {
        guard canAsk, let model = selectedModel else { return }
        let prompt = question.trimmingCharacters(in: .whitespacesAndNewlines)
        answer = ""
        errorMessage = nil
        isGenerating = true

        generationTask = Task {
            do {
                let stream = try await service.streamChat(
                    model: model,
                    messages: [ChatMessage(role: .user, content: prompt)]
                )
                for try await event in stream {
                    if case .token(let fragment) = event {
                        answer += fragment
                    }
                }
            } catch is CancellationError {
                // Se conserva la respuesta parcial.
            } catch {
                errorMessage = error.localizedDescription
            }
            isGenerating = false
        }
    }
}

#Preview {
    QuickAskView()
}
