# Design

## Context

Ver `proposal.md` para la motivación. Este cambio es **documental**: describe el sistema ya implementado en `lib/`, `pubspec.yaml`, `assets/` y los manifiestos de plataforma. Las specs nuevas están en `specs/app-shell/spec.md`, `specs/waste-classification/spec.md`, `specs/live-camera-analysis/spec.md` y `specs/classification-history/spec.md`.

### Estructura y puntos de entrada

| Archivo | Responsabilidad actual |
|---|---|
| `lib/main.dart` | `main()`, `EcoSoftApp`, `EcoHome`, las tres secciones, el modelo `EcoRegistro`, el historial y los mapeos de contenedor/recomendación |
| `lib/camara_en_vivo.dart` | `CamaraEnVivo`: inicialización de cámara, vista previa, captura y análisis |
| `lib/services/clasificador_residuos.dart` | `ClasificadorResiduos` y `ResultadoResiduo`: carga del modelo, preprocesamiento e inferencia |
| `assets/models/waste_model.tflite` | Modelo TFLite local de ~20 MB, versionado en git |
| `assets/labels/` | Directorio vacío; las etiquetas están en el código |

No existen capas de repositorio, dominio, inyección de dependencias, router ni gestor de estado externo. La UI importa directamente los plugins y el servicio de clasificación.

### Arquitectura vigente

```text
EcoSoftApp
└── EcoHome (StatefulWidget)
    ├── IndexedStack(index: pagina)
    │   ├── inicio()
    │   ├── escaner()
    │   └── historialPage()
    ├── NavigationBar
    └── Navigator.push → CamaraEnVivo

EcoHome → ClasificadorResiduos → flutter_litert Interpreter
EcoHome → image_picker / camera
EcoHome → SharedPreferences (JSON con base64)
```

- El estado compartido vive en `_EcoHomeState` y se actualiza con `setState`.
- La sección activa se identifica con el entero `pagina`; no hay rutas nombradas para las tres pestañas.
- `IndexedStack` mantiene construidas las tres secciones, por lo que conservan imagen, resultado y lista al cambiar de pestaña.
- `CamaraEnVivo` es la única pantalla abierta con `Navigator.push`.
- `ClasificadorResiduos` se instancia una vez en `EcoHome` y memoiza el intérprete; `cerrar()` existe pero nunca se invoca.
- `clasificarImagen()` es síncrona y se ejecuta en el hilo de UI.

### Stack y versiones observadas

| Elemento | Versión / configuración |
|---|---|
| Flutter / Dart | 3.47.5 stable / `^3.13.4` |
| `flutter_litert` | 3.9.4 |
| `camera` | 0.12.2 |
| `image_picker` | 1.2.4 |
| `image` | 4.12.0 |
| `shared_preferences` | 2.5.6 |
| `flutter_lints` | 6.0.0 |
| Android | Gradle 9.3.1, AGP 9.1.0, Kotlin 2.4.0, Java 17, `minSdk 24` |
| Paquete Android | `com.example.app_movil` |

No hay dependencia directa de HTTP, base de datos, router, state management, codegen ni internacionalización.

### Contrato del modelo

- Asset: `assets/models/waste_model.tflite`, declarado en `pubspec.yaml`.
- Entrada: `[1, 224, 224, 3]`, float RGB normalizado con `/255`.
- Salida: `[1, 12]`.
- Clases, en el orden que usa el modelo: `battery`, `biological`, `brown-glass`, `cardboard`, `clothes`, `green-glass`, `metal`, `paper`, `plastic`, `shoes`, `trash`, `white-glass`.
- `cargarModelo()` rechaza el modelo si las dimensiones no coinciden.
- El resultado se obtiene por `argmax`; la confianza mostrada es el valor crudo de la salida, sin `softmax` ni umbral.
- `initializeWeb()` se ejecuta antes de `Interpreter.fromAsset`; en nativo es no-op y en web carga el runtime WASM desde un CDN.
- El commit `f960b1f` indica que el modelo proviene de WasteNet con licencia MIT, pero no hay archivo de licencia ni atribución en el repositorio.

### Persistencia

