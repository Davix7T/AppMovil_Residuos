import 'package:app_movil/services/recomendador_habitos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const recomendador = RecomendadorHabitos();
  final ahora = DateTime(2026, 11, 22);

  RegistroParaRecomendacion registro(
    String etiqueta,
    int diasAntes, {
    String? nombre,
  }) {
    return RegistroParaRecomendacion(
      etiqueta: etiqueta,
      nombre: nombre ?? etiqueta,
      fecha: ahora.subtract(Duration(days: diasAntes)),
    );
  }

  test('pide más historial antes de personalizar recomendaciones', () {
    final resultado = recomendador.analizar([
      registro('paper', 1),
      registro('plastic', 2),
    ], ahora: ahora);

    expect(resultado.titulo, 'Sigue registrando tus residuos');
    expect(resultado.consejo, isEmpty);
  });

  test('recomienda una acción para la categoría más frecuente', () {
    final resultado = recomendador.analizar([
      registro('paper', 1, nombre: 'Papel'),
      registro('paper', 4, nombre: 'Papel'),
      registro('plastic', 7, nombre: 'Plástico'),
    ], ahora: ahora);

    expect(resultado.titulo, 'Tu residuo más frecuente: Papel');
    expect(resultado.resumen, contains('2 veces'));
    expect(resultado.consejo, contains('limpio y seco'));
    expect(resultado.cantidadCategoriaFrecuente, 2);
    expect(resultado.totalRegistros, 3);
  });

  test('incluye frecuencia y categoría en la respuesta personalizada', () {
    final analisis = recomendador.analizar([
      registro('paper', 1, nombre: 'Papel'),
      registro('paper', 4, nombre: 'Papel'),
      registro('plastic', 7, nombre: 'Plástico'),
    ], ahora: ahora);

    final consejo = construirConsejoPersonalizado(
      analisis,
      textoIA: 'Mantén el papel limpio y seco.',
    );

    expect(consejo, contains('Papel fue la categoría más frecuente'));
    expect(consejo, contains('con 2 registros'));
    expect(consejo, contains('Mantén el papel limpio y seco.'));
    expect(consejo, contains('Sugerencia práctica para Papel:'));
  });

  test('crea un respaldo personalizado sin texto generado por IA', () {
    final analisis = recomendador.analizar([
      registro('paper', 1, nombre: 'Papel'),
      registro('paper', 4, nombre: 'Papel'),
      registro('plastic', 7, nombre: 'Plástico'),
    ], ahora: ahora);

    final consejo = construirConsejoPersonalizado(analisis);

    expect(consejo, contains('Papel fue la categoría más frecuente'));
    expect(consejo, contains('Separa el papel limpio y seco'));
  });

  test(
    'compara periodos iguales cuando ambos tienen suficientes registros',
    () {
      final resultado = recomendador.analizar([
        registro('plastic', 1, nombre: 'Plástico'),
        registro('plastic', 5, nombre: 'Plástico'),
        registro('paper', 10, nombre: 'Papel'),
        registro('plastic', 35, nombre: 'Plástico'),
        registro('paper', 40, nombre: 'Papel'),
        registro('paper', 50, nombre: 'Papel'),
      ], ahora: ahora);

      expect(resultado.tendencia, contains('2 residuos de tipo plástico'));
      expect(resultado.tendencia, contains('fueron 1'));
    },
  );

  test(
    'omite la tendencia si los periodos no tienen suficientes registros',
    () {
      final resultado = recomendador.analizar([
        registro('paper', 1),
        registro('plastic', 2),
        registro('paper', 3),
      ], ahora: ahora);

      expect(resultado.tendencia, isNull);
    },
  );
}
