import 'dart:async';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart' show DeviceOrientation;

import 'services/analizador_residuos.dart';
import 'services/contenedores.dart';
import 'services/frame_rgb.dart';
import 'widgets/detecciones_painter.dart';

/// Reconocimiento de residuos en vivo con cajas por contenedor colombiano.
///
/// Dos rutas de captura, según la plataforma (el resto del pipeline es común):
///  * ANDROID: `startImageStream` en YUV420 -> `FrameRgb.desdeYuv420` (con la
///    rotación del sensor aplicada). Sin sonido de obturador, sin JPEG.
///  * CHROME (y cualquier plataforma sin image stream): `takePicture` ->
///    decodificación nativa del navegador (`ui.instantiateImageCodec`) ->
///    `FrameRgb.desdeRgba`. `startImageStream` NO está implementado en la
///    versión web del plugin `camera`, por eso se usa esta ruta.
class CamaraEnVivo extends StatefulWidget {
  const CamaraEnVivo({super.key});

  @override
  State<CamaraEnVivo> createState() => _CamaraEnVivoState();
}

class _CamaraEnVivoState extends State<CamaraEnVivo> {
  /// Si en Chrome ves las cajas reflejadas respecto al video (ocurre con
  /// algunas webcams frontales), pon esto en true.
  static const bool espejarCajasEnWeb = false;

  /// Fracción del lado menor que ocupa el cuadro guía central.
  static const double guiaFraccion = 0.60;

  CameraController? _controller;
  CameraDescription? _camara;
  final AnalizadorResiduos _analizador = AnalizadorResiduos();

  String? _error;
  bool _cargando = true;
  bool _activo = true;
  bool _procesando = false;

  List<DeteccionResiduo> _detecciones = const [];
  int _msDeteccion = 0;
  int _msTotal = 0;
  double _fps = 0;
  double? _aspectoFrame;
  final Stopwatch _reloj = Stopwatch()..start();
  int _msUltimoResultado = 0;

  bool get _usaImageStream =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    try {
      final camaras = await availableCameras();
      if (camaras.isEmpty) {
        throw Exception('No se encontró ninguna cámara.');
      }
      final camara = camaras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => camaras.first,
      );

      final controlador = CameraController(
        camara,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: _usaImageStream ? ImageFormatGroup.yuv420 : null,
      );

      // Cámara y modelos se preparan en paralelo.
      await Future.wait([controlador.initialize(), _analizador.cargar()]);

      if (!mounted) {
        await controlador.dispose();
        return;
      }

      setState(() {
        _camara = camara;
        _controller = controlador;
        _cargando = false;
      });