- Clave de SharedPreferences: `historial_ecosoft`.
- Cada registro contiene `nombre`, `contenedor`, `recomendacion`, `fecha` ISO-8601 e `imagen` en base64.
- Al iniciar, `cargarHistorial()` lee el JSON y decodifica todas las imágenes en memoria.
- Al guardar, se reescribe la lista completa; la escritura no se espera desde `guardarClasificacion()`.
- No hay versión de esquema, migración, límite de registros ni borrado.
- Los errores de lectura/escritura solo se registran con `debugPrint`.

### Plataformas

| Plataforma | Estado real |
|---|---|
| Android | Funcional; permisos de cámara heredados del plugin; `INTERNET` solo en debug/profile; release firmado con debug |
| iOS | Scaffolding presente; faltan `NSCameraUsageDescription` y `NSPhotoLibraryUsageDescription` |
| Web | Estructura presente; `manifest.json` e `index.html` son plantilla; requiere red para el runtime LiteRT y descarga el modelo de ~20 MB |
| Linux/Windows/macOS | `flutter_litert` soportado; no hay plugin de cámara de escritorio, por lo que la cámara en vivo no funciona |

No hay backend, API, autenticación, sincronización ni endpoints. Todo el flujo es local, salvo la carga del runtime en web.

### Calidad observada

- `flutter analyze`: un aviso `unnecessary_import` en `clasificador_residuos.dart`.
- `dart format --output=none`: los tres archivos Dart requerirían formato.
- No existe `test/`; `flutter test` falla con "Test directory not found".
- No hay CI, pre-commit, cobertura ni LICENSE.
- `README.md` y metadatos web siguen siendo plantilla.
- En el entorno analizado solo hay un dispositivo Linux; no hay dispositivo ni AVD Android, Chrome no está instalado y faltan `clang++`, `ninja` y GTK. El toolchain Android (SDK 36) sí está disponible.

## Goals / Non-Goals

**Goals:**

- Fijar una línea base verificable del comportamiento actual.
- Trazar cada capacidad a código y configuración existentes.
- Separar explícitamente el estado actual de las mejoras propuestas.

**Non-Goals:**

- Cambiar código, dependencias, assets o configuración de plataformas.
- Corregir defectos conocidos o implementar funcionalidades pendientes.
- Añadir pruebas, CI, internacionalización o branding.
- Cambiar el modelo, el preprocesamiento o la persistencia.
- Reconstruir la arquitectura o migrar a otro gestor de estado.

## Decisions

### UI monolítica con `setState` e `IndexedStack`

Se mantiene una sola `StatefulWidget` para el shell y las tres secciones, con `setState` y un índice entero. Es suficiente para el alcance actual y evita dependencias nuevas; la consecuencia es un archivo de ~900 líneas y lógica de presentación, persistencia y mapeos en el mismo lugar.

Alternativas consideradas pero no implementadas: router (`go_router`), gestor de estado (`provider`, `riverpod`, `bloc`) y separación en `screens/`, `models/` y `repositories/`.

### Servicio dedicado para el modelo

`ClasificadorResiduos` encapsula la carga y la inferencia, con un DTO `ResultadoResiduo`. La UI no manipula tensores directamente. El modelo se carga bajo demanda y se reutiliza; no hay aislamiento en otro isolate.

### Contrato de modelo fijo y validado

El modelo debe ser exactamente 224×224×3 con 12 salidas. La validación temprana convierte un modelo incompatible en un error visible en vez de una clasificación silenciosamente incorrecta. El preprocesamiento se limita a `/255`; no se normaliza por media/desviación ni se aplica orientación EXIF explícita.

### Cámara en vivo por captura única

La pantalla de cámara abre la primera cámara disponible, carga el modelo y espera una acción del usuario. No analiza fotogramas en streaming. Cada pulsación captura una foto y reemplaza el resultado. Las capturas no se guardan automáticamente.

### Persistencia simple en SharedPreferences

Se eligió JSON con imágenes en base64 por simplicidad y para evitar dependencias adicionales. El costo es que el historial completo se carga, se decodifica y se reescribe en memoria; no es adecuado para un historial grande.

