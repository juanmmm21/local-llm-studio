//
//  OnboardingView.swift
//  local-llm-studio
//
//  Primer arranque sin Ollama instalado: guía visual de tres pasos
//  en lugar de un mensaje de error.
//

import SwiftUI

struct OnboardingView: View {
    /// Reintenta la conexión (tras instalar Ollama).
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 10) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 52))
                    .foregroundStyle(Color.accentColor)
                Text("Bienvenido a local-llm-studio")
                    .font(.largeTitle.bold())
                Text("Tu estudio privado de IA. Solo falta una pieza: Ollama, el motor gratuito que ejecuta los modelos en tu Mac.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
            }

            VStack(alignment: .leading, spacing: 18) {
                step(number: 1, title: "Descarga Ollama",
                     detail: "Es gratuito y de código abierto. Descarga única: después todo funciona sin conexión.")
                step(number: 2, title: "Arrastra Ollama a Aplicaciones y ábrelo una vez",
                     detail: "Quedará como un icono en la barra de menús. De ahí en adelante, esta app lo arrancará sola.")
                step(number: 3, title: "Vuelve aquí",
                     detail: "Pulsa «Ya lo he instalado» y elige tu primer modelo del catálogo integrado.")
            }
            .frame(maxWidth: 460, alignment: .leading)

            HStack(spacing: 12) {
                Link(destination: URL(string: "https://ollama.com/download")!) {
                    Label("Descargar Ollama", systemImage: "arrow.down.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Ya lo he instalado") {
                    onRetry()
                }
                .controlSize(.large)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func step(number: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.headline)
                .frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.15), in: Circle())
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    OnboardingView(onRetry: {})
        .frame(width: 700, height: 560)
}
