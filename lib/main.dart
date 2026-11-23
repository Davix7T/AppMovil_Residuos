import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'camara_en_vivo.dart';
import 'services/clasificador_residuos.dart';
import 'services/generador_consejos.dart';
import 'services/recomendador_habitos.dart';

void main() => runApp(const EcoSoftApp());

const verde = Color(0xFF10B981);
const fondo = Color(0xFFF8FAFC);
const texto = Color(0xFF1E293B);

class EcoSoftApp extends StatelessWidget {
  const EcoSoftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EcoSoft',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: fondo,
        colorScheme: ColorScheme.fromSeed(seedColor: verde),
        appBarTheme: const AppBarTheme(
          backgroundColor: fondo,
          foregroundColor: texto,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE8EEF0)),
          ),
        ),
      ),
      home: const EcoHome(),
    );
  }
}

class EcoRegistro {
  final String nombre;
  final String etiqueta;
  final String contenedor;
  final String recomendacion;
  final DateTime fecha;
  final Uint8List imagen;
  final double confianza;

  const EcoRegistro({
    required this.nombre,
    required this.etiqueta,
    required this.contenedor,
    required this.recomendacion,
    required this.fecha,
    required this.imagen,
    required this.confianza,
  });

  Map<String, dynamic> toJson() => {
    'nombre': nombre,
    'etiqueta': etiqueta,
    'contenedor': contenedor,
    'recomendacion': recomendacion,
    'fecha': fecha.toIso8601String(),
    'imagen': base64Encode(imagen),
    'confianza': confianza,
  };

  factory EcoRegistro.fromJson(Map<String, dynamic> json) {
    final etiqueta = (json['etiqueta'] ?? '').toString();
    return EcoRegistro(
      nombre: (json['nombre'] ?? 'Residuo').toString(),
      etiqueta: etiqueta,
      contenedor: (json['contenedor'] ?? 'Por revisar').toString(),
      recomendacion: (json['recomendacion'] ?? '').toString(),
      fecha:
          DateTime.tryParse((json['fecha'] ?? '').toString()) ?? DateTime.now(),
      imagen: Uint8List.fromList(base64Decode(json['imagen'] ?? '')),
      confianza: (json['confianza'] as num?)?.toDouble() ?? 0,
    );
  }
}

class EcoHome extends StatefulWidget {
  const EcoHome({super.key});

  @override
  State<EcoHome> createState() => _EcoHomeState();
}

class _EcoHomeState extends State<EcoHome> {
  final ImagePicker picker = ImagePicker();
  final ClasificadorResiduos clasificador = ClasificadorResiduos();
  final GeneradorConsejosLocal generadorConsejos =
      crearGeneradorConsejosLocal();
  final List<EcoRegistro> historial = [];

  int pagina = 0;
  bool cargando = false;
  bool modeloCargado = false;
  Uint8List? imagen;
  String nombreImagen = '';
  ResultadoResiduo? resultado;
  String filtroHistorial = 'Todos';
  String busquedaHistorial = '';
  String? consejoGeneradoIA;
  bool consejoGeneradoPorIA = false;
  bool generandoConsejoIA = false;
  bool importandoModeloConsejos = false;
  bool modeloConsejosDisponible = false;

  @override
  void initState() {
    super.initState();
    cargarHistorial();
    verificarModeloConsejos();
  }

  @override
  void dispose() {
    clasificador.cerrar();
    super.dispose();
  }

