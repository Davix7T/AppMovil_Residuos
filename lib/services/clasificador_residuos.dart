
import 'dart:typed_data';
import 'package:flutter_litert/flutter_litert.dart';
import 'package:image/image.dart' as img;

class ResultadoResiduo {
  final String etiqueta;
  final double confianza;

  const ResultadoResiduo({
    required this.etiqueta,
    required this.confianza,
  });
}

class ClasificadorResiduos {
  static const String rutaModelo =
      'assets/models/waste_model.tflite';

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

  Interpreter? _interpreter;

  bool get modeloCargado => _interpreter != null;

  Future<void> cargarModelo() async {
    if (_interpreter != null) return;

    await initializeWeb();

    final interpreter =
        await Interpreter.fromAsset(rutaModelo);

    interpreter.allocateTensors();

    final entrada = interpreter.getInputTensor(0);
    final salida = interpreter.getOutputTensor(0);

    if (entrada.shape.toString() != '[1, 224, 224, 3]' ||
        salida.shape.toString() != '[1, 12]') {
      interpreter.close();
      throw StateError(
        'Las dimensiones del modelo no coinciden '
        'con las esperadas.',
      );
    }

    _interpreter = interpreter;
  }

  ResultadoResiduo clasificarImagen(Uint8List bytes) {
    final interpreter = _interpreter;

    if (interpreter == null) {
      throw StateError(
        'Primero debes cargar el modelo.',
      );
    }

    final img.Image? imagenOriginal = img.decodeImage(bytes);

    if (imagenOriginal == null) {
      throw FormatException(
        'No se pudo leer la imagen seleccionada.',
      );
    }

    final img.Image imagenRedimensionada = img.copyResize(
      imagenOriginal,
      width: 224,
      height: 224,
    );

    final entrada = [
      List.generate(
        224,
        (y) => List.generate(
          224,
          (x) {
            final pixel = imagenRedimensionada.getPixel(x, y);

            return [
              pixel.r.toDouble() / 255.0,
              pixel.g.toDouble() / 255.0,
              pixel.b.toDouble() / 255.0,
            ];
          },
        ),
      ),
    ];

    final salida = [
      List<double>.filled(etiquetas.length, 0.0),
    ];

    interpreter.run(entrada, salida);

    final puntuaciones = salida[0];

    int indiceMayor = 0;

    for (int i = 1; i < puntuaciones.length; i++) {
      if (puntuaciones[i] > puntuaciones[indiceMayor]) {
        indiceMayor = i;
      }
    }

    return ResultadoResiduo(
      etiqueta: etiquetas[indiceMayor],
      confianza: puntuaciones[indiceMayor],
    );
  }

  void cerrar() {
    _interpreter?.close();
    _interpreter = null;
  }

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
