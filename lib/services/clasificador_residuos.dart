import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'frame_rgb.dart';
import 'tflite_runner.dart';

class PrediccionResiduo {
  final String etiqueta;
  final double confianza;

  const PrediccionResiduo({required this.etiqueta, required this.confianza});
}

class ResultadoResiduo {
  final String etiqueta;
  final double confianza;
  final List<PrediccionResiduo> alternativas;

  const ResultadoResiduo({
    required this.etiqueta,
    required this.confianza,
    this.alternativas = const [],
  });

  /// Diferencia entre la mejor y la segunda mejor puntuación. Un margen bajo
  /// indica que el modelo duda entre dos categorías.
  double get margen => alternativas.length < 2
      ? confianza
      : confianza - alternativas[1].confianza;
}

/// Clasificador de material (12 clases). Sigue siendo el modelo original
/// `waste_model.tflite`, pero ahora:
///  * se usa sobre el RECORTE de cada objeto detectado (no sobre todo el
///    fotograma), que es la causa principal de las etiquetas incorrectas;
///  * se ejecuta con buffers planos (Float32List) en lugar de listas
///    anidadas, y fuera del hilo de la UI en Android;
///  * si el modelo entrega logits en vez de probabilidades, se aplica softmax.
class ClasificadorResiduos {
  static const String rutaModelo = 'assets/models/waste_model.tflite';
  static const int tamEntrada = 224;

  /// Normalización de entrada. El código original usaba /255 -> [0, 1].
  /// Si el modelo se entrenó con MobileNet/EfficientNet sin capa Rescaling
  /// interna, cambia a `NormalizacionEntrada.menosUnoUno` y compara la
  /// precisión (ver CAMBIOS.md, sección "Cómo verificar la normalización").
  static const NormalizacionEntrada normalizacion =
      NormalizacionEntrada.ceroUno;

  /// Activa el registro de las 3 mejores clases en cada inferencia.
  static const bool registroDetallado = false;

  static const List<String> etiquetas = [
    'battery',
    'biological',
    'brown-glass',
    'cardboard',
    'clothes',
    'green-glass',
    'metal',
    'paper',
    'plastic',
    'shoes',
    'trash',
    'white-glass',
  ];

  final TfliteRunner _runner = crearRunner();
  final Float32List _salida = Float32List(etiquetas.length);

  Future<void> _cola = Future.value();

  bool get modeloCargado => _runner.cargado;

  String get backend => _runner.backend;

  Future<void> cargarModelo() async {
    if (_runner.cargado) return;
    await _runner.cargar(
      rutaModelo,
      formaEntradaEsperada: const [1, tamEntrada, tamEntrada, 3],
      formaSalidaEsperada: [1, etiquetas.length],
      hilos: 2,
    );
  }

  /// Clasifica una imagen completa (flujo "tomar foto / galería").
  /// Mantiene el redimensionamiento original (224 x 224 estirado), que es el
  /// que usó el entrenamiento del modelo. Ahora es asíncrono.
  Future<ResultadoResiduo> clasificarImagen(Uint8List bytes) async {
    if (!_runner.cargado) {
      throw StateError('Primero debes cargar el modelo.');
    }

    final img.Image? imagenOriginal = img.decodeImage(bytes);
    if (imagenOriginal == null) {
      throw const FormatException('No se pudo leer la imagen seleccionada.');
    }

    final img.Image redim = img.copyResize(
      imagenOriginal,
      width: tamEntrada,
      height: tamEntrada,
    );

    final rgb = Uint8List(tamEntrada * tamEntrada * 3);
    var i = 0;
    for (var y = 0; y < tamEntrada; y++) {
      for (var x = 0; x < tamEntrada; x++) {
        final p = redim.getPixel(x, y);
        rgb[i++] = p.r.toInt();
        rgb[i++] = p.g.toInt();
        rgb[i++] = p.b.toInt();
      }
    }
    final frame = FrameRgb(tamEntrada, tamEntrada, rgb);
    final tensor = frame.recorteCuadrado(
      0,
      0,
      1,
      1,
      tamEntrada,
      margen: 0,
      normalizacion: normalizacion,
    );
    return clasificarTensor(tensor);
  }

  /// Clasifica un recorte ya preparado (tamEntrada x tamEntrada x 3, NHWC,
  /// normalizado). Lo usa el analizador en vivo con el recorte de cada objeto.
  Future<ResultadoResiduo> clasificarTensor(Float32List entrada) {
    return _enCola(() async {
      if (!_runner.cargado) {
        throw StateError('Primero debes cargar el modelo.');
      }
      await _runner.ejecutar(entrada, _salida);
      return _interpretar(_salida);
    });
  }

  ResultadoResiduo _interpretar(Float32List cruda) {
    final puntuaciones = _aProbabilidades(cruda);

    final indices = List<int>.generate(puntuaciones.length, (i) => i)
      ..sort((a, b) => puntuaciones[b].compareTo(puntuaciones[a]));

    final mejores = indices
        .take(3)
        .map(
          (i) => PrediccionResiduo(
            etiqueta: etiquetas[i],
            confianza: puntuaciones[i],
          ),
        )
        .toList();

    if (kDebugMode && registroDetallado) {
      debugPrint('--- RESULTADOS DEL MODELO ---');
      for (final p in mejores) {
        debugPrint('${p.etiqueta}: ${(p.confianza * 100).toStringAsFixed(2)}%');
      }
    }

    return ResultadoResiduo(
      etiqueta: mejores.first.etiqueta,
      confianza: mejores.first.confianza,
      alternativas: mejores,
    );
  }

  /// Si la salida ya son probabilidades (en [0,1] y suman ~1) se usa tal
  /// cual; si son logits, se aplica softmax. Sin esto, un modelo sin softmax
  /// final mostraría "confianzas" mayores a 100 % o negativas.
  static List<double> _aProbabilidades(Float32List s) {
    var suma = 0.0;
    var enRango = true;
    for (final v in s) {
      if (v < 0 || v > 1) enRango = false;
      suma += v;
    }
    if (enRango && (suma - 1).abs() < 0.05) {
      return List<double>.generate(s.length, (i) => s[i].toDouble());
    }
    var maxV = s[0].toDouble();
    for (final v in s) {
      if (v > maxV) maxV = v.toDouble();
    }
    final exps = [for (final v in s) math.exp(v - maxV)];
    final total = exps.reduce((a, b) => a + b);
    return [for (final e in exps) e / total];
  }

  Future<T> _enCola<T>(Future<T> Function() tarea) {
    final r = _cola.then((_) => tarea());
    _cola = r.then<void>((_) {}, onError: (_) {});
    return r;
  }

  Future<void> cerrar() => _runner.cerrar();

  String nombreEnEspanol(String etiqueta) {
    const traducciones = {
      'battery': 'Batería',
      'biological': 'Residuo orgánico',
      'brown-glass': 'Vidrio marrón',
      'cardboard': 'Cartón',
      'clothes': 'Ropa',
      'green-glass': 'Vidrio verde',
      'metal': 'Metal',
      'paper': 'Papel',
      'plastic': 'Plástico',
      'shoes': 'Calzado',
      'trash': 'Otros residuos',
      'white-glass': 'Vidrio transparente',
    };

    return traducciones[etiqueta] ?? 'Residuo desconocido';
  }
}