  Future<void> cargarHistorial() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final datos = prefs.getString('historial_ecosoft');
      if (datos == null) return;
      final lista = jsonDecode(datos) as List<dynamic>;
      final registros = <EcoRegistro>[];
      for (final item in lista) {
        try {
          registros.add(
            EcoRegistro.fromJson(Map<String, dynamic>.from(item as Map)),
          );
        } catch (e) {
          debugPrint('Registro de historial omitido: $e');
        }
      }
      if (!mounted) return;
      setState(() {
        historial
          ..clear()
          ..addAll(registros);
      });
    } catch (e) {
      debugPrint('Error al cargar historial: $e');
    }
  }

  Future<void> guardarHistorialLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'historial_ecosoft',
        jsonEncode(historial.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar el historial: $e')),
        );
      }
    }
  }

  Future<void> seleccionarImagen(ImageSource source) async {
    try {
      final archivo = await picker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 1800,
      );
      if (archivo == null) return;
      final bytes = await archivo.readAsBytes();
      if (!mounted) return;
      setState(() {
        imagen = bytes;
        nombreImagen = archivo.name;
        resultado = null;
        pagina = 1;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo abrir la imagen: $e')));
    }
  }

  Future<void> mostrarOpcionesImagen() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Agregar residuo',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Tomar fotografía'),
              onTap: () {
                Navigator.pop(ctx);
                seleccionarImagen(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () {
                Navigator.pop(ctx);
                seleccionarImagen(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> analizarImagen() async {
    if (imagen == null || cargando) return;
    setState(() {
      cargando = true;
      resultado = null;
    });
    try {
      if (!clasificador.modeloCargado) {
        await clasificador.cargarModelo();
      }
      final prediccion = await clasificador.clasificarImagen(imagen!);
      if (!mounted) return;
      setState(() {
        resultado = prediccion;
        modeloCargado = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo analizar la imagen: $e'),
          duration: const Duration(seconds: 7),
        ),
      );
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  void guardarClasificacion() {
    final actual = resultado;
    final bytes = imagen;
    if (actual == null || bytes == null) return;

    setState(() {
      historial.insert(
        0,
        EcoRegistro(
          nombre: clasificador.nombreEnEspanol(actual.etiqueta),
          etiqueta: actual.etiqueta,
          contenedor: obtenerContenedor(actual.etiqueta),
          recomendacion: obtenerRecomendacion(actual.etiqueta),
          fecha: DateTime.now(),
          imagen: Uint8List.fromList(bytes),
          confianza: actual.confianza,
        ),
      );
      consejoGeneradoIA = null;
      consejoGeneradoPorIA = false;
      imagen = null;
      nombreImagen = '';
      resultado = null;
      pagina = 2;
    });
    guardarHistorialLocal();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Clasificación guardada en el historial.')),
    );
  }

  Future<void> eliminarRegistro(EcoRegistro registro) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar registro'),
        content: Text('¿Quieres eliminar "${registro.nombre}" del historial?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    setState(() {
      historial.remove(registro);
      consejoGeneradoIA = null;
      consejoGeneradoPorIA = false;
    });
    await guardarHistorialLocal();
  }

  Future<void> generarConsejoIA(AnalisisHabitos analisis) async {
    if (generandoConsejoIA ||
        analisis.consejo.isEmpty ||
        !generadorConsejos.soportado ||
        !modeloConsejosDisponible) {
      return;
    }

    setState(() {
      generandoConsejoIA = true;
      consejoGeneradoIA = null;
      consejoGeneradoPorIA = false;
    });

    try {
      final resultado = await generadorConsejos.generarConsejo(
        analisis,
        onProgress: (_, _) {},
      );
      if (!mounted) return;
      setState(() {
        consejoGeneradoIA = resultado.texto;
        consejoGeneradoPorIA = resultado.generadoPorIA;
      });
      if (!resultado.generadoPorIA) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'El modelo no produjo una respuesta útil. Se muestra la sugerencia personalizada de respaldo.'
              '${resultado.motivoRespaldo == null ? '' : ' Motivo: ${resultado.motivoRespaldo}'}',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        consejoGeneradoIA = construirConsejoPersonalizado(analisis);
        consejoGeneradoPorIA = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo generar el consejo con IA local. Se muestra una sugerencia personalizada de respaldo. ($e)',
          ),
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => generandoConsejoIA = false);
      }
    }
  }

  Future<void> verificarModeloConsejos() async {
    try {
      final disponible = await generadorConsejos.modeloInstalado;
      if (mounted) setState(() => modeloConsejosDisponible = disponible);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo comprobar el modelo local: $e')),
      );
    }
  }

  Future<void> importarModeloGemma() async {
    if (importandoModeloConsejos || generandoConsejoIA) return;

    try {
      final seleccion = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['litertlm'],
      );
      if (seleccion.isEmpty) return;
      final ruta = seleccion.single.path;
      if (ruta == null) {
        throw StateError('No se pudo acceder al archivo seleccionado.');
      }

      setState(() => importandoModeloConsejos = true);
      await generadorConsejos.importarModelo(ruta);
      if (!mounted) return;
      setState(() => modeloConsejosDisponible = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Modelo Gemma importado correctamente.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo importar el modelo Gemma: $e'),
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) setState(() => importandoModeloConsejos = false);
    }
  }

  void abrirDetalle(EcoRegistro registro) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.memory(
                  registro.imagen,
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox(
                    height: 160,
                    child: Center(child: Icon(Icons.image_not_supported)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                registro.nombre,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _infoLinea(Icons.delete_outline, registro.contenedor),
              _infoLinea(Icons.calendar_today_outlined, _fecha(registro.fecha)),
              if (registro.confianza > 0)
                _infoLinea(
                  Icons.analytics_outlined,
                  'Puntuación del modelo: ${(registro.confianza * 100).toStringAsFixed(1)}%',
                ),
              const SizedBox(height: 16),
              const Text(
                'Recomendación',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
              const SizedBox(height: 6),
              Text(registro.recomendacion, style: const TextStyle(height: 1.5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoLinea(IconData icono, String textoLinea) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Icon(icono, size: 19, color: verde),
        const SizedBox(width: 8),
        Expanded(child: Text(textoLinea)),
      ],
    ),
  );

  String _fecha(DateTime fecha) =>
      '${fecha.day.toString().padLeft(2, '0')}/'
      '${fecha.month.toString().padLeft(2, '0')}/${fecha.year} '
      '${fecha.hour.toString().padLeft(2, '0')}:'
      '${fecha.minute.toString().padLeft(2, '0')}';

  String obtenerRecomendacion(String etiqueta) {
    switch (etiqueta.toLowerCase()) {
      case 'battery':
        return 'No deposites las baterías en las canecas comunes. Guárdalas de forma segura y entrégalas en un punto de recolección posconsumo autorizado.';
      case 'biological':
        return 'Deposita los residuos orgánicos aprovechables en el contenedor verde. Si tienes las condiciones adecuadas, puedes aprovecharlos mediante compostaje.';
      case 'brown-glass':
      case 'green-glass':
      case 'white-glass':
        return 'Vacía los envases y entrégalos limpios. Manipula con cuidado cualquier vidrio roto y sigue las instrucciones del servicio local.';
      case 'cardboard':
        return 'Pliega el cartón y mantenlo limpio y seco antes de depositarlo en el contenedor blanco.';
      case 'clothes':
      case 'shoes':
        return 'Si están en buen estado, reutilízalos o dónalos. Si no, busca un programa de recolección textil; no los deposites automáticamente con reciclables.';
      case 'metal':
        return 'Vacía los recipientes metálicos y entrégalos limpios y secos en el contenedor blanco.';
      case 'paper':
        return 'Mantén el papel limpio y seco. El papel contaminado con grasa o residuos orgánicos puede no ser aprovechable.';
      case 'plastic':
        return 'Vacía los envases plásticos y entrégalos limpios y secos en el contenedor blanco. Aplástalos si las indicaciones locales lo permiten.';
      case 'trash':
        return 'Deposita este residuo en el contenedor negro cuando no sea aprovechable. Revisa si existe una ruta especial para este material.';
      default:
        return 'Verifica el material y consulta las indicaciones de separación de residuos de tu municipio.';
    }
  }

  String obtenerContenedor(String etiqueta) {
    switch (etiqueta.toLowerCase()) {
      case 'battery':
        return 'Punto de recolección especial';
      case 'biological':
        return 'Contenedor verde';
      case 'brown-glass':
      case 'green-glass':
      case 'white-glass':
      case 'cardboard':
      case 'metal':
      case 'paper':
      case 'plastic':
        return 'Contenedor blanco';
      case 'clothes':
      case 'shoes':
        return 'Reutilización / recolección textil';
      case 'trash':
      default:
        return 'Contenedor negro';
    }
  }

  @override
  Widget build(BuildContext context) {
    final pantallas = [
      _inicio(),
      _escaner(),
      _historialPage(),
      _estadisticasPage(),
      _aprenderPage(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.eco, color: verde, size: 29),
            SizedBox(width: 8),
            Text('EcoSoft', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: SafeArea(
        child: IndexedStack(index: pagina, children: pantallas),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: pagina,
        onDestinationSelected: (index) => setState(() => pagina = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.center_focus_strong),
            selectedIcon: Icon(Icons.camera_alt),
            label: 'Escanear',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'Historial'),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            label: 'Estadísticas',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            label: 'Aprender',
          ),
        ],
      ),
    );
  }

  Widget _inicio() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 8),
        const Text(
          'Pequeñas acciones,\ngrandes cambios 🌱',
          style: TextStyle(
            fontSize: 29,
            height: 1.2,
            fontWeight: FontWeight.bold,
            color: texto,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Identifica tus residuos y aprende a clasificarlos.',
          style: TextStyle(color: Colors.black54, fontSize: 15),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: verde,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reciclar empieza aquí',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Reconoce, separa y aprovecha mejor tus residuos.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              Icon(Icons.recycling, color: Colors.white, size: 52),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: _resumenInicio(
                'Registros',
                '${historial.length}',
                Icons.inventory_2_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _resumenInicio(
                'Este mes',
                '${_registrosMes().length}',
                Icons.calendar_month_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const Text(
          '¿Qué quieres hacer?',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        _accionInicio(
          Icons.camera_alt_outlined,
          'Escanear un residuo',
          'Tomar una foto o usar la cámara en vivo.',
          () => setState(() => pagina = 1),
        ),
        _accionInicio(
          Icons.history,
          'Consultar mi historial',
          'Revisar y administrar tus clasificaciones.',
          () => setState(() => pagina = 2),
        ),
        _accionInicio(
          Icons.menu_book_outlined,
          'Aprender a separar',
          'Conocer los contenedores y buenas prácticas.',
          () => setState(() => pagina = 4),
        ),
        const SizedBox(height: 16),
        const Card(
          child: ListTile(
            leading: Icon(Icons.lightbulb_outline, color: verde),
            title: Text('Consejo ecológico'),
            subtitle: Text(
              'Los residuos aprovechables deben mantenerse limpios y secos para facilitar su recuperación.',
            ),
          ),
        ),
      ],
    );
  }

  Widget _resumenInicio(String titulo, String valor, IconData icono) => Card(
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: verde),
          const SizedBox(height: 8),
          Text(
            valor,
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
          ),
          Text(titulo, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    ),
  );

  Widget _accionInicio(
    IconData icono,
    String titulo,
    String subtitulo,
    VoidCallback accion,
  ) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.all(12),
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFD1FAE5),
        child: Icon(icono, color: const Color(0xFF047857)),
      ),
      title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitulo),
      trailing: const Icon(Icons.chevron_right),
      onTap: accion,
    ),
  );

  Widget _escaner() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Escanea tu residuo',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.bold,
            color: texto,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Analiza una fotografía o utiliza el reconocimiento en vivo.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 20),
        Container(
          height: 270,
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5EE),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFD1E8DA)),
          ),
          child: imagen == null
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      size: 60,
                      color: Color(0xFF059669),
                    ),
                    SizedBox(height: 14),
                    Text(
                      'Tu imagen aparecerá aquí',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: texto,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Procura tener buena iluminación',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                )
              : Image.memory(imagen!, fit: BoxFit.contain),
        ),
        if (nombreImagen.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(nombreImagen, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: cargando ? null : mostrarOpcionesImagen,
          icon: const Icon(Icons.add_a_photo_outlined),
          label: const Text('Tomar foto o elegir de galería'),
          style: FilledButton.styleFrom(
            backgroundColor: verde,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CamaraEnVivo()),
          ),
          icon: const Icon(Icons.videocam_outlined),
          label: const Text('Iniciar reconocimiento en vivo'),
        ),
        if (imagen != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: cargando
                      ? null
                      : () => setState(() {
                          imagen = null;
                          nombreImagen = '';
                          resultado = null;
                        }),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Cambiar imagen'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: cargando ? null : analizarImagen,
                  icon: const Icon(Icons.search),
                  label: Text(cargando ? 'Analizando...' : 'Analizar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: verde,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (resultado != null) _resultadoCard(),
        const SizedBox(height: 12),
        const Text(
          'Nota: el reconocimiento en vivo muestra detecciones en pantalla, pero no guarda fotogramas automáticamente. Solo se guardan en el historial los resultados de fotografías cuando pulsas “Guardar en historial”.',
          style: TextStyle(color: Colors.black54, fontSize: 12, height: 1.4),
        ),
      ],
    );
  }

  Widget _resultadoCard() {
    final r = resultado!;
    return Card(
      margin: const EdgeInsets.only(top: 18),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.check_circle, color: verde, size: 25),
                SizedBox(width: 8),
                Text(
                  'Resultado de clasificación',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              clasificador.nombreEnEspanol(r.etiqueta),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: texto,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Puntuación del modelo: ${(r.confianza * 100).toStringAsFixed(1)}%',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 14),
            _contenedorBadge(obtenerContenedor(r.etiqueta)),
            const SizedBox(height: 14),
            const Text(
              'Recomendación EcoSoft',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              obtenerRecomendacion(r.etiqueta),
              style: const TextStyle(height: 1.5),
            ),
            if (r.alternativas.length > 1) ...[
              const SizedBox(height: 14),
              const Text(
                'Otras categorías consideradas',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              ...r.alternativas
                  .skip(1)
                  .map(
                    (p) => Text(
                      '${clasificador.nombreEnEspanol(p.etiqueta)} · ${(p.confianza * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: guardarClasificacion,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Guardar en historial'),
                style: FilledButton.styleFrom(
                  backgroundColor: verde,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'La puntuación es una estimación del modelo, no una garantía de que la clasificación sea correcta.',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contenedorBadge(String nombre) {
    final color = nombre.contains('verde')
        ? Colors.green
        : nombre.contains('blanco')
        ? Colors.blueGrey.shade100
        : nombre.contains('especial')
        ? Colors.amber
        : Colors.black87;
    final fg = nombre.contains('blanco') ? texto : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        nombre,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold),
      ),
    );
  }

  List<EcoRegistro> _registrosMes() {
    final ahora = DateTime.now();
    return historial
        .where(
          (r) => r.fecha.year == ahora.year && r.fecha.month == ahora.month,
        )
        .toList();
  }

  Widget _historialPage() {
    final categorias = [
      'Todos',
      'Contenedor blanco',
      'Contenedor verde',
      'Contenedor negro',
      'Punto de recolección especial',
    ];
    final filtrados = historial.where((r) {
      final coincideFiltro =
          filtroHistorial == 'Todos' || r.contenedor == filtroHistorial;
      final q = busquedaHistorial.trim().toLowerCase();
      final coincideTexto =
          q.isEmpty ||
          r.nombre.toLowerCase().contains(q) ||
          r.contenedor.toLowerCase().contains(q);
      return coincideFiltro && coincideTexto;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Mi historial',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.bold,
            color: texto,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${historial.length} clasificaciones guardadas',
          style: const TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 16),
        TextField(
          decoration: InputDecoration(
            hintText: 'Buscar por residuo o contenedor',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (v) => setState(() => busquedaHistorial = v),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: filtroHistorial,
          decoration: InputDecoration(
            labelText: 'Filtrar por contenedor',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
          ),
          items: categorias
              .map(
                (c) => DropdownMenuItem(
                  value: c,
                  child: Text(c, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => filtroHistorial = v ?? 'Todos'),
        ),
        const SizedBox(height: 14),
        if (historial.isEmpty)
          const _EstadoVacio(
            icono: Icons.history,
            titulo: 'Aún no tienes registros',
            detalle: 'Analiza una fotografía y guarda el resultado para consultarlo aquí.',
          )
        else if (filtrados.isEmpty)
          const _EstadoVacio(
            icono: Icons.search_off,
            titulo: 'No hay coincidencias',
            detalle: 'Prueba con otro texto o filtro.',
          )
        else
          ...filtrados.map(
            (r) => Card(
              child: ListTile(
                onTap: () => abrirDetalle(r),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.memory(
                    r.imagen,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(
                      width: 56,
                      height: 56,
                      child: Icon(Icons.image_not_supported),
                    ),
                  ),
                ),
                title: Text(
                  r.nombre,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${r.contenedor}\n${_fecha(r.fecha)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'ver') abrirDetalle(r);
                    if (v == 'eliminar') eliminarRegistro(r);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'ver', child: Text('Ver detalle')),
                    PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _estadisticasPage() {
    final total = historial.length;
    final analisisHabitos = const RecomendadorHabitos().analizar(
      historial.map(
        (registro) => RegistroParaRecomendacion(
          etiqueta: registro.etiqueta,
          nombre: registro.nombre,
          fecha: registro.fecha,
        ),
      ),
    );
    final blanco = historial
        .where((r) => r.contenedor == 'Contenedor blanco')
        .length;
    final verdeCount = historial
        .where((r) => r.contenedor == 'Contenedor verde')
        .length;
    final negro = historial
        .where((r) => r.contenedor == 'Contenedor negro')
        .length;
    final especial = historial
        .where((r) => r.contenedor == 'Punto de recolección especial')
        .length;
    final mes = _registrosMes();
    final maxValor = [
      blanco,
      verdeCount,
      negro,
      especial,
      1,
    ].reduce((a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Estadísticas',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.bold,
            color: texto,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Resumen de las clasificaciones que has guardado.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _estadisticaTarjeta(
                'Total',
                '$total',
                Icons.inventory_2_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _estadisticaTarjeta(
                'Este mes',
                '${mes.length}',
                Icons.calendar_month_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _tarjetaRecomendacion(analisisHabitos),
        const SizedBox(height: 20),
        const Text(
          'Distribución por contenedor',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _barraEstadistica(
          'Blanco · aprovechables',
          blanco,
          total,
          const Color(0xFFCBD5E1),
          maxValor,
        ),
        _barraEstadistica(
          'Verde · orgánicos',
          verdeCount,
          total,
          const Color(0xFF16A34A),
          maxValor,
        ),
        _barraEstadistica(
          'Negro · no aprovechables',
          negro,
          total,
          const Color(0xFF1F2937),
          maxValor,
        ),
        _barraEstadistica(
          'Especial · posconsumo',
          especial,
          total,
          const Color(0xFFF59E0B),
          maxValor,
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Actividad de los últimos 7 días',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                const SizedBox(height: 12),
                ...List.generate(7, (i) {
                  final dia = DateTime.now().subtract(Duration(days: 6 - i));
                  final cantidad = historial
                      .where(
                        (r) =>
                            r.fecha.year == dia.year &&
                            r.fecha.month == dia.month &&
                            r.fecha.day == dia.day,
                      )
                      .length;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 48,
                          child: Text(
                            [
                              'Lun',
                              'Mar',
                              'Mié',
                              'Jue',
                              'Vie',
                              'Sáb',
                              'Dom',
                            ][dia.weekday - 1],
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: cantidad == 0
                                  ? 0
                                  : cantidad /
                                        (historial.isEmpty
                                            ? 1
                                            : historial.length),
                              minHeight: 9,
                              backgroundColor: const Color(0xFFE5E7EB),
                              color: verde,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 32,
                          child: Text('$cantidad', textAlign: TextAlign.end),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Las estadísticas se calculan únicamente con los resultados que guardas manualmente; el reconocimiento en vivo no modifica estos datos.',
          style: TextStyle(color: Colors.black54, fontSize: 12, height: 1.4),
        ),
      ],
    );
  }

  Widget _tarjetaRecomendacion(AnalisisHabitos analisis) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline, color: verde),
              SizedBox(width: 8),
              Text(
                'Recomendación personalizada',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            analisis.titulo,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          Text(analisis.resumen),
          if (analisis.consejo.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Sugerencia: ${analisis.consejo}'),
          ],
          if (analisis.tendencia != null) ...[
            const SizedBox(height: 10),
            Text(
              analisis.tendencia!,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
          if (consejoGeneradoIA != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    consejoGeneradoPorIA
                        ? 'Consejo generado por IA local'
                        : 'Sugerencia personalizada de respaldo',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(consejoGeneradoIA!),
                  if (!consejoGeneradoPorIA) ...[
                    const SizedBox(height: 5),
                    const Text(
                      'Se basa en la categoría más frecuente de tu historial.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (generadorConsejos.soportado) ...[
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: importandoModeloConsejos || generandoConsejoIA
                  ? null
                  : importarModeloGemma,
              icon: importandoModeloConsejos
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_open_outlined),
              label: Text(
                importandoModeloConsejos
                    ? 'Importando Gemma...'
                    : modeloConsejosDisponible
                    ? 'Cambiar modelo Gemma 3 1B IT'
                    : 'Importar modelo Gemma 3 1B IT',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              modeloConsejosDisponible
                  ? 'Gemma 3 1B IT está instalado y funciona sin conexión.'
                  : 'Descarga el archivo de unos 557 MiB. Primero acepta la licencia de Gemma en $urlLicenciaModeloConsejos, luego descarga $urlDescargaModeloConsejos y selecciónalo aquí.',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed:
                  generandoConsejoIA ||
                      importandoModeloConsejos ||
                      !modeloConsejosDisponible ||
                      analisis.consejo.isEmpty
                  ? null
                  : () => generarConsejoIA(analisis),
              icon: generandoConsejoIA
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                generandoConsejoIA
                    ? 'Generando consejo...'
                    : 'Generar consejo con IA generativa',
              ),
            ),
            if (generandoConsejoIA) ...[
              const SizedBox(height: 6),
              const LinearProgressIndicator(),
              const SizedBox(height: 4),
              Text(
                'Cargando Gemma 3 1B IT en el dispositivo...',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
            const SizedBox(height: 4),
            const Text(
              'El consejo se genera en el dispositivo usando solo el resumen de hábitos; las fotos no se envían.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'La generación local con IA está disponible en Android.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          const SizedBox(height: 10),
          const Text(
            'El modelo local solo recibe un resumen del historial; las fotos permanecen en el dispositivo. Verifica las reglas de separación de tu localidad.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    ),
  );

  Widget _estadisticaTarjeta(String titulo, String valor, IconData icono) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icono, color: verde),
              const SizedBox(height: 8),
              Text(
                valor,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(titulo, style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ),
      );

  Widget _barraEstadistica(
    String titulo,
    int cantidad,
    int total,
    Color color,
    int maximo,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(titulo)),
            Text(
              '$cantidad${total == 0 ? '' : ' (${(cantidad * 100 / total).toStringAsFixed(0)}%)'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: cantidad / maximo,
            minHeight: 10,
            color: color,
            backgroundColor: const Color(0xFFE5E7EB),
          ),
        ),
      ],
    ),
  );

  Widget _aprenderPage() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Aprende a separar',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.bold,
            color: texto,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Guía básica de separación de residuos en Colombia.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 18),
        _tarjetaContenedor(
          color: const Color(0xFF16A34A),
          titulo: 'Contenedor verde',
          subtitulo: 'Residuos orgánicos aprovechables',
          ejemplos: 'Restos de comida y residuos orgánicos aprovechables, de acuerdo con la ruta local.',
          consejo: 'Evita mezclar estos residuos con materiales reciclables limpios y secos.',
          icono: Icons.eco,
        ),
        _tarjetaContenedor(
          color: const Color(0xFFCBD5E1),
          textoColor: texto,
          titulo: 'Contenedor blanco',
          subtitulo: 'Residuos aprovechables',
          ejemplos: 'Plástico, vidrio, metales, papel y cartón.',
          consejo: 'Entrégalos limpios y secos. Separa los materiales cuando sea posible.',
          icono: Icons.recycling,
        ),
        _tarjetaContenedor(
          color: const Color(0xFF1F2937),
          titulo: 'Contenedor negro',
          subtitulo: 'Residuos no aprovechables',
          ejemplos: 'Residuos que no pueden aprovecharse mediante las rutas ordinarias de reciclaje.',
          consejo: 'No deposites aquí pilas ni residuos especiales que requieren recolección posconsumo.',
          icono: Icons.delete_outline,
        ),
        _tarjetaContenedor(
          color: const Color(0xFFF59E0B),
          titulo: 'Recolección especial',
          subtitulo: 'Pilas y residuos posconsumo',
          ejemplos: 'Baterías y otros residuos que requieren un sistema de recolección especializado.',
          consejo: 'Consulta los puntos autorizados. Esta categoría no es una de las tres canecas de colores.',
          icono: Icons.battery_alert_outlined,
        ),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Antes de reciclar',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                SizedBox(height: 8),
                Text('• Separa los materiales en la fuente.'),
                Text('• Mantén limpios y secos los aprovechables.'),
                Text('• Reutiliza los objetos cuando sea posible.'),
                Text(
                  '• Consulta las rutas y condiciones de recolección de tu municipio.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Esta guía es orientativa. La clasificación final y los servicios de recolección pueden variar según las condiciones locales.',
          style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
        ),
      ],
    );
  }

  Widget _tarjetaContenedor({
    required Color color,
    Color textoColor = Colors.white,
    required String titulo,
    required String subtitulo,
    required String ejemplos,
    required String consejo,
    required IconData icono,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color,
                  child: Icon(icono, color: textoColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        subtitulo,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Ejemplos: $ejemplos', style: const TextStyle(height: 1.4)),
            const SizedBox(height: 6),
            Text(
              'Consejo: $consejo',
              style: const TextStyle(height: 1.4, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String detalle;

  const _EstadoVacio({
    required this.icono,
    required this.titulo,
    required this.detalle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(icono, size: 48, color: verde),
            const SizedBox(height: 12),
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              detalle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
