// Lógica pura de Dart (sin Flutter): fotograma RGB "vertical" (ya rotado) y
// las conversiones a tensores que necesitan los modelos.
//
// Un único tipo de fotograma sirve para Android (YUV420 del image stream) y
// para Chrome (RGBA decodificado por el navegador), de modo que el resto del
// pipeline (detector, clasificador, rastreador) es idéntico en ambas
// plataformas.

import 'dart:math' as math;
import 'dart:typed_data';

/// Normalización de entrada del modelo.
enum NormalizacionEntrada {
  /// [0, 1]  (pixel / 255). Es lo que usaba el clasificador original.
  ceroUno,

  /// [-1, 1] (típico de MobileNet/EfficientNet de Keras sin capa Rescaling).
  menosUnoUno,

  /// [0, 255] sin escalar (modelos con la normalización dentro del grafo).
  crudo,
}

Float32List _tabla(NormalizacionEntrada n) {
  final t = Float32List(256);
  for (var i = 0; i < 256; i++) {
    switch (n) {
      case NormalizacionEntrada.ceroUno:
        t[i] = i / 255.0;
      case NormalizacionEntrada.menosUnoUno:
        t[i] = i / 127.5 - 1.0;
      case NormalizacionEntrada.crudo:
        t[i] = i.toDouble();
    }
  }
  return t;
}

final Map<NormalizacionEntrada, Float32List> _tablas = {
  for (final n in NormalizacionEntrada.values) n: _tabla(n),
};

/// Parámetros del letterbox (imagen escalada y centrada con relleno).
class InfoLetterbox {
  final double escala;
  final int padIzq;
  final int padArriba;
  final int anchoNuevo;
  final int altoNuevo;

  const InfoLetterbox({
    required this.escala,
    required this.padIzq,
    required this.padArriba,
    required this.anchoNuevo,
    required this.altoNuevo,
  });
}

class FrameRgb {
  final int ancho;
  final int alto;

  /// 3 bytes por píxel (R, G, B), filas contiguas, sin relleno.
  final Uint8List rgb;

  FrameRgb(this.ancho, this.alto, this.rgb)
    : assert(rgb.length >= ancho * alto * 3);

  /// Desde RGBA (lo que entrega `ui.Image.toByteData(rawRgba)`; Chrome).
  factory FrameRgb.desdeRgba(int ancho, int alto, Uint8List rgba) {
    final out = Uint8List(ancho * alto * 3);
    var s = 0;
    var d = 0;
    final n = ancho * alto;
    for (var i = 0; i < n; i++) {
      out[d++] = rgba[s];
      out[d++] = rgba[s + 1];
      out[d++] = rgba[s + 2];
      s += 4;
    }
    return FrameRgb(ancho, alto, out);
  }

  /// Desde un fotograma YUV420 del sensor (Android `startImageStream`).
  ///
  /// [rotacion] (0/90/180/270) es el giro HORARIO que hay que aplicar al
  /// fotograma del sensor para dejarlo vertical. El resultado se reduce para
  /// que su lado mayor no pase de [maxLado] (muestreo directo, sin convertir
  /// primero la imagen completa: es más rápido y no asigna memoria extra).
  factory FrameRgb.desdeYuv420({
    required int ancho,
    required int alto,
    required Uint8List y,
    required Uint8List u,
    required Uint8List v,
    required int filaY,
    required int filaUV,
    required int pixelUV,
    int rotacion = 0,
    int maxLado = 640,
  }) {
    final giro = rotacion % 360;
    final intercambia = giro == 90 || giro == 270;
    final uw = intercambia ? alto : ancho;
    final uh = intercambia ? ancho : alto;
    final escala = math.min(1.0, maxLado / math.max(uw, uh));
    final ow = math.max(1, (uw * escala).round());
    final oh = math.max(1, (uh * escala).round());

    final out = Uint8List(ow * oh * 3);
    var d = 0;
    for (var oy = 0; oy < oh; oy++) {
      final uy = oy * uh ~/ oh;
      for (var ox = 0; ox < ow; ox++) {
        final ux = ox * uw ~/ ow;
        int sx;
        int sy;
        switch (giro) {
          case 90:
            sx = uy;
            sy = alto - 1 - ux;
          case 180:
            sx = ancho - 1 - ux;
            sy = alto - 1 - uy;
          case 270:
            sx = ancho - 1 - uy;
            sy = ux;
          default:
            sx = ux;
            sy = uy;
        }
        final yy = y[sy * filaY + sx];
        final uvIdx = (sy >> 1) * filaUV + (sx >> 1) * pixelUV;
        final uu = u[uvIdx] - 128;
        final vv = v[uvIdx] - 128;
        var r = yy + ((1436 * vv) >> 10);
        var g = yy - ((352 * uu + 731 * vv) >> 10);
        var b = yy + ((1814 * uu) >> 10);
        out[d++] = r < 0 ? 0 : (r > 255 ? 255 : r);
        out[d++] = g < 0 ? 0 : (g > 255 ? 255 : g);
        out[d++] = b < 0 ? 0 : (b > 255 ? 255 : b);
      }
    }
    return FrameRgb(ow, oh, out);
  }

