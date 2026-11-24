import 'dart:io';

import 'package:flutter_litert_lm/flutter_litert_lm.dart';
import 'package:path_provider/path_provider.dart';

import 'generador_consejos_base.dart';
import 'recomendador_habitos.dart';

GeneradorConsejosLocal crearGeneradorConsejosLocal() =>
    _GeneradorConsejosLiteRt();

class _GeneradorConsejosLiteRt implements GeneradorConsejosLocal {
  static const int _bytesModelo = 584417280;
  static const String _nombreModelo = 'gemma3-1b-it-int4.litertlm';
  static const LiteLmConversationConfig _configuracionConversacion =
      LiteLmConversationConfig(
        systemInstruction:
            'Responde siempre en español latinoamericano. Eres EcoAsistente, un orientador de reciclaje. '
            'Redacta consejos breves y concretos sobre separación de residuos. '
            'Habla solo de la categoría de residuo indicada. '
            'No inventes datos y respeta el consejo base.',
        samplerConfig: LiteLmSamplerConfig(
          temperature: 0.3,
          topK: 40,
          topP: 0.9,
        ),
      );

  @override
  bool get soportado => Platform.isAndroid;

  @override
  Future<bool> get modeloInstalado async {
    final modelo = await _archivoModelo();
    return await modelo.exists() && await modelo.length() == _bytesModelo;
  }

  @override
  Future<void> importarModelo(String rutaArchivo) async {
    final origen = File(rutaArchivo);
    if (!await origen.exists()) {
      throw FileSystemException('No se encontró el archivo seleccionado.');
    }
    if (!origen.path.toLowerCase().endsWith('.litertlm')) {
      throw const FormatException('Selecciona el archivo .litertlm de Gemma.');
    }
    final bytes = await origen.length();
    if (bytes != _bytesModelo) {
      throw FormatException(
        'El archivo no corresponde a Gemma 3 1B IT Q4 '
        '($bytes bytes; se esperaban $_bytesModelo).',
      );
    }

    final destino = await _archivoModelo();
    await destino.parent.create(recursive: true);
    final temporal = File('${destino.path}.part');
    if (await temporal.exists()) await temporal.delete();
    try {
      await origen.copy(temporal.path);
      if (await temporal.length() != _bytesModelo) {
        throw const FileSystemException(
          'No se pudo copiar completo el modelo seleccionado.',
        );
      }
      if (await destino.exists()) await destino.delete();
      await temporal.rename(destino.path);
    } finally {
      if (await temporal.exists()) await temporal.delete();
    }
  }

  @override
  Future<ResultadoConsejoLocal> generarConsejo(
    AnalisisHabitos analisis, {
    required ProgresoDescargaModelo onProgress,
  }) async {
    if (!soportado) {
      throw UnsupportedError('La generación local con IA requiere Android.');
    }

    final modelo = await _archivoModelo();
    if (!await modelo.exists() || await modelo.length() != _bytesModelo) {
      throw StateError(
        'Primero descarga y acepta la licencia del modelo Gemma 3 1B IT '
        'en $urlLicenciaModeloConsejos y luego impórtalo desde la app.',
      );
    }
    onProgress(0, 0);
    LiteLmEngine? engine;
    LiteLmConversation? conversation;
    try {
      engine = await LiteLmEngine.create(
        LiteLmEngineConfig(modelPath: modelo.path, backend: LiteLmBackend.cpu),
      );
      conversation = await engine.createConversation(
        _configuracionConversacion,
      );

      var respuesta = await conversation.sendMessage(_mensaje(analisis));
      var texto = _limpiarRespuesta(respuesta.text);
      if (!respuestaConsejoValida(texto)) {
        final textoParaTraducir = texto;
        await conversation.dispose();
        conversation = await engine.createConversation(
          _configuracionConversacion,
        );
        respuesta = await conversation.sendMessage(
          textoParaTraducir.isEmpty
              ? _reintento(analisis)
              : _traducirAlEspanol(analisis, textoParaTraducir),
        );
        texto = _limpiarRespuesta(respuesta.text);
      }
      if (!respuestaConsejoValida(texto)) {
        return ResultadoConsejoLocal(
          texto: construirConsejoPersonalizado(analisis),
          generadoPorIA: false,
          motivoRespaldo: _motivoRechazo(texto),
        );
      }
      return ResultadoConsejoLocal(
        texto: construirConsejoPersonalizado(analisis, textoIA: texto),
        generadoPorIA: true,
      );
    } finally {
      try {
        await conversation?.dispose();
      } finally {
        await engine?.dispose();
      }
    }
  }

