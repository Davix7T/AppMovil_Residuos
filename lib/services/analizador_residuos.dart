import 'dart:math' as math;

import 'clasificador_residuos.dart';
import 'contenedores.dart';
import 'frame_rgb.dart';
import 'rastreador.dart';
import 'yolo_detector.dart';

class ConfigAnalizador {
  /// Umbral de confianza del detector (YOLO).
  final double umbralDeteccion;

  /// Confianza mínima del clasificador de material para poder cambiar el
  /// contenedor base de un objeto (p. ej. un vaso que resulta ser de papel).
  final double umbralMaterial;

  /// Cada cuánto se reclasifica el material de un mismo objeto.
  final int intervaloClasificacionMs;

  /// Máximo de objetos que se reclasifican por fotograma.
  final int maxObjetosClasificados;

  /// Incluir celulares, teclados, etc. como "RAEE". Desactivado por defecto.
  final bool incluirElectronicos;

  /// Si el detector no encuentra nada, clasificar la región central (la
  /// guía que ya mostraba la app) para materiales que COCO no tiene:
  /// cartón, papel arrugado, latas...
  final bool usarRegionCentral;
  final double fraccionRegionCentral;
  final double umbralRegionCentral;
  final double margenMinimoRegionCentral;
  final int intervaloRegionCentralMs;

  const ConfigAnalizador({
    this.umbralDeteccion = 0.40,
    this.umbralMaterial = 0.55,
    this.intervaloClasificacionMs = 900,
    this.maxObjetosClasificados = 3,
    this.incluirElectronicos = false,
    this.usarRegionCentral = true,
    this.fraccionRegionCentral = 0.60,
    this.umbralRegionCentral = 0.75,
    this.margenMinimoRegionCentral = 0.25,
    this.intervaloRegionCentralMs = 900,
  });
}

class DeteccionResiduo {
  /// Identificador estable del objeto (-1 para la región central).
  final int id;
  final double izq;
  final double arriba;
  final double der;
  final double abajo;

  /// Nombre del objeto en español ("Botella").
  final String nombre;

  /// Material en español ("Plástico"), si el clasificador pudo decidirlo.
  final String? material;

  /// Confianza de la detección (0..1).
  final double confianza;
  final double? confianzaMaterial;
  final ContenedorColombia contenedor;

  /// true si viene del análisis de la región central y no del detector.
  final bool regionCentral;

  const DeteccionResiduo({
    required this.id,
    required this.izq,
    required this.arriba,
    required this.der,
    required this.abajo,
    required this.nombre,
    required this.material,
    required this.confianza,
    required this.confianzaMaterial,
    required this.contenedor,
    required this.regionCentral,
  });

  String get titulo => material == null ? nombre : '$nombre · $material';
}

class ResultadoFrame {
  final List<DeteccionResiduo> detecciones;
  final int msDeteccion;
  final int msTotal;

  const ResultadoFrame(this.detecciones, this.msDeteccion, this.msTotal);
}

/// Orquesta el pipeline completo para un fotograma:
///   YOLO (qué objetos y dónde) -> rastreador (estabilidad temporal) ->
///   clasificador de material sobre el recorte de cada objeto ->
///   regla de contenedor colombiano.
class AnalizadorResiduos {
  final ConfigAnalizador config;
  final YoloDetector _detector;
  final ClasificadorResiduos _clasificador;
  final Rastreador _rastreador = Rastreador();
  final Map<String, PerfilObjeto> _perfiles;
  final Stopwatch _reloj = Stopwatch()..start();

  final List<ResultadoResiduo> _votosCentro = [];
  int _msUltimaCentral = -1000000;
  DeteccionResiduo? _ultimaCentral;

  AnalizadorResiduos({
    this.config = const ConfigAnalizador(),
    ClasificadorResiduos? clasificador,
    YoloDetector? detector,
  })  : _clasificador = clasificador ?? ClasificadorResiduos(),
        _perfiles = {
          ...perfilesCoco,
          if (config.incluirElectronicos) ...perfilesElectronicos,
        },
        _detector = detector ??
            YoloDetector(
              umbral: config.umbralDeteccion,
              etiquetasPermitidas: {
                ...perfilesCoco.keys,
                if (config.incluirElectronicos) ...perfilesElectronicos.keys,
              },
            );

  String get backendDetector => _detector.backend;
  String get backendClasificador => _clasificador.backend;

  Future<void> cargar() async {
    await Future.wait([_detector.cargar(), _clasificador.cargarModelo()]);
  }

