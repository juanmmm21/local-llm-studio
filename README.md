# local-llm-studio

Entorno de escritorio nativo para macOS (SwiftUI) para gestionar e interactuar con modelos de lenguaje locales (Llama, DeepSeek, Mistral, Gemma...) a través de [Ollama](https://ollama.com), con biblioteca de archivos local para RAG privado.

## Filosofía

- **Inferencia 100% local:** los modelos siempre corren en tu Mac mediante Ollama (`localhost:11434`). El chat funciona sin conexión.
- **Privacidad por defecto:** la app solo usa internet en dos casos controlados por ti: descargar modelos desde el catálogo integrado (vía Ollama) y la búsqueda web opcional del asistente (desactivada por defecto).
- **Sin dependencias externas:** solo frameworks nativos de Apple (SwiftUI, SwiftData, Foundation, Network).

## Requisitos

- macOS 14.0 o superior.
- Xcode 16 o superior.
- [Ollama](https://ollama.com) instalado. La app lo arranca sola en segundo plano si no está en ejecución.

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

## Estado

- [x] **Fase 1:** conectividad local (listado de modelos, chat con streaming, UI de tres zonas, auto-arranque de Ollama).
- [x] **Fase 2:** catálogo integrado con descarga de modelos con un clic y progreso en vivo.
- [x] **Fase 3:** historial de conversaciones persistido (SwiftData) y biblioteca de documentos con RAG privado (embeddings locales con respaldo por palabras clave).
- [x] **Fase 4:** búsqueda web híbrida opcional (el modelo local responde con contexto de internet; interruptor de privacidad desactivado por defecto e indicador de fuente en cada respuesta).
