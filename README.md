# local-llm-studio

Entorno de escritorio nativo para macOS (SwiftUI) para gestionar e interactuar con modelos de lenguaje locales (Llama, DeepSeek, Mistral, Gemma...) a través de [Ollama](https://ollama.com), con biblioteca de archivos local para RAG privado.

## Filosofía

- **100% Local:** toda la inferencia ocurre en tu Mac mediante Ollama (`localhost:11434`).
- **Privacidad absoluta:** cero llamadas a APIs externas de internet. La única comunicación de red es HTTP local hacia `127.0.0.1`.
- **Sin dependencias externas:** solo frameworks nativos de Apple (SwiftUI, SwiftData, Foundation, Network).

## Requisitos

- macOS 14.0 o superior.
- Xcode 16 o superior.
- [Ollama](https://ollama.com) instalado y en ejecución (`ollama serve`).

## Compilar

```bash
xcodebuild -scheme local-llm-studio -destination 'platform=macOS' build
```

## Estructura del proyecto

```
local-llm-studio/
├── App/            # Punto de entrada de la aplicación
├── Models/         # Modelos de dominio (Codable) para la API local de Ollama
├── Services/       # Servicios (OllamaService: cliente HTTP local async/await)
├── ViewModels/     # Estado observable de la UI
├── Views/          # Vistas SwiftUI
└── Resources/      # Assets y entitlements
```

## Estado (Fase 1)

- [x] Estructura base del proyecto.
- [x] `OllamaService`: cliente asíncrono para listar modelos instalados (`GET /api/tags`).
- [ ] Chat con streaming (`POST /api/chat`).
- [ ] UI de tres paneles (Sidebar + Chat + Selector de modelos).
