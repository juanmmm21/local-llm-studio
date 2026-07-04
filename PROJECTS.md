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

### Fase 3: Persistencia y Biblioteca de Documentos Local (Completada)
- [x] Historial de conversaciones persistido con SwiftData (sidebar con sesiones).
- [x] Sistema de archivos mediante SwiftData (bookmarks con ámbito de seguridad, sin duplicar archivos en disco).
- [x] Lógica nativa de lectura de archivos locales (Markdown, TXT, PDF vía PDFKit).
- [x] Procesador RAG local: extracción, chunking, embeddings locales (`/api/embed` + nomic-embed-text) con respaldo por palabras clave, e inyección de contexto en el prompt con citas de origen.

### Fase 4: Búsqueda Web Híbrida (Completada)
- [x] Interruptor de privacidad en la UI para activar/desactivar el acceso a internet del asistente (off por defecto, se recuerda entre sesiones).
- [x] Servicio de búsqueda web nativo (URLSession + DuckDuckGo HTML, sin claves de API) que recupera y limpia resultados relevantes.
- [x] Inyección de los resultados web en el prompt junto al contexto del RAG local, con citas de las fuentes.
- [x] Indicador visible en el chat cuando una respuesta ha usado información de internet.

### Fase 5: Gestión Avanzada y Multimodalidad (Completada)
- [x] Gestión de modelos instalados: eliminación desde el catálogo con confirmación para liberar disco (`/api/delete`).
- [x] Instalación automática del modelo de embeddings (nomic-embed-text) en el primer arranque; excluido del selector de chat.
- [x] Renombrado de conversaciones y búsqueda en el historial (por título y contenido de los mensajes).
- [x] Lectura del contenido completo de las páginas web principales en la búsqueda híbrida (no solo los resúmenes del buscador).
- [x] Chat multimodal: adjuntar imágenes PNG/JPEG para modelos con visión (LLaVA), con persistencia en el historial.

### Fase 6: Experiencia de Producto (Completada)
- [x] Licencia MIT publicada en el repositorio.
- [x] Renderizado Markdown enriquecido en las respuestas: bloques de código con etiqueta de lenguaje y botón de copiar.
- [x] Ventana de Ajustes nativa (⌘,): host/puerto de Ollama, instrucciones de sistema, temperatura y ventana de contexto.
- [x] Métricas de generación bajo cada respuesta: modelo usado, tokens por segundo y duración.
- [x] Exportación de conversaciones a Markdown desde el menú contextual del historial.
- [x] Arrastrar y soltar sobre el chat: imágenes al mensaje, documentos a la biblioteca RAG.
- [x] Onboarding de primer arranque: guía visual de instalación cuando Ollama no está en el Mac.
- [x] Icono de app propio con todos los tamaños del set de macOS (generador en `Scripts/make-app-icon.swift`).

### Fase 7: Potencia de Chat, RAG Avanzado y Calidad (Completada)
- [x] Regenerar la última respuesta y editar/reenviar mensajes propios (la conversación se recorta desde ese punto).
- [x] Plantillas de asistente por conversación (traductor, revisor de código, redactor, profesor, resumidor) con prioridad sobre el prompt global.
- [x] Títulos de conversación generados automáticamente por el modelo local tras el primer intercambio (con limpieza de razonamiento tipo `<think>`).
- [x] Fuentes del RAG visibles: cada respuesta muestra los fragmentos de la biblioteca que se inyectaron como contexto.
- [x] Carpetas vigiladas: la biblioteca se sincroniza con carpetas del usuario en cada arranque (altas y bajas de documentos).
- [x] Indicador de modelos en memoria (`/api/ps`) con expulsión de RAM sin borrar del disco (`keep_alive: 0`).
- [x] Pregunta rápida en la barra de menús de macOS (MenuBarExtra), sin abrir la ventana principal y sin guardar historial.
- [x] Target de tests unitarios (XCTest): 33 tests de parsing Markdown, recuperación RAG, chunking, parsing web y saneado de títulos.