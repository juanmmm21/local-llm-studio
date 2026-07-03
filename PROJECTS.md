# PROJECTS.md - Arquitectura Local e Historial Autónomo

## Visión General
**local-llm-studio** es un entorno de escritorio nativo para macOS diseñado para centralizar e interactuar con diversos modelos de lenguaje (Llama, DeepSeek, Mistral, Gemma, etc.) que se ejecutan de manera estrictamente local en la máquina del usuario a través de Ollama. 

El propósito crítico del proyecto es el **aislamiento total de la red**: tanto la inferencia de los modelos como el procesamiento de la biblioteca de archivos local (RAG privado) se ejecutan localmente en el Mac, garantizando confidencialidad absoluta y disponibilidad sin conexión a internet.

## Arquitectura de Ejecución Local
1. **Frontend (SwiftUI):** Interfaz nativa de tres paneles que interactúa con los servicios locales.
2. **Motor de Inferencia:** Ollama ejecutándose en `localhost:11434`. La app interactúa con la API local para listar modelos descargados en el Mac y procesar el chat.
3. **Biblioteca Offline (SwiftData):** Almacenamiento local de metadatos de documentos, rutas de archivos y sesiones de chat histórico.
4. **Procesador de Contexto RAG:** Algoritmo local para la extracción de texto, fragmentación (`chunking`) e inyección directa en el prompt del modelo seleccionado, respetando su ventana de contexto local.

## Hoja de Ruta de Desarrollo

### Fase 1: Core de Conectividad Local y UI (En Desarrollo)
- [ ] Estructura base de la app de macOS (Sidebar + Ventana de Chat + Selector superior de modelos locales).
- [ ] Cliente HTTP asíncrono para interactuar con el endpoint local de Ollama (`/api/tags` y `/api/chat`).
- [ ] Implementación de streaming de texto en la interfaz sin latencia ni bloqueos de memoria.

### Fase 2: Persistencia y Biblioteca de Documentos Local
- [ ] Sistema de archivos mediante SwiftData (guardar rutas locales sin duplicar archivos en disco).
- [ ] Lógica nativa de lectura de archivos locales (Markdown, TXT, PDF).