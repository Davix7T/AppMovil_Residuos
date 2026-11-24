# EcoSoft

EcoSoft es una aplicación móvil desarrollada con Flutter para clasificar
residuos mediante inteligencia artificial. Permite tomar o seleccionar una
fotografía, reconocer el material con un modelo TensorFlow Lite y mostrar el
contenedor recomendado según la clasificación.

También incluye reconocimiento en vivo con cámara, historial local y
recomendaciones personalizadas generadas completamente en el dispositivo.

## Funcionalidades

- Clasificación de residuos a partir de fotos y imágenes de la galería.
- Cámara en vivo con detección de objetos y clasificación por recortes.
- 12 categorías: batería, residuos biológicos, vidrio marrón, cartón,
  ropa, vidrio verde, metal, papel, plástico, zapatos, basura y vidrio blanco.
- Recomendación del contenedor de reciclaje correspondiente.
- Historial persistente con imágenes y datos de clasificación.
- Estadísticas de frecuencia y tendencia de los residuos registrados.
- Consejos personalizados basados en el patrón de uso.
- Generación de texto con Gemma 3 1B IT ejecutada localmente en Android.
- Funcionamiento sin conexión una vez que se importa el modelo generativo.

## Modelos de inteligencia artificial

### Clasificación de residuos

La aplicación usa `assets/models/waste_model.tflite`, un modelo TensorFlow Lite
entrenado para reconocer 12 clases de residuos. Recibe imágenes RGB de
`224 x 224` y devuelve 12 puntuaciones. Es posible cargarlo y ejecutarlo en
Android, iOS y web.

### Detección en vivo

La cámara en vivo utiliza `assets/models/yolov8n_float32.tflite` para detectar
objetos dentro de cada fotograma. Cada detección se recorta y se clasifica con
el modelo de residuos.

### Consejos personalizados

El análisis de hábitos combina el historial local y la categoría más frecuente
para construir un resumen. Con al menos tres clasificaciones guardadas, la app
puede enviar ese resumen a **Gemma 3 1B IT**, una variante LiteRT-LM
instruction-tuned.

El modelo generativo no recibe fotografías ni el historial completo. Las
imágenes y el historial se almacenan únicamente en el dispositivo. Si Gemma no
produce una respuesta válida, la app muestra el consejo base calculado por
reglas locales sin atribuirlo falsamente a la IA.

> La precisión depende de la calidad de la fotografía, la iluminación y los
> datos utilizados para entrenar los modelos. Las recomendaciones no sustituyen
> las indicaciones oficiales de separación de cada municipio.

## Requisitos

- Flutter 3 y Dart 3.13 o superior.
- Android Studio o Visual Studio Code con Flutter.
- Android físico o emulador para las funciones de Android.
- Conexión a Internet solo para instalar dependencias y descargar Gemma.
- Al menos 557 MiB de espacio disponible para el modelo generativo de Gemma.

La clasificación y el reconocimiento en vivo requieren una cámara; no están
disponibles en todas las plataformas de escritorio.

## Instalación

### 1. Instalar herramientas

Instala Flutter y Android Studio. Durante la instalación de Android Studio,
configura el Android SDK, las herramientas de plataforma y, opcionalmente, un
emulador.

Comprueba el entorno:

```powers
flutter doctor
```

### 2. Clonar e instalar dependencias

```powers
git clone https://github.com/Davix7T/AppMovil_Residuos.git
cd AppMovil_Residuos
flutter pub get
```

### 3. Ejecutar la aplicación

Conecta un dispositivo Android o inicia un emulador y ejecuta:

```powers
flutter devices
flutter run -d <ID-del-dispositivo>
```

Para generar una APK de depuración:

```powers
flutter build apk --debug
```

El resultado se crea en `build/app/outputs/flutter-apk/app-debug.apk`.

## Configurar Gemma 3 1B IT

El modelo generativo no se incluye en el repositorio porque tiene un tamaño
aproximado de 557 MiB y requiere aceptar una licencia.

1. Inicia sesión en Hugging Face.
2. Solicita y acepta el acceso a
   [Gemma 3 1B IT](https://huggingface.co/google/gemma-3-1b-it).
3. Descarga la versión convertida para LiteRT:
   [gemma3-1b-it-int4.litertlm](https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/a9bd85643f05cdb1e5cd5af7ba4e74b0e8210ca0/gemma3-1b-it-int4.litertlm).
4. Copia el archivo al teléfono y abre la aplicación.
5. En **Estadísticas**, pulsa
   **Importar modelo Gemma 3 1B IT** y selecciona el archivo.

La app valida el nombre y el tamaño del archivo antes de almacenarlo en su
directorio privado. Después de importarlo, la generación funciona sin conexión.
La app solo acepta el archivo `gemma3-1b-it-int4.litertlm` con su tamaño
esperado.

No subas el modelo al repositorio ni incluyas archivos `.litertlm` dentro de
`assets/`. El archivo está excluido mediante `.gitignore`.

## Uso

1. Abre **Escaneo** y toma una fotografía o selecciona una imagen.
2. Guarda el resultado si deseas incorporarlo al historial.
3. Usa **Cámara en vivo** para detectar y clasificar residuos en tiempo real.
4. Consulta **Historial** para revisar, buscar o eliminar registros.
5. Abre **Estadísticas** para ver tendencias y generar una recomendación.

El consejo con IA necesita al menos tres clasificaciones guardadas. La app
presenta siempre una recomendación local basada en el análisis de hábitos si
Gemma no está disponible o no produce una respuesta válida.


El historial se guarda en `SharedPreferences` bajo la clave
`historial_ecosoft`. Las imágenes se codifican en base64 dentro del JSON.

## Privacidad

- La clasificación e inferencia se realizan localmente.
- Gemma recibe solo categoría, conteos, resumen y tendencia agregados.
- Las fotografías no se envían a Hugging Face ni a un servicio externo.
- El historial e imágenes permanecen en el almacenamiento local de la app.
- Quitar los datos de la aplicación elimina el historial y el modelo importado.

## Verificación

Ejecuta las comprobaciones disponibles:

```powers
flutter analyze
flutter test
flutter build apk --debug
flutter build web
```

El proyecto incluye pruebas para contenedores, clasificación de fotogramas,
seguimiento, decodificador YOLO y recomendaciones personalizadas.

## Limitaciones conocidas

- El modelo de clasificación puede confundir materiales visualmente similares.
- Los contenedores están orientados a prácticas de clasificación colombianas.
- Gemma 3 1B es pequeño: sus respuestas pueden ser imprecisas y se valida el
  resultado antes de mostrarlo.
- La generación local está habilitada únicamente en Android.
- Los permisos de cámara y galería requieren configuración adicional en iOS,
  actualmente no incluidos en `Info.plist`.

## Tecnologías

- Flutter y Dart
- LiteRT / TensorFlow Lite
- LiteRT-LM
- YOLOv8n convertido a TFLite
- Gemma 3 1B IT
- Camera y Image Picker
- SharedPreferences

