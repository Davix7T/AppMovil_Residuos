import 'generador_consejos_base.dart';
import 'recomendador_habitos.dart';

GeneradorConsejosLocal crearGeneradorConsejosLocal() =>
    _GeneradorConsejosNoDisponible();

class _GeneradorConsejosNoDisponible implements GeneradorConsejosLocal {
  @override
  bool get soportado => false;

  @override
  Future<bool> get modeloInstalado async => false;

  @override
  Future<void> importarModelo(String rutaArchivo) {
    throw UnsupportedError('La generación local con IA requiere Android.');
  }

  @override
  Future<ResultadoConsejoLocal> generarConsejo(
    AnalisisHabitos analisis, {
    required ProgresoDescargaModelo onProgress,
  }) {
    throw UnsupportedError('La generación local con IA requiere Android.');
  }
}
