
class ResultadoResiduo {
  final String etiqueta;
  final double confianza;

  const ResultadoResiduo({
    required this.etiqueta,
    required this.confianza,
  });
}

class ClasificadorResiduos {
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