  String _mensaje(AnalisisHabitos analisis) {
    return '/no_think\n'
        'Escribe únicamente una recomendación breve en español latinoamericano. '
        'La respuesta debe empezar exactamente con "Según tu historial,". '
        'Adapta la acción a los datos del historial sin inventar cantidades. '
        'Imita el idioma y el formato de este ejemplo, pero no copies sus datos: '
        '"Según tu historial, el papel es lo que más registras (4 de 6). '
        'Sepáralo limpio y seco para facilitar su reciclaje."\n'
        'Categoría: ${analisis.categoria ?? analisis.titulo}\n'
        'Frecuencia: ${analisis.cantidadCategoriaFrecuente} de ${analisis.totalRegistros} clasificaciones.\n'
        'Historial: ${analisis.resumen}\n'
        '${analisis.tendencia == null ? '' : 'Tendencia: ${analisis.tendencia}\n'}'
        'Consejo base que debes respetar: ${analisis.consejo}\n'
        'Ahora escribe solo el consejo correspondiente a estos datos. '
        'Empieza: Según tu historial,';
  }

  String _reintento(AnalisisHabitos analisis) {
    return '/no_think\n'
        'Redacta una recomendación breve en español latinoamericano. '
        'Empieza exactamente por "Según tu historial,". '
        'Ejemplo de estilo: "Según tu historial, el papel predomina. '
        'Sepáralo limpio y seco." No inventes cantidades. '
        'Tu categoría principal es ${analisis.categoria}; aparece '
        '${analisis.cantidadCategoriaFrecuente} de ${analisis.totalRegistros} clasificaciones. '
        'Respeta este consejo: ${analisis.consejo}. Escribe ahora solo la respuesta.';
  }

  String _traducirAlEspanol(AnalisisHabitos analisis, String texto) {
    return '/no_think\n'
        'Traduce la recomendación siguiente a español latinoamericano natural. '
        'Devuelve únicamente la traducción, en un párrafo breve. '
        'Conserva el sentido, la categoría y las cantidades; no agregues datos.\n'
        'Ejemplo: "Keep the paper dry." = "Mantén el papel seco."\n'
        'Categoría del historial: ${analisis.categoria}\n'
        'Frecuencia: ${analisis.cantidadCategoriaFrecuente} de ${analisis.totalRegistros}.\n'
        'Texto para traducir: $texto\n'
        'Traducción:';
  }

  String _limpiarRespuesta(String texto) {
    final cierrePensamiento = texto.lastIndexOf('</think>');
    if (cierrePensamiento >= 0) {
      return texto.substring(cierrePensamiento + '</think>'.length).trim();
    }
    if (texto.contains('<think>')) return '';
    return texto.trim();
  }

  String _motivoRechazo(String texto) {
    if (texto.isEmpty) return 'El modelo devolvió una respuesta vacía.';
    if (texto.split(RegExp(r'\s+')).length > 100) {
      return 'El modelo generó una respuesta demasiado extensa.';
    }
    final vista = texto.length > 120 ? '${texto.substring(0, 120)}...' : texto;
    return 'El modelo respondió en otro idioma: "$vista"';
  }

  Future<File> _archivoModelo() async {
    final directorio = await getApplicationSupportDirectory();
    return File('${directorio.path}${Platform.pathSeparator}$_nombreModelo');
  }
}