      if (_usaImageStream) {
        await controlador.startImageStream(_alRecibirFrame);
      } else {
        unawaited(_bucleCaptura());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _cargando = false;
      });
    }
  }

  // ---------------------------------------------------------------- ANDROID

  void _alRecibirFrame(CameraImage imagen) {
    // Si todavía se está procesando un fotograma, este se descarta (no se
    // encola): así la latencia no crece y el resultado siempre es reciente.
    if (_procesando || !_activo) return;
    _procesando = true;
    _analizarAndroid(imagen).whenComplete(() => _procesando = false);
  }

  Future<void> _analizarAndroid(CameraImage imagen) async {
    try {
      final p = imagen.planes;
      if (p.length < 3) {
        throw StateError(
          'Formato de cámara no soportado (${p.length} planos).',
        );
      }
      // La conversión es síncrona: se hace ANTES del primer await, mientras
      // los bytes del fotograma siguen siendo válidos.
      final frame = FrameRgb.desdeYuv420(
        ancho: imagen.width,
        alto: imagen.height,
        y: p[0].bytes,
        u: p[1].bytes,
        v: p[2].bytes,
        filaY: p[0].bytesPerRow,
        filaUV: p[1].bytesPerRow,
        pixelUV: p[1].bytesPerPixel ?? 1,
        rotacion: _rotacionSensor(),
        maxLado: 640,
      );
      await _procesar(frame);
    } catch (e) {
      debugPrint('Error al analizar fotograma: $e');
    }
  }

  /// Giro horario que hay que aplicar al fotograma del sensor para dejarlo
  /// vertical (cámara trasera): (orientación del sensor - giro del
  /// dispositivo) mod 360.
  int _rotacionSensor() {
    final sensor = _camara?.sensorOrientation ?? 90;
    final giroDispositivo = switch (_controller?.value.deviceOrientation) {
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
      _ => 0,
    };
    return (sensor - giroDispositivo + 360) % 360;
  }

  // ----------------------------------------------------------------- CHROME

  Future<void> _bucleCaptura() async {
    while (mounted && _activo) {
      try {
        final c = _controller;
        if (c == null || !c.value.isInitialized) break;

        final foto = await c.takePicture();
        final Uint8List bytes = await foto.readAsBytes();
        final frame = await _decodificarImagen(bytes);

        if (!mounted || !_activo) break;
        await _procesar(frame);
      } catch (e) {
        debugPrint('Error al analizar fotograma: $e');
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
  }

  /// Decodifica con el códec del propio navegador/motor (rápido y asíncrono),
  /// en lugar de la librería `image` en Dart puro, que bloquearía la UI.
  Future<FrameRgb> _decodificarImagen(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final fotograma = await codec.getNextFrame();
      final imagen = fotograma.image;
      try {
        final datos = await imagen.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        if (datos == null) {
          throw StateError('No se pudo leer la imagen capturada.');
        }
        return FrameRgb.desdeRgba(
          imagen.width,
          imagen.height,
          datos.buffer.asUint8List(datos.offsetInBytes, datos.lengthInBytes),
        );
      } finally {
        imagen.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  // ----------------------------------------------------------------- COMÚN

  Future<void> _procesar(FrameRgb frame) async {
    final r = await _analizador.analizar(frame);
    if (!mounted || !_activo) return;

    final ahora = _reloj.elapsedMilliseconds;
    final ciclo = ahora - _msUltimoResultado;
    _msUltimoResultado = ahora;
    final fpsInstantaneo = ciclo > 0 ? 1000 / ciclo : 0.0;

    setState(() {
      _detecciones = r.detecciones;
      _msDeteccion = r.msDeteccion;
      _msTotal = r.msTotal;
      _fps = _fps == 0 ? fpsInstantaneo : _fps * 0.8 + fpsInstantaneo * 0.2;
      _aspectoFrame = frame.ancho / frame.alto;
    });
  }

  @override
  void dispose() {
    _activo = false;
    final c = _controller;
    if (c != null) {
      if (c.value.isStreamingImages) {
        c.stopImageStream().catchError((_) {});
      }
      c.dispose();
    }
    _analizador.cerrar();
    super.dispose();
  }

  double _aspectoVista(CameraController c) {
    final medido = _aspectoFrame;
    if (medido != null) return medido;
    // Antes del primer fotograma: la misma regla que usa CameraPreview.
    final o = c.value.lockedCaptureOrientation ?? c.value.deviceOrientation;
    final horizontal =
        o == DeviceOrientation.landscapeLeft ||
        o == DeviceOrientation.landscapeRight;
    return horizontal ? c.value.aspectRatio : 1 / c.value.aspectRatio;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Reconocimiento de residuos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
      ),
      body: _cargando
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF10B981)),
                  SizedBox(height: 14),
                  Text('Cargando cámara y modelos...'),
                ],
              ),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error al abrir la cámara:\n$_error',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : _controller != null && _controller!.value.isInitialized
          ? Column(
              children: [
                Expanded(child: _vista(_controller!)),
                _panel(),
              ],
            )
          : const Center(child: Text('Cámara no disponible')),
    );
  }

  Widget _vista(CameraController c) {
    return Container(
      margin: const EdgeInsets.all(12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        // La vista previa y las cajas comparten EXACTAMENTE el mismo
        // rectángulo (misma proporción que el fotograma analizado), por eso
        // las coordenadas normalizadas de las cajas caen donde deben.
        child: AspectRatio(
          aspectRatio: _aspectoVista(c),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(c),
              IgnorePointer(
                child: CustomPaint(
                  painter: DeteccionesPainter(
                    detecciones: _detecciones,
                    espejo: kIsWeb && espejarCajasEnWeb,
                    guiaFraccion: guiaFraccion,
                  ),
                ),
              ),
              if (_detecciones.isEmpty)
                Positioned(
                  top: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Apunta la cámara a un residuo',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _panel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.recycling, color: Color(0xFF10B981), size: 26),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Resultado del reconocimiento',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_detecciones.isEmpty)
            const Text(
              'Buscando residuos...',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF10B981),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 150),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: _detecciones.map(_fila).toList(),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Detección: $_msDeteccion ms · Ciclo: $_msTotal ms · '
            '${_fps.toStringAsFixed(1)} FPS\n'
            'Motor: ${_analizador.backendDetector} / '
            '${_analizador.backendClasificador}',
            style: const TextStyle(fontSize: 11, color: Colors.black45),
          ),
          const SizedBox(height: 4),
          const Text(
            'El resultado se actualiza automáticamente. Las puntuaciones son '
            'estimaciones del modelo y pueden equivocarse. Colores según la '
            'norma colombiana: verde (orgánicos), blanco (aprovechables), '
            'negro (no aprovechables).',
            style: TextStyle(fontSize: 11, color: Colors.black45),
          ),
        ],
      ),
    );
  }

  Widget _fila(DeteccionResiduo d) {
    final color = Color(d.contenedor.colorArgb);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black26),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.titulo,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${d.contenedor.nombre} · ${d.contenedor.descripcion}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          Text(
            '${(d.confianza * 100).toStringAsFixed(0)}%',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
