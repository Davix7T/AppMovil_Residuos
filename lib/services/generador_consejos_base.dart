import 'recomendador_habitos.dart';

const String urlLicenciaModeloConsejos =
    'https://huggingface.co/litert-community/Gemma3-1B-IT';
const String urlDescargaModeloConsejos =
    'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/a9bd85643f05cdb1e5cd5af7ba4e74b0e8210ca0/gemma3-1b-it-int4.litertlm';

typedef ProgresoDescargaModelo = void Function(int recibidos, int total);

abstract class GeneradorConsejosLocal {
  bool get soportado;

  Future<bool> get modeloInstalado;

  Future<void> importarModelo(String rutaArchivo);

  Future<ResultadoConsejoLocal> generarConsejo(
    AnalisisHabitos analisis, {
    required ProgresoDescargaModelo onProgress,
  });
}

class ResultadoConsejoLocal {
  final String texto;
  final bool generadoPorIA;
  final String? motivoRespaldo;

  const ResultadoConsejoLocal({
    required this.texto,
    required this.generadoPorIA,
    this.motivoRespaldo,
  });
}

bool respuestaConsejoValida(String texto) {
  final palabras = _palabras(texto);
  if (palabras.isEmpty || palabras.length > 100) return false;

  const marcadoresIngles = {
    'and',
    'are',
    'can',
    'courses',
    'easier',
    'find',
    'for',
    'from',
    'goals',
    'learning',
    'made',
    'new',
    'online',
    'paper',
    'plastic',
    'practice',
    'recycle',
    'recycling',
    'remember',
    'resources',
    'schedule',
    'separate',
    'skill',
    'starting',
    'steps',
    'the',
    'these',
    'waste',
    'with',
    'you',
    'your',
    'glass',
    'clean',
    'dry',
    'container',
    'properly',
  };
  return !palabras.any(marcadoresIngles.contains);
}

List<String> _palabras(String texto) => texto
    .toLowerCase()
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u')
    .replaceAll('ü', 'u')
    .replaceAll('ñ', 'n')
    .split(RegExp(r'[^a-z]+'))
    .where((palabra) => palabra.isNotEmpty)
    .toList();
