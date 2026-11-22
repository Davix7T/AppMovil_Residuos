// Lógica pura de Dart (sin Flutter): seguimiento de objetos entre fotogramas.
//
// Para qué sirve:
//  * Confirmación temporal: una caja solo se muestra tras [minAciertos]
//    fotogramas seguidos -> elimina los parpadeos y gran parte de los
//    falsos positivos de un solo fotograma.
//  * Suavizado de cajas (media móvil exponencial) -> el recuadro no "tiembla".
//  * Caché del clasificador de material por objeto -> el clasificador de
//    12 clases no se ejecuta en todos los fotogramas, solo cada
//    [intervaloMs] por objeto.

import 'yolo_decoder.dart';

class Pista {
  final int id;
  final int clase;
  final String etiqueta;

  double izq;
  double arriba;
  double der;
  double abajo;
  double puntaje;

  int aciertos = 1;
  int fallos = 0;

  int _msUltimaClasificacion = -1;
  final List<({String etiqueta, double confianza})> _historialMaterial = [];

  Pista(this.id, CajaDeteccion c)
      : clase = c.clase,
        etiqueta = c.etiqueta,
        izq = c.izq,
        arriba = c.arriba,
        der = c.der,
        abajo = c.abajo,
        puntaje = c.puntaje;

  bool get confirmada => aciertos >= 2;

  /// ¿Toca (re)clasificar el material de este objeto?
  bool necesitaClasificar(int msAhora, int intervaloMs) =>
      _msUltimaClasificacion < 0 ||
      msAhora - _msUltimaClasificacion >= intervaloMs;

  void registrarMaterial(String etiqueta, double confianza, int msAhora) {
    _msUltimaClasificacion = msAhora;
    _historialMaterial.add((etiqueta: etiqueta, confianza: confianza));
    if (_historialMaterial.length > 3) _historialMaterial.removeAt(0);
  }

  /// Material más votado de las últimas clasificaciones (con su confianza
  /// media), o null si todavía no hay ninguna.
  ({String etiqueta, double confianza})? get materialVotado {
    if (_historialMaterial.isEmpty) return null;
    final votos = <String, List<double>>{};
    for (final h in _historialMaterial) {
      votos.putIfAbsent(h.etiqueta, () => []).add(h.confianza);
    }
    String? mejor;
    var mejorVotos = 0;
    var mejorMedia = 0.0;
    votos.forEach((k, v) {
      final media = v.reduce((a, b) => a + b) / v.length;
      if (v.length > mejorVotos || (v.length == mejorVotos && media > mejorMedia)) {
        mejor = k;
        mejorVotos = v.length;
        mejorMedia = media;
      }
    });
    return (etiqueta: mejor!, confianza: mejorMedia);
  }
}

class Rastreador {
  final double iouMin;
  final int maxFallos;
  final double pesoNuevo;

  Rastreador({this.iouMin = 0.30, this.maxFallos = 3, this.pesoNuevo = 0.6});

  final List<Pista> _pistas = [];
  int _siguienteId = 1;

  List<Pista> get pistas => List.unmodifiable(_pistas);

  /// Pistas que se deben dibujar: confirmadas y vistas en los últimos
  /// fotogramas.
  List<Pista> get visibles =>
      _pistas.where((p) => p.confirmada && p.fallos <= 2).toList();

  void reiniciar() => _pistas.clear();

  List<Pista> actualizar(List<CajaDeteccion> cajas) {
    final pares = <({int pista, int caja, double iou})>[];
    for (var i = 0; i < _pistas.length; i++) {
      final p = _pistas[i];
      for (var j = 0; j < cajas.length; j++) {
        final c = cajas[j];
        if (c.clase != p.clase) continue;
        final iou = iouCajas(p.izq, p.arriba, p.der, p.abajo, c.izq, c.arriba, c.der, c.abajo);
        if (iou >= iouMin) pares.add((pista: i, caja: j, iou: iou));
      }
    }
    pares.sort((a, b) => b.iou.compareTo(a.iou));

    final pistasUsadas = <int>{};
    final cajasUsadas = <int>{};
    for (final par in pares) {
      if (pistasUsadas.contains(par.pista) || cajasUsadas.contains(par.caja)) continue;
      pistasUsadas.add(par.pista);
      cajasUsadas.add(par.caja);
      final p = _pistas[par.pista];
      final c = cajas[par.caja];
      final a = pesoNuevo;
      p.izq = p.izq * (1 - a) + c.izq * a;
      p.arriba = p.arriba * (1 - a) + c.arriba * a;
      p.der = p.der * (1 - a) + c.der * a;
      p.abajo = p.abajo * (1 - a) + c.abajo * a;
      p.puntaje = p.puntaje * (1 - a) + c.puntaje * a;
      p.aciertos++;
      p.fallos = 0;
    }

    for (var i = 0; i < _pistas.length; i++) {
      if (!pistasUsadas.contains(i)) _pistas[i].fallos++;
    }
    _pistas.removeWhere((p) => p.fallos > maxFallos);

    for (var j = 0; j < cajas.length; j++) {
      if (!cajasUsadas.contains(j)) {
        _pistas.add(Pista(_siguienteId++, cajas[j]));
      }
    }
    return visibles;
  }
}
