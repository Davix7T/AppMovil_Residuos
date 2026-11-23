import 'package:flutter_test/flutter_test.dart';
import 'package:app_movil/services/contenedores.dart';

void main() {
  group('contenedorPorMaterial', () {
    test('materiales aprovechables van al blanco', () {
      for (final m in [
        'plastic', 'paper', 'cardboard', 'metal',
        'brown-glass', 'green-glass', 'white-glass'
      ]) {
        expect(contenedorPorMaterial(m), ContenedorColombia.blanco, reason: m);
      }
    });

    test('orgánicos al verde, no aprovechables al negro, pilas a especial', () {
      expect(contenedorPorMaterial('biological'), ContenedorColombia.verde);
      expect(contenedorPorMaterial('trash'), ContenedorColombia.negro);
      expect(contenedorPorMaterial('clothes'), ContenedorColombia.negro);
      expect(contenedorPorMaterial('shoes'), ContenedorColombia.negro);
      expect(contenedorPorMaterial('battery'), ContenedorColombia.especial);
      expect(contenedorPorMaterial('desconocido'), ContenedorColombia.negro);
    });
  });

  group('decidirContenedor', () {
    final botella = perfilesCoco['bottle']!;
    final vaso = perfilesCoco['cup']!;
    final banano = perfilesCoco['banana']!;

    test('botella de plástico con material seguro -> blanco', () {
      final d = decidirContenedor(botella, material: 'plastic', confianzaMaterial: 0.9);
      expect(d.contenedor, ContenedorColombia.blanco);
      expect(d.materialUsado, 'plastic');
    });

    test('material poco confiable se ignora y manda el objeto', () {
      final d = decidirContenedor(vaso, material: 'paper', confianzaMaterial: 0.40);
      expect(d.contenedor, ContenedorColombia.negro);
      expect(d.materialUsado, isNull);
    });

    test('vaso con material seguro cambia de contenedor', () {
      final d = decidirContenedor(vaso, material: 'paper', confianzaMaterial: 0.8);
      expect(d.contenedor, ContenedorColombia.blanco);
    });

    test('material imposible para el objeto se descarta', () {
      final d = decidirContenedor(botella, material: 'shoes', confianzaMaterial: 0.99);
      expect(d.contenedor, ContenedorColombia.blanco);
      expect(d.materialUsado, isNull);
    });

    test('alimentos siempre al verde sin consultar el material', () {
      final d = decidirContenedor(banano, material: 'plastic', confianzaMaterial: 0.99);
      expect(d.contenedor, ContenedorColombia.verde);
      expect(d.materialUsado, isNull);
    });
  });

  test('las clases que no son residuos no tienen perfil', () {
    for (final c in ['person', 'chair', 'car', 'dining table', 'tv', 'bowl']) {
      expect(perfilesCoco.containsKey(c), isFalse, reason: c);
    }
  });
}
