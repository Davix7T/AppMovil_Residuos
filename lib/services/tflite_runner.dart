// Punto de entrada único: importa esto y llama a `crearRunner()`.
// La importación condicional elige la implementación correcta en tiempo de
// compilación (así el código de Chrome nunca se compila para Android ni
// viceversa).
export 'tflite_runner_base.dart';
export 'tflite_runner_stub.dart'
    if (dart.library.io) 'tflite_runner_io.dart'
    if (dart.library.js_interop) 'tflite_runner_web.dart';