  /// Escribe en [destino] (tam*tam*3 floats, NHWC) la imagen con letterbox:
  /// se conserva la proporción y se rellena con gris 114 (convención YOLO).
  InfoLetterbox llenarLetterbox(
    Float32List destino,
    int tam, {
    NormalizacionEntrada normalizacion = NormalizacionEntrada.ceroUno,
  }) {
    assert(destino.length >= tam * tam * 3);
    final t = _tablas[normalizacion]!;
    final escala = math.min(tam / ancho, tam / alto);
    final nw = (ancho * escala).round();
    final nh = (alto * escala).round();
    final padX = (tam - nw) ~/ 2;
    final padY = (tam - nh) ~/ 2;

    final gris = t[114];
    destino.fillRange(0, tam * tam * 3, gris);

    final mapaX = Int32List(nw);
    for (var x = 0; x < nw; x++) {
      mapaX[x] = math.min(ancho - 1, x * ancho ~/ nw) * 3;
    }
    for (var y = 0; y < nh; y++) {
      final sy = math.min(alto - 1, y * alto ~/ nh);
      final fila = sy * ancho * 3;
      var d = ((y + padY) * tam + padX) * 3;
      for (var x = 0; x < nw; x++) {
        final s = fila + mapaX[x];
        destino[d++] = t[rgb[s]];
        destino[d++] = t[rgb[s + 1]];
        destino[d++] = t[rgb[s + 2]];
      }
    }
    return InfoLetterbox(
      escala: escala,
      padIzq: padX,
      padArriba: padY,
      anchoNuevo: nw,
      altoNuevo: nh,
    );
  }

  /// Recorta una región CUADRADA alrededor de la caja normalizada
  /// ([izq],[arriba],[der],[abajo] en 0..1) y la remuestrea a tam x tam
  /// (bilineal). El recorte es cuadrado para no deformar el objeto al
  /// redimensionarlo; [margen] añade contexto alrededor de la caja.
  Float32List recorteCuadrado(
    double izq,
    double arriba,
    double der,
    double abajo,
    int tam, {
    double margen = 0.12,
    NormalizacionEntrada normalizacion = NormalizacionEntrada.ceroUno,
  }) {
    final t = _tablas[normalizacion]!;
    final cx = (izq + der) / 2 * ancho;
    final cy = (arriba + abajo) / 2 * alto;
    final bw = (der - izq) * ancho;
    final bh = (abajo - arriba) * alto;
    final lado = math.max(16.0, math.max(bw, bh) * (1 + 2 * margen));

    var x0 = cx - lado / 2;
    var y0 = cy - lado / 2;
    if (lado <= ancho) x0 = x0.clamp(0.0, ancho - lado).toDouble();
    if (lado <= alto) y0 = y0.clamp(0.0, alto - lado).toDouble();

    final out = Float32List(tam * tam * 3);
    final paso = lado / tam;
    var d = 0;
    for (var ty = 0; ty < tam; ty++) {
      final fy = (y0 + (ty + 0.5) * paso - 0.5).clamp(0.0, alto - 1.0);
      final iy = fy.floor();
      final iy2 = math.min(alto - 1, iy + 1);
      final wy = fy - iy;
      for (var tx = 0; tx < tam; tx++) {
        final fx = (x0 + (tx + 0.5) * paso - 0.5).clamp(0.0, ancho - 1.0);
        final ix = fx.floor();
        final ix2 = math.min(ancho - 1, ix + 1);
        final wx = fx - ix;
        final a = (iy * ancho + ix) * 3;
        final b = (iy * ancho + ix2) * 3;
        final c = (iy2 * ancho + ix) * 3;
        final e = (iy2 * ancho + ix2) * 3;
        for (var k = 0; k < 3; k++) {
          final arribaV = rgb[a + k] * (1 - wx) + rgb[b + k] * wx;
          final abajoV = rgb[c + k] * (1 - wx) + rgb[e + k] * wx;
          final v = arribaV * (1 - wy) + abajoV * wy;
          out[d++] = t[v.round().clamp(0, 255)];
        }
      }
    }
    return out;
  }
}
