// Implementación para CHROME / navegador.
//
// Orden de preferencia:
//   1. LiteRtInterpreter (LiteRT.js) con WebGPU; si el modelo no compila en
//      WebGPU, el propio paquete cae a WASM. Es asíncrono (no bloquea la UI).
//   2. Interpreter (tflite-js, WASM). Es síncrono: se usa solo si LiteRT.js
//      no se puede cargar (por ejemplo sin acceso al CDN de jsDelivr).
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_litert/flutter_litert.dart';

import 'tflite_runner_base.dart';

TfliteRunner crearRunner() => _RunnerWeb();

class _RunnerWeb implements TfliteRunner {
  LiteRtInterpreter? _lrt;
  Interpreter? _tfliteJs;
  List<int> _entrada = const [];
  List<int> _salida = const [];
  String _backend = 'sin cargar';

  @override
  bool get cargado => _lrt != null || _tfliteJs != null;

  @override
  List<int> get formaEntrada => _entrada;

  @override
  List<int> get formaSalida => _salida;

  @override
  String get backend => _backend;

  @override
  Future<void> cargar(
    String rutaAsset, {
    required List<int> formaEntradaEsperada,
    required List<int> formaSalidaEsperada,
    int hilos = 4,
  }) async {
    if (cargado) return;
    _entrada = formaEntradaEsperada;
    _salida = formaSalidaEsperada;

    final datos = await rootBundle.load(rutaAsset);
    final bytes = datos.buffer.asUint8List(
      datos.offsetInBytes,
      datos.lengthInBytes,
    );

    try {
      final lrt = await LiteRtInterpreter.fromBytes(
        bytes,
        accelerator: 'webgpu',
      );
      _lrt = lrt;
      _backend = lrt.activeAccelerator == 'webgpu'
          ? 'LiteRT.js WebGPU'
          : 'LiteRT.js WASM';
    } catch (_) {
      await initializeWeb();
      _tfliteJs = await Interpreter.fromBytes(bytes);
      _backend = 'tflite-js WASM';
    }
  }

  @override
  Future<void> ejecutar(Float32List entrada, Float32List salida) async {
    final lrt = _lrt;
    if (lrt != null) {
      await lrt.runForMultipleInputs(
        <Object>[entrada],
        <int, Object>{0: salida},
      );
      return;
    }
    final js = _tfliteJs;
    if (js == null) {
      throw StateError('El modelo no está cargado.');
    }
    // tflite-js solo rellena destinos ByteBuffer "en sitio".
    js.runForMultipleInputs(
      <Object>[entrada.buffer],
      <int, Object>{0: salida.buffer},
    );
  }

  @override
  Future<void> cerrar() async {
    _lrt?.close();
    _lrt = null;
    _tfliteJs?.close();
    _tfliteJs = null;
  }
}
