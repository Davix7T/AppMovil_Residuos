import 'dart:typed_data';

/// Contrato común para ejecutar un modelo .tflite. Hay una implementación por
/// plataforma (ver `tflite_runner.dart`):
///   * Android/iOS/escritorio -> `tflite_runner_io.dart`
///     (Interpreter + IsolateInterpreter: la inferencia corre en otro hilo).
///   * Chrome                 -> `tflite_runner_web.dart`
///     (LiteRT.js con WebGPU->WASM; si falla, tflite-js).
///
/// IMPORTANTE: [entrada] y [salida] deben crearse con `Float32List(n)`
/// (sin vistas con desplazamiento) porque en web se entregan como
/// `.buffer`. Se pueden reutilizar entre llamadas.
abstract class TfliteRunner {
  /// Carga el modelo. En nativo se valida que las formas de los tensores
  /// coincidan con las esperadas; en web (donde no se pueden consultar
  /// con LiteRT.js) se confía en ellas.
  Future<void> cargar(
    String rutaAsset, {
    required List<int> formaEntradaEsperada,
    required List<int> formaSalidaEsperada,
    int hilos = 4,
  });

  List<int> get formaEntrada;
  List<int> get formaSalida;

  /// Descripción legible del motor realmente usado (p. ej. "LiteRT XNNPACK
  /// 4 hilos", "LiteRT.js WebGPU", "tflite-js WASM").
  String get backend;

  bool get cargado;

  Future<void> ejecutar(Float32List entrada, Float32List salida);

  Future<void> cerrar();
}
