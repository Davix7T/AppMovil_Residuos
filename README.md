# app_movil

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Recomendaciones con IA local

La generación de consejos funciona en Android con Gemma 3 1B IT mediante
LiteRT-LM. El modelo ocupa aproximadamente 557 MiB y, una vez importado, se
ejecuta sin conexión. Solo recibe el resumen de hábitos; las imágenes no se
envían.

Antes de usar esta función:

1. Inicia sesión en [Hugging Face](https://huggingface.co/litert-community/Gemma3-1B-IT)
   y acepta la licencia de Gemma para habilitar la descarga.
2. Descarga
   [gemma3-1b-it-int4.litertlm](https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/a9bd85643f05cdb1e5cd5af7ba4e74b0e8210ca0/gemma3-1b-it-int4.litertlm)
   en el teléfono.
3. En Estadísticas, pulsa **Importar modelo Gemma 3 1B IT** y selecciona el
   archivo descargado.

La aplicación valida el tamaño del archivo antes de copiarlo a su
almacenamiento privado. No incluyas el modelo descargado en el repositorio.
