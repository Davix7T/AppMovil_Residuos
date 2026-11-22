import 'dart:typed_data';

import 'frame_rgb.dart';
import 'tflite_runner.dart';
import 'yolo_decoder.dart';

/// Detector de objetos YOLOv8 (por defecto YOLOv8n entrenado en COCO).
///
/// Para usar un modelo propio entrenado con residuos (por ejemplo YOLOv8
/// exportado a TFLite con clases "plastic", "paper"...), basta con cambiar
/// [rutaModelo], [etiquetas] y, si el tamaño de entrada es otro, [tamEntrada].
/// El resto del pipeline no cambia.
class YoloDetector {
  final String rutaModelo;
  final int tamEntrada;
  final List<String> etiquetas;
  final bool canalPrimero;

  /// Etiquetas que se conservan (null = todas).
  final Set<String>? etiquetasPermitidas;

  final double umbral;
  final int hilos;

  late final int _canales = etiquetas.length + 4;
  late final int _anclas = _contarAnclas(tamEntrada);

  final TfliteRunner _runner = crearRunner();
  late final Float32List _entrada = Float32List(tamEntrada * tamEntrada * 3);
  late final Float32List _salida = Float32List(_canales * _anclas);
  late final DecodificadorYolo _decodificador = DecodificadorYolo(
    etiquetas: etiquetas,
    clasesPermitidas: etiquetasPermitidas == null
        ? null
        : {
            for (var i = 0; i < etiquetas.length; i++)
              if (etiquetasPermitidas!.contains(etiquetas[i])) i,
          },
    umbral: umbral,
  );

  YoloDetector({
    this.rutaModelo = 'assets/models/yolov8n_float32.tflite',
    this.tamEntrada = 640,
    this.etiquetas = etiquetasCoco,
    this.canalPrimero = true,
    this.etiquetasPermitidas,
    this.umbral = 0.40,
    this.hilos = 4,
  });

  bool get cargado => _runner.cargado;
  String get backend => _runner.backend;

  /// Anclas de YOLOv8 para strides 8, 16 y 32 (640 -> 8400).
  static int _contarAnclas(int tam) {
    int n(int stride) => (tam ~/ stride) * (tam ~/ stride);
    return n(8) + n(16) + n(32);
  }

  Future<void> cargar() async {
    if (_runner.cargado) return;
    await _runner.cargar(
      rutaModelo,
      formaEntradaEsperada: [1, tamEntrada, tamEntrada, 3],
      formaSalidaEsperada: canalPrimero
          ? [1, _canales, _anclas]
          : [1, _anclas, _canales],
      hilos: hilos,
    );
  }

  /// Detecta objetos en un fotograma vertical. NO es reentrante: el llamador
  /// debe esperar a que termine antes de enviar otro fotograma.
  Future<List<CajaDeteccion>> detectar(FrameRgb frame) async {
    final lb = frame.llenarLetterbox(_entrada, tamEntrada);
    await _runner.ejecutar(_entrada, _salida);
    return _decodificador.decodificar(
      _salida,
      canales: _canales,
      anclas: _anclas,
      canalPrimero: canalPrimero,
      tamEntrada: tamEntrada,
      letterbox: lb,
      anchoFrame: frame.ancho,
      altoFrame: frame.alto,
    );
  }

  Future<void> cerrar() => _runner.cerrar();
}
