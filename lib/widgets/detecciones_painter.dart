import 'package:material_ui/material_ui.dart';

import '../services/analizador_residuos.dart';
import '../services/contenedores.dart';

/// Dibuja sobre la vista previa las cajas de cada residuo con el color del
/// contenedor colombiano que le corresponde, más una etiqueta con el nombre,
/// el material, el contenedor y la confianza.
///
/// Las cajas llegan normalizadas (0..1) respecto al fotograma completo, así
/// que basta con que este widget ocupe EXACTAMENTE el mismo rectángulo que la
/// vista previa (ver `camara_en_vivo.dart`).
class DeteccionesPainter extends CustomPainter {
  final List<DeteccionResiduo> detecciones;

  /// Refleja horizontalmente las cajas (solo si la imagen analizada y la vista
  /// previa están en espejo distinto, p. ej. algunas webcams en Chrome).
  final bool espejo;

  /// Si no hay detecciones, dibuja un cuadro guía centrado con este tamaño
  /// (fracción del lado menor). null = sin guía.
  final double? guiaFraccion;

  DeteccionesPainter({
    required this.detecciones,
    this.espejo = false,
    this.guiaFraccion,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (detecciones.isEmpty && guiaFraccion != null) {
      _dibujarGuia(canvas, size);
      return;
    }
    for (final d in detecciones) {
      _dibujarDeteccion(canvas, size, d);
    }
  }

  void _dibujarGuia(Canvas canvas, Size size) {
    final lado =
        guiaFraccion! * (size.width < size.height ? size.width : size.height);
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: lado,
      height: lado,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0x99FFFFFF);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(18)),
      paint,
    );
  }

  void _dibujarDeteccion(Canvas canvas, Size size, DeteccionResiduo d) {
    var izq = d.izq * size.width;
    var der = d.der * size.width;
    if (espejo) {
      final t = size.width - der;
      der = size.width - izq;
      izq = t;
    }
    final rect = Rect.fromLTRB(
      izq,
      d.arriba * size.height,
      der,
      d.abajo * size.height,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
    final color = Color(d.contenedor.colorArgb);

    if (d.contenedor == ContenedorColombia.blanco) {
      // Un trazo blanco sobre una cámara clara no se ve: se le añade contorno.
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = const Color(0xFF111827),
      );
    }
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = d.contenedor == ContenedorColombia.blanco ? 3 : 4
        ..color = color,
    );

    final texto = color.computeLuminance() > 0.5
        ? const Color(0xFF111827)
        : Colors.white;
    final pct = (d.confianza * 100).round();
    final zona = d.regionCentral ? ' (zona central)' : '';
    final tp = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '${d.titulo} $pct%$zona\n',
            style: TextStyle(
              color: texto,
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(
            text: d.contenedor.nombre,
            style: TextStyle(color: texto, fontSize: 11),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: size.width * 0.9);

    const pad = 6.0;
    final w = tp.width + pad * 2;
    final h = tp.height + pad;
    var x = rect.left;
    if (x + w > size.width) x = size.width - w;
    if (x < 0) x = 0;
    var y = rect.top - h - 2;
    if (y < 0) y = rect.top + 2;

    final chip = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, w, h),
      const Radius.circular(8),
    );
    canvas.drawRRect(chip, Paint()..color = color);
    if (d.contenedor == ContenedorColombia.blanco) {
      canvas.drawRRect(
        chip,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFF111827),
      );
    }
    tp.paint(canvas, Offset(x + pad, y + pad / 2));
  }

  @override
  bool shouldRepaint(covariant DeteccionesPainter old) =>
      old.detecciones != detecciones ||
      old.espejo != espejo ||
      old.guiaFraccion != guiaFraccion;
}
