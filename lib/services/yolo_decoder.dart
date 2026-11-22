// Lógica pura de Dart (sin Flutter): decodificación de la salida de YOLOv8.
//
// Formato verificado con el modelo yolov8n_float32.tflite:
//   entrada  [1, 640, 640, 3] float32, RGB en [0, 1]
//   salida   [1, 84, 8400]    float32  -> 4 coordenadas (cx, cy, w, h) +
//                                         80 puntuaciones de clase por ancla
// IMPORTANTE: en este modelo las coordenadas salen NORMALIZADAS (0..1) y no en
// píxeles. El decodificador lo detecta automáticamente para que un modelo
// propio exportado en píxeles también funcione.

import 'dart:typed_data';

import 'frame_rgb.dart';

/// Caja detectada. Coordenadas normalizadas (0..1) respecto al fotograma
/// vertical completo (independiente del tamaño de la vista previa).
class CajaDeteccion {
  final double izq;
  final double arriba;
  final double der;
  final double abajo;
  final int clase;
  final String etiqueta;
  final double puntaje;

  const CajaDeteccion({
    required this.izq,
    required this.arriba,
    required this.der,
    required this.abajo,
    required this.clase,
    required this.etiqueta,
    required this.puntaje,
  });

  double get ancho => der - izq;
  double get alto => abajo - arriba;
  double get area => (ancho < 0 ? 0 : ancho) * (alto < 0 ? 0 : alto);

  double iou(CajaDeteccion o) => iouCajas(izq, arriba, der, abajo, o.izq, o.arriba, o.der, o.abajo);
}

double iouCajas(double aI, double aA, double aD, double aB, double bI,
    double bA, double bD, double bB) {
  final x1 = aI > bI ? aI : bI;
  final y1 = aA > bA ? aA : bA;
  final x2 = aD < bD ? aD : bD;
  final y2 = aB < bB ? aB : bB;
  final w = x2 - x1;
  final h = y2 - y1;
  if (w <= 0 || h <= 0) return 0;
  final inter = w * h;
  final union = (aD - aI) * (aB - aA) + (bD - bI) * (bB - bA) - inter;
  return union <= 0 ? 0 : inter / union;
}

class DecodificadorYolo {
  /// Nombres de clase alineados con los canales 4..4+nc de la salida.
  final List<String> etiquetas;

  /// Índices de clase que se conservan (null = todas). Las demás se
  /// descartan DESPUÉS de competir por el argmax: si un píxel es "persona"
  /// con 0.9 y "botella" con 0.4, es una persona y no una botella.
  final Set<int>? clasesPermitidas;

  final double umbral;
  final double iouMismaClase;
  final double iouEntreClases;
  final int maxDetecciones;

  const DecodificadorYolo({
    required this.etiquetas,
    this.clasesPermitidas,
    this.umbral = 0.40,
    this.iouMismaClase = 0.45,
    this.iouEntreClases = 0.70,
    this.maxDetecciones = 20,
  });

