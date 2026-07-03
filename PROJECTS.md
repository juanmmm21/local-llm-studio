# PROJECTS.md - Arquitectura Local e Historial Autónomo

## Visión General
**local-llm-studio** es un entorno de escritorio nativo para macOS diseñado para centralizar e interactuar con diversos modelos de lenguaje (Llama, DeepSeek, Mistral, Gemma, etc.) que se ejecutan de manera estrictamente local en la máquina del usuario a través de Ollama. 

El principio rector del proyecto es **local-first con privacidad por defecto**: la inferencia de los modelos y el procesamiento de la biblioteca de archivos local (RAG privado) se ejecutan siempre localmente en el Mac, y funcionan sin conexión a internet. La red solo se usa en dos casos explícitos y controlados por el usuario:
1. **Descarga de modelos:** gestionada por el propio Ollama al instalar un modelo desde el catálogo integrado de la app.
2. **Búsqueda web opcional:** el usuario puede permitir que el asistente consulte internet para enriquecer respuestas, aunque el modelo siga corriendo en local. Desactivada por defecto.

## Arquitectura de Ejecución Local
1. **Frontend (SwiftUI):** Interfaz nativa de tres paneles que interactúa con los servicios locales.
2. **Motor de Inferencia:** Ollama ejecutándose en `localhost:11434`. La app interactúa con la API local para listar modelos descargados en el Mac y procesar el chat.
3. **Biblioteca Offline (SwiftData):** Almacenamiento local de metadatos de documentos, rutas de archivos y sesiones de chat histórico.
4. **Procesador de Contexto RAG:** Algoritmo local para la extracción de texto, fragmentación (`chunking`) e inyección directa en el prompt del modelo seleccionado, respetando su ventana de contexto local.

## Hoja de Ruta de Desarrollo

### Fase 1: Core de Conectividad Local y UI (Completada)
- [x] Estructura base de la app de macOS (Sidebar + Ventana de Chat + Selector superior de modelos locales).
- [x] Cliente HTTP asíncrono para interactuar con el endpoint local de Ollama (`/api/tags` y `/api/chat`).
- [x] Implementación de streaming de texto en la interfaz sin latencia ni bloqueos de memoria.

### Fase 2: Catálogo y Gestión de Modelos In-App (Completada)
- [x] Catálogo curado de los modelos más relevantes (Llama, DeepSeek, Mistral, Gemma, Qwen, Phi...).
- [x] Descarga con un clic mediante `/api/pull` de Ollama, con barra de progreso en la UI. Sin consola.
- [x] Refresco automático de la lista de modelos instalados al terminar cada descarga.

### Fase 3: Persistencia y Biblioteca de Documentos Local
- [ ] Sistema de archivos mediante SwiftData (guardar rutas locales sin duplicar archivos en disco).
- [ ] Lógica nativa de lectura de archivos locales (Markdown, TXT, PDF).
- [ ] Procesador RAG local: extracción, chunking e inyección de contexto en el prompt.

### Fase 4: Búsqueda Web Híbrida (Planificada)
- [ ] Interruptor de privacidad en la UI para activar/desactivar el acceso a internet del asistente (off por defecto).
- [ ] Servicio de búsqueda web nativo (URLSession) que recupera y limpia resultados relevantes.
- [ ] Inyección de los resultados web en el prompt junto al contexto del RAG local, con citas de las fuentes.
- [ ] Indicador visible en el chat cuando una respuesta ha usado información de internet.