class RegistroParaRecomendacion {
  final String etiqueta;
  final String nombre;
  final DateTime fecha;

  const RegistroParaRecomendacion({
    required this.etiqueta,
    required this.nombre,
    required this.fecha,
  });
}

class AnalisisHabitos {
  final String titulo;
  final String resumen;
  final String consejo;
  final String? tendencia;
  final String? categoria;
  final int? cantidadCategoriaFrecuente;
  final int? totalRegistros;

  const AnalisisHabitos({
    required this.titulo,
    required this.resumen,
    required this.consejo,
    this.tendencia,
    this.categoria,
    this.cantidadCategoriaFrecuente,
    this.totalRegistros,
  });
}

String construirConsejoPersonalizado(
  AnalisisHabitos analisis, {
  String? textoIA,
}) {
  final categoria = analisis.categoria;
  final cantidad = analisis.cantidadCategoriaFrecuente;
  final total = analisis.totalRegistros;
  final contexto = categoria != null && cantidad != null && total != null
      ? 'En tus $total clasificaciones, $categoria fue la categoría más frecuente con $cantidad registros. '
      : '';
  final recomendacion = textoIA?.trim().isNotEmpty == true
      ? textoIA!.trim()
      : analisis.consejo;
  final consejoBase = analisis.consejo;
  final incluyeConsejoBase =
      textoIA?.toLowerCase().contains(consejoBase.toLowerCase()) ?? false;
  final complemento =
      textoIA?.trim().isNotEmpty == true &&
          consejoBase.isNotEmpty &&
          !incluyeConsejoBase
      ? ' Sugerencia práctica para ${categoria ?? 'esta categoría'}: $consejoBase'
      : '';

  return '$contexto$recomendacion$complemento';
}

class RecomendadorHabitos {
  static const int _minimoRegistros = 3;
  static const Duration _ventana = Duration(days: 30);

  const RecomendadorHabitos();

  AnalisisHabitos analizar(
    Iterable<RegistroParaRecomendacion> historial, {
    DateTime? ahora,
  }) {
    final registros = historial.toList();
    if (registros.length < _minimoRegistros) {
      final faltantes = _minimoRegistros - registros.length;
      return AnalisisHabitos(
        titulo: registros.isEmpty
            ? 'Aún no hay datos suficientes'
            : 'Sigue registrando tus residuos',
        resumen: registros.isEmpty
            ? 'Guarda clasificaciones en el historial para recibir consejos basados en tus hábitos.'
            : 'Tienes ${registros.length} clasificaciones. Guarda $faltantes más para identificar patrones con mayor contexto.',
        consejo: '',
      );
    }

    final conteos = _contar(registros);
    final etiquetaFrecuente = _masFrecuente(conteos);
    final registroFrecuente = registros.firstWhere(
      (r) => _normalizar(r.etiqueta) == etiquetaFrecuente,
    );
    final cantidadFrecuente = conteos[etiquetaFrecuente]!;
    final nombreFrecuente = registroFrecuente.nombre;
    final fechaActual = ahora ?? DateTime.now();
    final inicioActual = fechaActual.subtract(_ventana);
    final inicioAnterior = fechaActual.subtract(const Duration(days: 60));
    final recientes = registros
        .where(
          (r) =>
              !r.fecha.isBefore(inicioActual) && !r.fecha.isAfter(fechaActual),
        )
        .toList();
    final anteriores = registros
        .where(
          (r) =>
              !r.fecha.isBefore(inicioAnterior) &&
              r.fecha.isBefore(inicioActual),
        )
        .toList();

    return AnalisisHabitos(
      titulo: 'Tu residuo más frecuente: $nombreFrecuente',
      categoria: nombreFrecuente,
      resumen:
          'Lo has registrado $cantidadFrecuente ${cantidadFrecuente == 1 ? 'vez' : 'veces'} en un historial de ${registros.length} clasificaciones.',
      consejo: _consejo(etiquetaFrecuente),
      tendencia:
          recientes.length >= _minimoRegistros &&
              anteriores.length >= _minimoRegistros
          ? _resumirTendencia(recientes, anteriores)
          : null,
      cantidadCategoriaFrecuente: cantidadFrecuente,
      totalRegistros: registros.length,
    );
  }

  Map<String, int> _contar(Iterable<RegistroParaRecomendacion> registros) {
    final conteos = <String, int>{};
    for (final registro in registros) {
      final etiqueta = _normalizar(registro.etiqueta);
      conteos[etiqueta] = (conteos[etiqueta] ?? 0) + 1;
    }
    return conteos;
  }

  String _masFrecuente(Map<String, int> conteos) {
    var etiqueta = conteos.keys.first;
    for (final entrada in conteos.entries.skip(1)) {
      if (entrada.value > conteos[etiqueta]!) etiqueta = entrada.key;
    }
    return etiqueta;
  }

  String _resumirTendencia(
    List<RegistroParaRecomendacion> recientes,
    List<RegistroParaRecomendacion> anteriores,
  ) {
    final conteosRecientes = _contar(recientes);
    final categoriaReciente = _masFrecuente(conteosRecientes);
    final registroCategoria = recientes.firstWhere(
      (r) => _normalizar(r.etiqueta) == categoriaReciente,
    );
    final cantidadReciente = conteosRecientes[categoriaReciente]!;
    final cantidadAnterior = _contar(anteriores)[categoriaReciente] ?? 0;
    final nombre = registroCategoria.nombre.toLowerCase();

    return 'En los últimos 30 días registraste $cantidadReciente residuos de tipo $nombre; en los 30 días anteriores fueron $cantidadAnterior.';
  }

  String _normalizar(String etiqueta) => etiqueta.trim().toLowerCase();

  String _consejo(String etiqueta) {
    switch (etiqueta) {
      case 'battery':
        return 'Lleva las baterías a un punto de recolección posconsumo; no las deposites en las canecas comunes.';
      case 'biological':
        return 'Puedes separar los residuos orgánicos y explorar el compostaje si tienes dónde hacerlo.';
      case 'brown-glass':
      case 'green-glass':
      case 'white-glass':
        return 'Entrega los envases de vidrio vacíos y manipula con cuidado cualquier vidrio roto.';
      case 'cardboard':
        return 'Mantén el cartón limpio y seco, y pliégalo antes de llevarlo al contenedor correspondiente.';
      case 'clothes':
      case 'shoes':
        return 'Considera reutilizar o donar las prendas y el calzado que aún estén en buen estado.';
      case 'metal':
        return 'Vacía y entrega los recipientes metálicos limpios y secos.';
      case 'paper':
        return 'Separa el papel limpio y seco; el papel con grasa o residuos puede no ser aprovechable.';
      case 'plastic':
        return 'Vacía los envases plásticos y entrégalos limpios y secos, según las reglas de tu localidad.';
      case 'trash':
        return 'Antes de desechar otros residuos, revisa si existe una ruta de aprovechamiento o recolección especial.';
      default:
        return 'Consulta las indicaciones de separación de tu localidad para esta categoría.';
    }
  }
}