  Future<ResultadoFrame> analizar(FrameRgb frame) async {
    final inicio = _reloj.elapsedMilliseconds;

    final cajas = await _detector.detectar(frame);
    final msDeteccion = _reloj.elapsedMilliseconds - inicio;

    final visibles = _rastreador.actualizar(cajas);
    final ahora = _reloj.elapsedMilliseconds;

    // Reclasificar el material de los objetos que lo necesiten (con caché).
    final pendientes = visibles
        .where((p) =>
            _perfiles[p.etiqueta]?.regla == ReglaFusion.refinarConMaterial &&
            p.fallos == 0 &&
            p.necesitaClasificar(ahora, config.intervaloClasificacionMs))
        .toList()
      ..sort((a, b) => _peso(b).compareTo(_peso(a)));

    for (final p in pendientes.take(config.maxObjetosClasificados)) {
      final tensor = frame.recorteCuadrado(
        p.izq, p.arriba, p.der, p.abajo,
        ClasificadorResiduos.tamEntrada,
        normalizacion: ClasificadorResiduos.normalizacion,
      );
      final r = await _clasificador.clasificarTensor(tensor);
      p.registrarMaterial(r.etiqueta, r.confianza, ahora);
    }

    final detecciones = <DeteccionResiduo>[];
    for (final p in visibles) {
      final perfil = _perfiles[p.etiqueta];
      if (perfil == null) continue;
      final mat = p.materialVotado;
      final decision = decidirContenedor(
        perfil,
        material: mat?.etiqueta,
        confianzaMaterial: mat?.confianza ?? 0,
        umbralMaterial: config.umbralMaterial,
      );
      detecciones.add(DeteccionResiduo(
        id: p.id,
        izq: p.izq,
        arriba: p.arriba,
        der: p.der,
        abajo: p.abajo,
        nombre: perfil.nombre,
        material: decision.materialUsado == null
            ? null
            : _clasificador.nombreEnEspanol(decision.materialUsado!),
        confianza: p.puntaje,
        confianzaMaterial: decision.materialUsado == null ? null : mat?.confianza,
        contenedor: decision.contenedor,
        regionCentral: false,
      ));
    }

    if (config.usarRegionCentral) {
      if (detecciones.isNotEmpty) {
        _votosCentro.clear();
        _ultimaCentral = null;
      } else {
        await _analizarRegionCentral(frame, ahora);
        if (_ultimaCentral != null) detecciones.add(_ultimaCentral!);
      }
    }

    return ResultadoFrame(
      detecciones,
      msDeteccion,
      _reloj.elapsedMilliseconds - inicio,
    );
  }

  double _peso(Pista p) => p.puntaje * (p.der - p.izq) * (p.abajo - p.arriba);

  /// Clasifica el cuadrado central del fotograma (la guía de la pantalla).
  /// Es la vía para materiales que el detector COCO no conoce. Es estricta
  /// para evitar falsos positivos: confianza alta, margen amplio sobre la
  /// segunda opción y votación 3 de 5 fotogramas.
  Future<void> _analizarRegionCentral(FrameRgb frame, int ahora) async {
    if (ahora - _msUltimaCentral < config.intervaloRegionCentralMs) return;
    _msUltimaCentral = ahora;

    final lado = config.fraccionRegionCentral * math.min(frame.ancho, frame.alto);
    final mitadX = lado / 2 / frame.ancho;
    final mitadY = lado / 2 / frame.alto;
    final izq = 0.5 - mitadX;
    final arriba = 0.5 - mitadY;
    final der = 0.5 + mitadX;
    final abajo = 0.5 + mitadY;

    final tensor = frame.recorteCuadrado(
      izq, arriba, der, abajo,
      ClasificadorResiduos.tamEntrada,
      margen: 0,
      normalizacion: ClasificadorResiduos.normalizacion,
    );
    final r = await _clasificador.clasificarTensor(tensor);

    _votosCentro.add(r);
    if (_votosCentro.length > 5) _votosCentro.removeAt(0);

    final conteo = <String, List<ResultadoResiduo>>{};
    for (final v in _votosCentro) {
      conteo.putIfAbsent(v.etiqueta, () => []).add(v);
    }
    String? dominante;
    for (final e in conteo.entries) {
      if (dominante == null || e.value.length > conteo[dominante]!.length) {
        dominante = e.key;
      }
    }

    _ultimaCentral = null;
    if (dominante == null) return;
    final votos = conteo[dominante]!;
    if (votos.length < 3) return;

    final conf = votos.map((v) => v.confianza).reduce((a, b) => a + b) / votos.length;
    final margen = votos.map((v) => v.margen).reduce((a, b) => a + b) / votos.length;
    final minimo = dominante == 'trash' ? 0.85 : config.umbralRegionCentral;
    if (conf < minimo || margen < config.margenMinimoRegionCentral) return;

    _ultimaCentral = DeteccionResiduo(
      id: -1,
      izq: izq,
      arriba: arriba,
      der: der,
      abajo: abajo,
      nombre: _clasificador.nombreEnEspanol(dominante),
      material: null,
      confianza: conf,
      confianzaMaterial: null,
      contenedor: contenedorPorMaterial(dominante),
      regionCentral: true,
    );
  }

  Future<void> cerrar() async {
    await _detector.cerrar();
    await _clasificador.cerrar();
  }
}
