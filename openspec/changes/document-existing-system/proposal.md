# Proposal

## Why

EcoSoft ya implementa un flujo funcional de clasificación de residuos, pero el repositorio no tiene especificaciones OpenSpec que sirvan de línea base. Sin una descripción verificable del comportamiento actual, cualquier cambio futuro corre el riesgo de romper funciones existentes o de asumir capacidades que la aplicación todavía no tiene.

## What Changes

- Añadir especificaciones base para cuatro capacidades ya implementadas: contenedor y navegación, clasificación por imagen, análisis con cámara en vivo e historial local.
- Documentar en `design.md` la arquitectura vigente, el stack, el contrato del modelo, la persistencia y la configuración real de plataformas.
- Registrar el estado de calidad observado (`flutter analyze`, formato, ausencia de pruebas y de CI) como referencia para trabajo posterior.
- **No** se modifica código Dart, `pubspec.yaml`, assets, configuración de plataformas ni comportamiento en tiempo de ejecución.
- **No** se implementan funcionalidades pendientes ni se corrigen los defectos conocidos; solo se documentan.

## Capabilities

### New Capabilities

- `app-shell`: contenedor persistente de la aplicación, navegación inferior entre Inicio, Escanear e Historial, y contenido de la pantalla de inicio.
- `waste-classification`: selección de una imagen desde cámara o galería, carga validada del modelo local y presentación de categoría, confianza, contenedor y recomendación.
- `live-camera-analysis`: apertura de la cámara, vista previa, captura de una imagen bajo demanda y presentación del resultado sin guardado automático.
- `classification-history`: guardado explícito de una clasificación, persistencia local entre reinicios y listado cronológico de registros.

### Modified Capabilities

Ninguna. No existen specs previas en `openspec/specs/`; las cuatro capacidades son nuevas como documentación de comportamiento ya presente.

## Impact

- Solo se añaden archivos bajo `openspec/changes/document-existing-system/`.
- No cambian `lib/`, `pubspec.yaml`, `pubspec.lock`, `assets/`, `android/`, `ios/`, `web/`, `linux/`, `macos/` ni `windows/`.
- No hay endpoints, backend, base de datos externa ni migración de datos.
- Al archivar el cambio, las specs pasan a `openspec/specs/` y quedan como línea base para propuestas posteriores.

## Fuera de alcance

Los siguientes puntos se identificaron durante el análisis, pero **no forman parte de este cambio** y no deben implementarse como parte de él:

- Corregir el botón duplicado "Analizar residuo" en la pestaña Escanear.
- Añadir descripciones de uso de cámara y fototeca en iOS.
- Validar si la salida del modelo es probabilidad o logit, o añadir umbral de confianza.
- Mover la inferencia a un isolate o cambiar la persistencia del historial.
- Añadir pantalla de detalle, borrado, búsqueda o filtros del historial.
- Añadir pruebas, CI, internacionalización o branding de producto.
