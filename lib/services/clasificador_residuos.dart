
import 'package:flutter_litert/flutter_litert.dart';
import 'dart:developer' as developer;

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

  Future<void> cargarModelo() async {
    await initializeWeb();

    _interpreter = await Interpreter.fromAsset(rutaModelo);
    _interpreter!.allocateTensors();

    final entrada = _interpreter!.getInputTensor(0);
    final salida = _interpreter!.getOutputTensor(0);

    developer.log('Modelo cargado correctamente.');
    developer.log('Forma de entrada: ${entrada.shape}');
    developer.log('Tipo de entrada: ${entrada.type}');
    developer.log('Forma de salida: ${salida.shape}');
    developer.log('Tipo de salida: ${salida.type}');
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