  List<CajaDeteccion> decodificar(
    Float32List salida, {
    required int canales,
    required int anclas,
    required bool canalPrimero,
    required int tamEntrada,
    required InfoLetterbox letterbox,
    required int anchoFrame,
    required int altoFrame,
  }) {
    final nc = canales - 4;
    final candidatos = <_Candidato>[];
    var maxValor = 0.0;

    for (var i = 0; i < anclas; i++) {
      var mejor = -1;
      var mejorP = 0.0;
      for (var c = 0; c < nc; c++) {
        final p = canalPrimero ? salida[(4 + c) * anclas + i] : salida[i * canales + 4 + c];
        if (p > mejorP) {
          mejorP = p;
          mejor = c;
        }
      }
      if (mejor < 0 || mejorP < umbral) continue;
      if (clasesPermitidas != null && !clasesPermitidas!.contains(mejor)) continue;

      final cx = canalPrimero ? salida[i] : salida[i * canales];
      final cy = canalPrimero ? salida[anclas + i] : salida[i * canales + 1];
      final w = canalPrimero ? salida[2 * anclas + i] : salida[i * canales + 2];
      final h = canalPrimero ? salida[3 * anclas + i] : salida[i * canales + 3];
      for (final v in [cx, cy, w, h]) {
        if (v > maxValor) maxValor = v;
      }
      candidatos.add(_Candidato(cx, cy, w, h, mejor, mejorP));
    }
    if (candidatos.isEmpty) return const [];

    // Coordenadas normalizadas (<= ~1) o en píxeles de la entrada.
    final mult = maxValor <= 2.0 ? tamEntrada.toDouble() : 1.0;

    final cajas = <CajaDeteccion>[];
    for (final c in candidatos) {
      final cx = c.cx * mult;
      final cy = c.cy * mult;
      final w = c.w * mult;
      final h = c.h * mult;
      // Del espacio de la entrada (con letterbox) al fotograma, normalizado.
      final l = ((cx - w / 2 - letterbox.padIzq) / letterbox.escala) / anchoFrame;
      final t = ((cy - h / 2 - letterbox.padArriba) / letterbox.escala) / altoFrame;
      final r = ((cx + w / 2 - letterbox.padIzq) / letterbox.escala) / anchoFrame;
      final b = ((cy + h / 2 - letterbox.padArriba) / letterbox.escala) / altoFrame;
      final caja = CajaDeteccion(
        izq: l.clamp(0.0, 1.0),
        arriba: t.clamp(0.0, 1.0),
        der: r.clamp(0.0, 1.0),
        abajo: b.clamp(0.0, 1.0),
        clase: c.clase,
        etiqueta: c.clase < etiquetas.length ? etiquetas[c.clase] : 'clase_${c.clase}',
        puntaje: c.puntaje,
      );
      if (caja.ancho < 0.02 || caja.alto < 0.02) continue;
      cajas.add(caja);
    }
    return _nms(cajas);
  }

  List<CajaDeteccion> _nms(List<CajaDeteccion> cajas) {
    cajas.sort((a, b) => b.puntaje.compareTo(a.puntaje));
    final conservadas = <CajaDeteccion>[];
    for (final c in cajas) {
      var suprimida = false;
      for (final k in conservadas) {
        final iou = c.iou(k);
        if (iou > (k.clase == c.clase ? iouMismaClase : iouEntreClases)) {
          suprimida = true;
          break;
        }
      }
      if (!suprimida) {
        conservadas.add(c);
        if (conservadas.length >= maxDetecciones) break;
      }
    }
    return conservadas;
  }
}

class _Candidato {
  final double cx, cy, w, h;
  final int clase;
  final double puntaje;
  const _Candidato(this.cx, this.cy, this.w, this.h, this.clase, this.puntaje);
}

/// Las 80 clases COCO en el orden de los canales de YOLOv8.
const List<String> etiquetasCoco = [
  'person', 'bicycle', 'car', 'motorcycle', 'airplane', 'bus', 'train',
  'truck', 'boat', 'traffic light', 'fire hydrant', 'stop sign',
  'parking meter', 'bench', 'bird', 'cat', 'dog', 'horse', 'sheep', 'cow',
  'elephant', 'bear', 'zebra', 'giraffe', 'backpack', 'umbrella', 'handbag',
  'tie', 'suitcase', 'frisbee', 'skis', 'snowboard', 'sports ball', 'kite',
  'baseball bat', 'baseball glove', 'skateboard', 'surfboard',
  'tennis racket', 'bottle', 'wine glass', 'cup', 'fork', 'knife', 'spoon',
  'bowl', 'banana', 'apple', 'sandwich', 'orange', 'broccoli', 'carrot',
  'hot dog', 'pizza', 'donut', 'cake', 'chair', 'couch', 'potted plant',
  'bed', 'dining table', 'toilet', 'tv', 'laptop', 'mouse', 'remote',
  'keyboard', 'cell phone', 'microwave', 'oven', 'toaster', 'sink',
  'refrigerator', 'book', 'clock', 'vase', 'scissors', 'teddy bear',
  'hair drier', 'toothbrush',
];
