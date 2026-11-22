import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import '../lib/services/frame_rgb.dart';
import '../lib/services/yolo_decoder.dart';

const int anclas = 10;
const int canales = 84;

/// Tensor [84, anclas] por canales con una única detección en la ancla [i].
void poner(Float32List s, int i, double cx, double cy, double w, double h,
    int clase, double p) {
  s[0 * anclas + i] = cx;
  s[1 * anclas + i] = cy;
  s[2 * anclas + i] = w;
  s[3 * anclas + i] = h;
  s[(4 + clase) * anclas + i] = p;
}

void main() {
  // Fotograma vertical 480 x 640 -> letterbox 640: escala 1, pad horizontal 80.
  const lb = InfoLetterbox(
      escala: 1.0, padIzq: 80, padArriba: 0, anchoNuevo: 480, altoNuevo: 640);

  List<CajaDeteccion> decodificar(Float32List s, DecodificadorYolo d) =>
      d.decodificar(s,
          canales: canales, anclas: anclas, canalPrimero: true,
          tamEntrada: 640, letterbox: lb, anchoFrame: 480, altoFrame: 640);

  test('el modelo COCO tiene 80 clases', () {
    expect(etiquetasCoco.length, 80);
    expect(etiquetasCoco[39], 'bottle');
  });

  test('coordenadas normalizadas se convierten al fotograma', () {
    final s = Float32List(canales * anclas);
    // Centro en el medio de la entrada (0.5, 0.5), caja 0.25 x 0.25.
    poner(s, 3, 0.5, 0.5, 0.25, 0.25, 39, 0.9);
    final r = decodificar(s, const DecodificadorYolo(etiquetas: etiquetasCoco));
    expect(r.length, 1);
    expect(r[0].etiqueta, 'bottle');
    // En píxeles de entrada: x 240..400, y 240..400 -> restar pad 80 -> 160..320
    expect(r[0].izq, closeTo(160 / 480, 1e-4));
    expect(r[0].der, closeTo(320 / 480, 1e-4));
    expect(r[0].arriba, closeTo(240 / 640, 1e-4));
    expect(r[0].abajo, closeTo(400 / 640, 1e-4));
  });

  test('coordenadas en píxeles también se soportan (autodetección)', () {
    final s = Float32List(canales * anclas);
    poner(s, 3, 320, 320, 160, 160, 39, 0.9);
    final r = decodificar(s, const DecodificadorYolo(etiquetas: etiquetasCoco));
    expect(r.length, 1);
    expect(r[0].izq, closeTo(160 / 480, 1e-4));
    expect(r[0].der, closeTo(320 / 480, 1e-4));
  });

  test('bajo el umbral no hay detección', () {
    final s = Float32List(canales * anclas);
    poner(s, 3, 0.5, 0.5, 0.25, 0.25, 39, 0.30);
    expect(decodificar(s, const DecodificadorYolo(etiquetas: etiquetasCoco)), isEmpty);
  });

  test('una persona no se convierte en botella (el argmax manda)', () {
    final s = Float32List(canales * anclas);
    poner(s, 3, 0.5, 0.5, 0.25, 0.25, 0, 0.90); // person
    s[(4 + 39) * anclas + 3] = 0.50; // bottle, menor
    final r = decodificar(
      s,
      const DecodificadorYolo(etiquetas: etiquetasCoco, clasesPermitidas: {39}),
    );
    expect(r, isEmpty);
  });

  test('NMS elimina duplicados de la misma clase', () {
    final s = Float32List(canales * anclas);
    poner(s, 1, 0.50, 0.50, 0.25, 0.25, 39, 0.90);
    poner(s, 2, 0.51, 0.50, 0.25, 0.25, 39, 0.80);
    poner(s, 3, 0.52, 0.51, 0.25, 0.25, 39, 0.70);
    final r = decodificar(s, const DecodificadorYolo(etiquetas: etiquetasCoco));
    expect(r.length, 1);
    expect(r[0].puntaje, closeTo(0.90, 1e-6));
  });

  test('objetos separados se conservan', () {
    final s = Float32List(canales * anclas);
    poner(s, 1, 0.30, 0.30, 0.15, 0.15, 39, 0.90);
    poner(s, 2, 0.70, 0.70, 0.15, 0.15, 41, 0.80);
    final r = decodificar(s, const DecodificadorYolo(etiquetas: etiquetasCoco));
    expect(r.length, 2);
  });

  test('disposición transpuesta [anclas, canales] también funciona', () {
    final s = Float32List(canales * anclas);
    const i = 4;
    s[i * canales + 0] = 0.5;
    s[i * canales + 1] = 0.5;
    s[i * canales + 2] = 0.25;
    s[i * canales + 3] = 0.25;
    s[i * canales + 4 + 41] = 0.85;
    final r = const DecodificadorYolo(etiquetas: etiquetasCoco).decodificar(s,
        canales: canales, anclas: anclas, canalPrimero: false,
        tamEntrada: 640, letterbox: lb, anchoFrame: 480, altoFrame: 640);
    expect(r.length, 1);
    expect(r[0].etiqueta, 'cup');
  });
}
