import 'package:app_movil/services/generador_consejos_base.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('acepta un consejo breve en español y de la categoría analizada', () {
    expect(
      respuestaConsejoValida(
        'Según tu historial, el papel es frecuente. Sepáralo limpio y seco.',
      ),
      isTrue,
    );
  });

  test('rechaza respuestas genéricas en inglés', () {
    expect(
      respuestaConsejoValida(
        'Starting a new skill can be made easier with these steps.',
      ),
      isFalse,
    );
    expect(
      respuestaConsejoValida('Separate the paper carefully and recycle it.'),
      isFalse,
    );
  });

  test('acepta español aunque no contenga marcadores predefinidos', () {
    expect(respuestaConsejoValida('Papel reciclable, aprovéchalo.'), isTrue);
  });
}
