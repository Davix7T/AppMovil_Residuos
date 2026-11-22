// Lógica pura de Dart (sin Flutter): reglas de clasificación por contenedor
// según el código de colores colombiano (Resolución 2184 de 2019,
// Ministerio de Ambiente y Ministerio de Vivienda):
//   verde  -> residuos orgánicos aprovechables
//   blanco -> residuos aprovechables (plástico, vidrio, metales, papel, cartón)
//   negro  -> residuos no aprovechables
// "especial" NO es un contenedor de la norma: se usa para residuos que no
// deben ir a ninguna de las tres canecas (pilas, aparatos electrónicos) y
// que requieren puntos de recolección posconsumo.

enum ContenedorColombia { verde, blanco, negro, especial }

extension ContenedorColombiaInfo on ContenedorColombia {
  String get nombre {
    switch (this) {
      case ContenedorColombia.verde:
        return 'Contenedor verde';
      case ContenedorColombia.blanco:
        return 'Contenedor blanco';
      case ContenedorColombia.negro:
        return 'Contenedor negro';
      case ContenedorColombia.especial:
        return 'Punto de recolección especial';
    }
  }

  String get descripcion {
    switch (this) {
      case ContenedorColombia.verde:
        return 'Orgánicos aprovechables';
      case ContenedorColombia.blanco:
        return 'Residuos aprovechables';
      case ContenedorColombia.negro:
        return 'Residuos no aprovechables';
      case ContenedorColombia.especial:
        return 'Posconsumo / RAEE';
    }
  }

  /// Color ARGB para dibujar (se convierte a `Color` en la capa de UI).
  int get colorArgb {
    switch (this) {
      case ContenedorColombia.verde:
        return 0xFF16A34A;
      case ContenedorColombia.blanco:
        return 0xFFFFFFFF;
      case ContenedorColombia.negro:
        return 0xFF111827;
      case ContenedorColombia.especial:
        return 0xFFF59E0B;
    }
  }
}

/// Contenedor según la etiqueta del clasificador de 12 materiales.
ContenedorColombia contenedorPorMaterial(String etiqueta) {
  switch (etiqueta) {
    case 'biological':
      return ContenedorColombia.verde;
    case 'brown-glass':
    case 'green-glass':
    case 'white-glass':
    case 'cardboard':
    case 'metal':
    case 'paper':
    case 'plastic':
      return ContenedorColombia.blanco;
    case 'battery':
      return ContenedorColombia.especial;
    case 'clothes':
    case 'shoes':
    case 'trash':
    default:
      return ContenedorColombia.negro;
  }
}

/// Cómo se combina la detección de objeto (YOLO/COCO) con el clasificador
/// de material.
enum ReglaFusion {
  /// El objeto define el contenedor (alimentos -> verde). No se reclasifica.
  alimento,

  /// El objeto define el contenedor (electrónicos -> especial).
  electronico,

  /// El objeto es un envase/objeto cuyo material decide el contenedor.
  /// Si el clasificador no está seguro, se usa [PerfilObjeto.contenedorBase].
  refinarConMaterial,
}

class PerfilObjeto {
  final String nombre;
  final ContenedorColombia contenedorBase;
  final ReglaFusion regla;

  const PerfilObjeto(this.nombre, this.contenedorBase, this.regla);
}

