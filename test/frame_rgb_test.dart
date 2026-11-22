import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import '../lib/services/frame_rgb.dart';

void main() {
  // Sensor 4x2 con valores de luminancia distintos; U = V = 128 -> gris puro.
  // Fila 0: 10 20 30 40   Fila 1: 50 60 70 80
  final y = Uint8List.fromList([10, 20, 30, 40, 50, 60, 70, 80]);
  final u = Uint8List.fromList([128, 128]);
  final v = Uint8List.fromList([128, 128]);

  FrameRgb crear(int rot) => FrameRgb.desdeYuv420(
        ancho: 4, alto: 2, y: y, u: u, v: v,
        filaY: 4, filaUV: 2, pixelUV: 1, rotacion: rot, maxLado: 100,
      );

  int px(FrameRgb f, int x, int yy) => f.rgb[(yy * f.ancho + x) * 3];

  test('rotación 0 conserva la imagen', () {
    final f = crear(0);
    expect(f.ancho, 4);
    expect(f.alto, 2);
    expect(px(f, 0, 0), 10);
    expect(px(f, 3, 1), 80);
  });

  test('rotación 90 horaria: esquina sup-izq del sensor -> sup-der', () {
    final f = crear(90);
    expect(f.ancho, 2);
    expect(f.alto, 4);
    // sensor (sx=0, sy=0)=10 -> vertical (ux = alto-1-sy = 1, uy = sx = 0)
    expect(px(f, 1, 0), 10);
    // sensor (3,1)=80 -> (ux = 0, uy = 3)
    expect(px(f, 0, 3), 80);
  });

  test('rotación 270 horaria: esquina sup-izq del sensor -> inf-izq', () {
    final f = crear(270);
    expect(f.ancho, 2);
    expect(f.alto, 4);
    // sensor (0,0)=10 -> (ux = sy = 0, uy = ancho-1-sx = 3)
    expect(px(f, 0, 3), 10);
    // sensor (3,1)=80 -> (ux = 1, uy = 0)
    expect(px(f, 1, 0), 80);
  });

  test('rotación 180 invierte ambos ejes', () {
    final f = crear(180);
    expect(px(f, 0, 0), 80);
    expect(px(f, 3, 1), 10);
  });

  test('maxLado reduce el fotograma conservando la proporción', () {
    final f = FrameRgb.desdeYuv420(
      ancho: 4, alto: 2, y: y, u: u, v: v,
      filaY: 4, filaUV: 2, pixelUV: 1, rotacion: 0, maxLado: 2,
    );
    expect(f.ancho, 2);
    expect(f.alto, 1);
  });

  test('YUV gris produce RGB gris', () {
    final f = crear(0);
    expect(f.rgb[0], f.rgb[1]);
    expect(f.rgb[1], f.rgb[2]);
  });

  test('desdeRgba descarta el canal alfa', () {
    final f = FrameRgb.desdeRgba(2, 1, Uint8List.fromList([1, 2, 3, 255, 4, 5, 6, 255]));
    expect(f.rgb.toList(), [1, 2, 3, 4, 5, 6]);
  });

  test('letterbox centra la imagen y rellena con gris 114', () {
    // 4x2 -> tam 8: escala 2, imagen 8x4, relleno vertical de 2 filas.
    final f = FrameRgb(4, 2, Uint8List.fromList(List.filled(4 * 2 * 3, 255)));
    final buf = Float32List(8 * 8 * 3);
    final lb = f.llenarLetterbox(buf, 8);
    expect(lb.escala, 2.0);
    expect(lb.padIzq, 0);
    expect(lb.padArriba, 2);
    expect(buf[0], closeTo(114 / 255, 1e-6)); // fila 0 = relleno
    expect(buf[(2 * 8) * 3], closeTo(1.0, 1e-6)); // fila 2 = imagen
    expect(buf[(7 * 8) * 3], closeTo(114 / 255, 1e-6)); // fila 7 = relleno
  });

  test('normalización [-1, 1]', () {
    final f = FrameRgb(1, 1, Uint8List.fromList([0, 255, 0]));
    final t = f.recorteCuadrado(0, 0, 1, 1, 2,
        margen: 0, normalizacion: NormalizacionEntrada.menosUnoUno);
    expect(t[0], closeTo(-1.0, 1e-6));
    expect(t[1], closeTo(1.0, 1e-6));
  });

  test('recorte cuadrado de imagen uniforme es uniforme', () {
    final f = FrameRgb(20, 10, Uint8List.fromList(List.filled(20 * 10 * 3, 51)));
    final t = f.recorteCuadrado(0.2, 0.2, 0.6, 0.8, 8);
    expect(t.length, 8 * 8 * 3);
    for (final x in t) {
      expect(x, closeTo(51 / 255, 1e-6));
    }
  });
}
