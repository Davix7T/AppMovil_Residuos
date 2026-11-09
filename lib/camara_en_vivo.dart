import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:typed_data';
import 'services/clasificador_residuos.dart';

class CamaraEnVivo extends StatefulWidget {
  const CamaraEnVivo({super.key});

  @override
  State<CamaraEnVivo> createState() => _CamaraEnVivoState();
}

class _CamaraEnVivoState extends State<CamaraEnVivo> {
  CameraController? _controller;
  String? _error;
  bool _cargando = true;
  bool _analizando = false;
  String _resultado = 'Esperando imagen...';
  double _confianza = 0;

  final ClasificadorResiduos _clasificador =
    ClasificadorResiduos();

  @override
  void initState() {
    super.initState();
    _iniciarCamara();
  }

  Future<void> _iniciarCamara() async {
    try {
      final camaras = await availableCameras();

      if (camaras.isEmpty) {
        throw Exception('No se encontró ninguna cámara.');
      }

      await _clasificador.cargarModelo();

      final controlador = CameraController(
        camaras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controlador.initialize();

      if (!mounted) {
        await controlador.dispose();
        return;
      }

      setState(() {
        _controller = controlador;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _cargando = false;
      });
    }
  }

  Future<void> _analizarFotograma() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _analizando) {
      return;
    }

    setState(() {
      _analizando = true;
    });

    try {
      final foto = await _controller!.takePicture();
      final Uint8List bytes = await foto.readAsBytes();

      final resultado = _clasificador.clasificarImagen(bytes);

      if (!mounted) return;

      setState(() {
        _resultado =
            _clasificador.nombreEnEspanol(resultado.etiqueta);
        _confianza = resultado.confianza * 100;
      });
    } catch (e) {
      debugPrint('Error al analizar fotograma: $e');
    } finally {
      if (mounted) {
        setState(() {
          _analizando = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cámara en vivo'),
      ),
      body: Center(
        child: _cargando
            ? const CircularProgressIndicator()
            : _error != null
                ? Text('Error al abrir la cámara:\n$_error')
                : _controller != null &&
                        _controller!.value.isInitialized
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: CameraPreview(_controller!),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Text(
                                  _resultado,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Confianza: ${_confianza.toStringAsFixed(1)}%',
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: _analizando ? null : _analizarFotograma,
                                  icon: const Icon(Icons.search),
                                  label: Text(
                                    _analizando ? 'Analizando...' : 'Analizar imagen',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : const Text('Cámara no disponible'),
      ),
    );
  }
}