### Aplicación local sin backend

No hay red en el flujo principal: modelo, imágenes e historial viven en el dispositivo. La excepción es la web, donde `flutter_litert` obtiene su runtime desde un CDN.

### Configuración de plataforma heredada del template

Los identificadores, iconos, splash, firma y textos de plataforma son los de Flutter. Android es la plataforma donde el flujo completo es ejecutable; iOS requiere permisos adicionales y las funciones de cámara no están disponibles en escritorio.

## Risks / Trade-offs

- **Inferencia bloqueante en el hilo de UI** → aceptado en el estado actual; un cambio futuro debería moverla a un isolate y usar buffers tipados.
- **Historial sin límite con base64** → aceptado; puede degradar memoria y arranque. Un cambio futuro debería usar archivos/SQLite y miniaturas.
- **Confianza sin semántica verificada** → la spec dice "confianza reportada por el modelo"; si la salida son logits, la interpretación actual sería incorrecta.
- **Mapeos duplicados de categorías** → nombre, contenedor y recomendación viven en tres estructuras; agregar una clase exige cambios coordinados.
- **iOS sin claves de privacidad** → cámara y galería fallarán hasta añadirlas.
- **Web dependiente de CDN y modelo de 20 MB** → requiere red y aumenta el tiempo de primera carga.
- **Ciclo de vida de cámara y EXIF** → no se maneja `AppLifecycleState` ni se normaliza la orientación; puede fallar al volver del segundo plano o clasificar fotos rotadas.
- **Errores de persistencia silenciosos** → solo se registran en consola; el usuario no recibe aviso.
- **Sin pruebas ni CI** → cualquier regresión debe detectarse manualmente.
- **Botón "Analizar residuo" duplicado** → defecto visual conocido en la sección Escanear; no se corrige en este cambio.
- **Identidad y firma de plantilla** → `com.example.app_movil`, iconos/splash genéricos y release con clave de debug; no está listo para distribución.

## Migration Plan

No hay migración de datos ni despliegue. El cambio solo añade documentación.

1. Revisar las specs contra el código y la configuración actuales.
2. Ejecutar `openspec validate "document-existing-system" --strict`.
3. Archivar el cambio cuando se apruebe; las cuatro specs pasan a `openspec/specs/`.

Rollback: eliminar `openspec/changes/document-existing-system/`; la aplicación no se ve afectada.

## Open Questions

- ¿La salida del modelo es probabilidad (`softmax`) o logit? La respuesta afecta la interpretación del porcentaje, no la estructura de las specs.
- ¿Qué plataforma es prioritaria para las próximas mejoras: Android, web o iOS?
- ¿La cámara en vivo debería guardar resultados automáticamente en el futuro? El comportamiento actual y especificado es que no.
- ¿Se necesita una política de retención o límite para el historial?

Ninguna de estas preguntas bloquea la línea base; cualquiera que cambie el comportamiento requerirá una propuesta nueva.

## Trabajo futuro propuesto (fuera de alcance)

Estas mejoras **no están implementadas** y no forman parte de este cambio ni de sus tareas:

### Prioridad alta

- Eliminar el botón duplicado y actualizar los textos obsoletos de la interfaz.
- Añadir las descripciones de privacidad de cámara y fototeca en iOS.
- Verificar la semántica de la salida del modelo y definir un umbral de confianza.
- Corregir el aviso de análisis y normalizar el formato Dart.

### Prioridad media

- Mover decodificación, redimensión e inferencia fuera del hilo de UI.
- Sustituir base64/SharedPreferences por archivos de imagen y metadatos en una base local.
- Centralizar categorías, contenedores y recomendaciones en una sola fuente.
- Manejar el ciclo de vida de la cámara y la orientación EXIF.
- Gestionar y mostrar errores de persistencia.

### Prioridad baja

- Pantalla de detalle, borrado, búsqueda y filtros del historial.
- Pruebas unitarias/widget y CI con `analyze`, `test` y verificación de formato.
- Branding, `applicationId` propio, firma de release y atribución del modelo.
- Internacionalización y mejoras de accesibilidad.
