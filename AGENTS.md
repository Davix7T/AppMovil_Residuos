# AGENTS.md

Flutter app (`app_movil`) that classifies waste photos on-device with a TFLite model. UI text, identifiers, comments, and commit messages are in Spanish; preserve that convention. The Dart package is `app_movil` even though the repo is `AppMovil_Residuos`.

## Commands

- `flutter pub get` — after changing `pubspec.yaml`.
- `flutter analyze` — the only configured verification (`flutter_lints`; platform dirs and `build/` are excluded in `analysis_options.yaml`).
- `flutter run -d <device>` — live-camera code needs Android, iOS, or web; there is no desktop camera plugin.
- `flutter test` — no `test/` directory exists, so this currently errors with "Test directory not found"; that is not a regression.

## Structure

- `lib/main.dart` — app shell and all three tabs. Navigation is one `pagina` integer indexing `IndexedStack`; adding a tab means adding to both the `pantallas` list and `NavigationBar.destinations` **in the same order**, not adding a router.
- `lib/camara_en_vivo.dart` — live camera screen, pushed as a separate `MaterialPageRoute` from the scan tab.
- `lib/services/clasificador_residuos.dart` — model loading, preprocessing, inference, and Spanish label mapping.

## Model contract (easy to break)

- Model: `assets/models/waste_model.tflite` (~20 MB), declared in `pubspec.yaml`. Declare any new asset there too.
- Input is `[1, 224, 224, 3]` float RGB normalized by `/255`; output is `[1, 12]`. `cargarModelo()` hard-fails if either shape differs.
- Class order is hardcoded in `ClasificadorResiduos.etiquetas` and must match the model output order. Spanish names live in `clasificador_residuos.dart`; containers and recommendations are separate `switch` statements in `main.dart` — update all of them when changing classes.
- `initializeWeb()` must be awaited before `Interpreter.fromAsset`. It is a no-op on native, but on web it loads the WASM runtime from a CDN, so offline web runs fail.
- `cargarModelo()` memoizes the interpreter; `clasificarImagen()` throws `StateError` if it wasn't loaded. Classification is synchronous and runs a 224×224 Dart pixel loop, so it blocks the UI frame.
- Use `flutter_litert` (LiteRT), not `tflite_flutter`; the `Interpreter` and `initializeWeb` APIs come from that package.

## Persistence

- History is stored as JSON in SharedPreferences key `historial_ecosoft`, with images embedded as base64. Every save rewrites the full list; keep the key and JSON shape compatible with existing installs or migrate explicitly.

## Platform notes

- iOS `Info.plist` has no `NSCameraUsageDescription` or `NSPhotoLibraryUsageDescription`; add them before using camera/gallery on iOS.
- Android camera permissions come from the plugin manifest; the app's Android release build is still signed with debug keys (`android/app/build.gradle.kts`).
