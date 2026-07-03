# CLAUDE.md - Entorno Offline y Git Autónomo

## Información del Repositorio
- **URL:** https://github.com/juanmmm21/local-llm-studio
- **Filosofía:** 100% Local / Privacidad Absoluta / Zero-Network (Sin acceso a Internet).

## Automatización de Git (Flujo Autónomo)
- **Ejecución de Commits:** Tras completar un cambio lógico, refactorización o corrección que compile con éxito, se deben automatizar las acciones de Git. 
- **Si el Agente tiene acceso a Terminal:** Debe ejecutar de forma autónoma:
  1. `git add .`
  2. `git commit -m "Mensaje descriptivo en español e imperativo"`
  3. `git push`
- **Si el Agente NO tiene acceso a Terminal:** Debe estructurar su respuesta indicando explícitamente el mensaje de commit recomendado para que el script de automatización local del usuario lo procese de manera limpia.
- **Restricciones:** Prohibido incluir firmas de IA o tags de co-autoría (`Co-authored-by:`). Toda la autoría debe pertenecer a juanmmm21.

## Comandos de Desarrollo Locales
- **Compilar Proyecto:** `xcodebuild -scheme local-llm-studio -destination 'platform=macOS' build`
- **Formatear Código:** `swiftlint --fix`

## Estilo de Código (Swift/SwiftUI)
- **Dependencias:** Prohibido añadir librerías externas que requieran resoluciones de paquetes en la nube. Todo debe resolverse con los frameworks nativos de Apple (SwiftUI, SwiftData, Network, Foundation).
- **Concurrencia:** Uso estricto de `async/await` y `AsyncSequence` para gestionar flujos de datos y respuestas en streaming de manera eficiente y sin bloquear la UI.