import 'package:flutter_test/flutter_test.dart';
import 'package:app_movil/services/rastreador.dart';
import 'package:app_movil/services/yolo_decoder.dart';

CajaDeteccion caja(double x, double y, {int clase = 39, double p = 0.8}) =>
    CajaDeteccion(
      izq: x, arriba: y, der: x + 0.2, abajo: y + 0.2,
      clase: clase, etiqueta: etiquetasCoco[clase], puntaje: p,
    );

void main() {
  test('una caja solo es visible tras 2 fotogramas seguidos', () {
    final r = Rastreador();
    expect(r.actualizar([caja(0.3, 0.3)]), isEmpty);
    expect(r.actualizar([caja(0.31, 0.3)]).length, 1);
  });

  test('un falso positivo de un solo fotograma nunca se muestra', () {
    final r = Rastreador();
    r.actualizar([caja(0.3, 0.3)]);
    for (var i = 0; i < 5; i++) {
      expect(r.actualizar([]), isEmpty);
    }
    expect(r.pistas, isEmpty);
  });

  test('el id se mantiene mientras el objeto se mueve poco', () {
    final r = Rastreador();
    r.actualizar([caja(0.30, 0.30)]);
    final a = r.actualizar([caja(0.31, 0.30)]).first.id;
    final b = r.actualizar([caja(0.32, 0.31)]).first.id;
    expect(a, b);
  });

  test('clases distintas no se mezclan aunque se solapen', () {
    final r = Rastreador();
    r.actualizar([caja(0.3, 0.3, clase: 39)]);
    r.actualizar([caja(0.3, 0.3, clase: 39)]);
    final v = r.actualizar([caja(0.3, 0.3, clase: 41)]);
    expect(v.where((p) => p.clase == 41), isEmpty); // la nueva aún no confirma
  });

  test('desaparece tras demasiados fotogramas sin verse', () {
    final r = Rastreador();
    r.actualizar([caja(0.3, 0.3)]);
    r.actualizar([caja(0.3, 0.3)]);
    for (var i = 0; i < 4; i++) {
      r.actualizar([]);
    }
    expect(r.pistas, isEmpty);
  });

  test('el material se decide por voto de las últimas clasificaciones', () {
    final r = Rastreador();
    r.actualizar([caja(0.3, 0.3)]);
    final p = r.actualizar([caja(0.3, 0.3)]).first;
    expect(p.materialVotado, isNull);
    expect(p.necesitaClasificar(0, 900), isTrue);
    p.registrarMaterial('plastic', 0.9, 0);
    p.registrarMaterial('glass', 0.5, 1000);
    p.registrarMaterial('plastic', 0.8, 2000);
    expect(p.materialVotado!.etiqueta, 'plastic');
    expect(p.necesitaClasificar(2500, 900), isFalse);
    expect(p.necesitaClasificar(3000, 900), isTrue);
  });
}
