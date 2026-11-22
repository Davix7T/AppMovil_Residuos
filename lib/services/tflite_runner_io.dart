// Implementación NATIVA (Android, iOS, escritorio).
import 'dart:typed_data';

import 'package:flutter_litert/flutter_litert.dart';

import 'tflite_runner_base.dart';

TfliteRunner crearRunner() => _RunnerNativo();

class _RunnerNativo implements TfliteRunner {
  Interpreter? _interprete;
  IsolateInterpreter? _aislado;
  List<int> _entrada = const [];
  List<int> _salida = const [];
  int _hilos = 4;

  @override
  bool get cargado => _aislado != null;

  @override
  List<int> get formaEntrada => _entrada;

  @override
  List<int> get formaSalida => _salida;

  @override
  String get backend => 'LiteRT CPU ($_hilos hilos, hilo aparte)';

  @override
  Future<void> cargar(
    String rutaAsset, {
    required List<int> formaEntradaEsperada,
    required List<int> formaSalidaEsperada,
    int hilos = 4,
  }) async {
    if (cargado) return;
    _hilos = hilos;

    final opciones = InterpreterOptions()..threads = hilos;
    final interprete = await Interpreter.fromAsset(
      rutaAsset,
      options: opciones,
    );
    interprete.allocateTensors();

    final entrada = interprete.getInputTensor(0).shape;
    final salida = interprete.getOutputTensor(0).shape;

    if (!_igual(entrada, formaEntradaEsperada) ||
        !_igual(salida, formaSalidaEsperada)) {
      interprete.close();
      throw StateError(
        'Formas inesperadas en $rutaAsset: entrada $entrada (esperada '
        '$formaEntradaEsperada), salida $salida (esperada '
        '$formaSalidaEsperada).',
      );
    }

    _interprete = interprete;
    _entrada = entrada;
    _salida = salida;
    // La inferencia se ejecuta en un isolate para no bloquear la interfaz.
    _aislado = await IsolateInterpreter.create(address: interprete.address);
  }

  @override
  Future<void> ejecutar(Float32List entrada, Float32List salida) async {
    final aislado = _aislado;
    if (aislado == null) {
      throw StateError('El modelo no está cargado.');
    }
    await aislado.run(entrada, salida);
  }

  @override
  Future<void> cerrar() async {
    // Primero el isolate (mata el hilo), después el intérprete nativo.
    await _aislado?.close();
    _aislado = null;
    _interprete?.close();
    _interprete = null;
  }

  static bool _igual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