/// Clases COCO (las 80 del modelo YOLOv8n) que el sistema considera
/// residuos. Cualquier otra clase (persona, silla, auto, mesa...) se
/// descarta: es la principal defensa contra falsos positivos.
const Map<String, PerfilObjeto> perfilesCoco = {
  // Envases y objetos: el material decide.
  'bottle': PerfilObjeto(
      'Botella', ContenedorColombia.blanco, ReglaFusion.refinarConMaterial),
  'wine glass': PerfilObjeto(
      'Copa', ContenedorColombia.blanco, ReglaFusion.refinarConMaterial),
  'cup': PerfilObjeto(
      'Vaso', ContenedorColombia.negro, ReglaFusion.refinarConMaterial),
  'fork': PerfilObjeto(
      'Cubierto', ContenedorColombia.negro, ReglaFusion.refinarConMaterial),
  'knife': PerfilObjeto(
      'Cubierto', ContenedorColombia.negro, ReglaFusion.refinarConMaterial),
  'spoon': PerfilObjeto(
      'Cubierto', ContenedorColombia.negro, ReglaFusion.refinarConMaterial),
  'book': PerfilObjeto(
      'Libro / papel', ContenedorColombia.blanco, ReglaFusion.refinarConMaterial),
  'toothbrush': PerfilObjeto('Cepillo de dientes', ContenedorColombia.negro,
      ReglaFusion.refinarConMaterial),
  // Alimentos: orgánicos aprovechables.
  'banana': PerfilObjeto('Banano', ContenedorColombia.verde, ReglaFusion.alimento),
  'apple': PerfilObjeto('Manzana', ContenedorColombia.verde, ReglaFusion.alimento),
  'orange': PerfilObjeto('Naranja', ContenedorColombia.verde, ReglaFusion.alimento),
  'broccoli':
      PerfilObjeto('Brócoli', ContenedorColombia.verde, ReglaFusion.alimento),
  'carrot':
      PerfilObjeto('Zanahoria', ContenedorColombia.verde, ReglaFusion.alimento),
  'sandwich':
      PerfilObjeto('Sándwich', ContenedorColombia.verde, ReglaFusion.alimento),
  'hot dog':
      PerfilObjeto('Perro caliente', ContenedorColombia.verde, ReglaFusion.alimento),
  'pizza': PerfilObjeto('Pizza', ContenedorColombia.verde, ReglaFusion.alimento),
  'donut': PerfilObjeto('Dona', ContenedorColombia.verde, ReglaFusion.alimento),
  'cake': PerfilObjeto('Pastel', ContenedorColombia.verde, ReglaFusion.alimento),
};

/// Electrónicos (RAEE). Desactivados por defecto: un celular en la mano no es
/// un residuo y generaría "falsos positivos". Se activan con
/// `ConfigAnalizador.incluirElectronicos`.
const Map<String, PerfilObjeto> perfilesElectronicos = {
  'cell phone': PerfilObjeto(
      'Celular (RAEE)', ContenedorColombia.especial, ReglaFusion.electronico),
  'remote': PerfilObjeto(
      'Control (RAEE)', ContenedorColombia.especial, ReglaFusion.electronico),
  'mouse': PerfilObjeto(
      'Mouse (RAEE)', ContenedorColombia.especial, ReglaFusion.electronico),
  'keyboard': PerfilObjeto(
      'Teclado (RAEE)', ContenedorColombia.especial, ReglaFusion.electronico),
  'laptop': PerfilObjeto(
      'Portátil (RAEE)', ContenedorColombia.especial, ReglaFusion.electronico),
};

/// Materiales que un objeto "refinable" (botella, vaso...) puede tener.
/// Se ignoran materiales imposibles (una botella no es 'biological', 'shoes'...).
const Set<String> materialesCompatibles = {
  'brown-glass',
  'green-glass',
  'white-glass',
  'cardboard',
  'metal',
  'paper',
  'plastic',
  'trash',
};

/// Resultado de combinar objeto + material.
class DecisionContenedor {
  final ContenedorColombia contenedor;

  /// Material usado para decidir (null si se usó solo la regla del objeto).
  final String? materialUsado;

  const DecisionContenedor(this.contenedor, this.materialUsado);
}

/// Fusiona la clase detectada con la predicción del clasificador de material.
///
/// [umbralMaterial] es la confianza mínima del clasificador para que pueda
/// cambiar el contenedor base del objeto.
DecisionContenedor decidirContenedor(
  PerfilObjeto perfil, {
  String? material,
  double confianzaMaterial = 0,
  double umbralMaterial = 0.55,
}) {
  if (perfil.regla != ReglaFusion.refinarConMaterial) {
    return DecisionContenedor(perfil.contenedorBase, null);
  }
  if (material != null &&
      confianzaMaterial >= umbralMaterial &&
      materialesCompatibles.contains(material)) {
    return DecisionContenedor(contenedorPorMaterial(material), material);
  }
  return DecisionContenedor(perfil.contenedorBase, null);
}
