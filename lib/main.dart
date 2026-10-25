
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const EcoSoftApp());
}

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
  final String contenedor;
  final DateTime fecha;

  EcoRegistro({
    required this.nombre,
    required this.contenedor,
    required this.fecha,
  });
}

class EcoHome extends StatefulWidget {
  const EcoHome({super.key});

  @override
  State<EcoHome> createState() => _EcoHomeState();
}

class _EcoHomeState extends State<EcoHome> {
  int pagina = 0;
  final ImagePicker picker = ImagePicker();

  Uint8List? imagen;
  String nombreImagen = '';
  bool cargando = false;

  // En esta etapa guardamos los registros solo en memoria.
  final List<EcoRegistro> historial = [];

  Future<void> seleccionarImagen(ImageSource source) async {
    try {
      final XFile? archivo = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (archivo == null) return;

      final bytes = await archivo.readAsBytes();

      if (!mounted) return;

      setState(() {
        imagen = bytes;
        nombreImagen = archivo.name;
        pagina = 1;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Imagen cargada. La clasificación automática '
            'se integrará en el siguiente paso.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir la imagen: $e')),
      );
    }
  }

  Future<void> mostrarOpcionesImagen() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Agregar residuo',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Tomar fotografía'),
                onTap: () {
                  Navigator.pop(context);
                  seleccionarImagen(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Elegir de la galería'),
                onTap: () {
                  Navigator.pop(context);
                  seleccionarImagen(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void guardarEjemplo() {
    if (imagen == null) return;

    setState(() {
      historial.insert(
        0,
        EcoRegistro(
          nombre: 'Imagen pendiente de analizar',
          contenedor: 'Por determinar',
          fecha: DateTime.now(),
        ),
      );
      imagen = null;
      nombreImagen = '';
      pagina = 2;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Registro de prueba guardado. Aún no es una clasificación real.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pantallas = [
      inicio(),
      escaner(),
      historialPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.eco, color: verde, size: 30),
            SizedBox(width: 8),
            Text(
              'EcoSoft',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: IndexedStack(
          index: pagina,
          children: pantallas,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: pagina,
        onDestinationSelected: (index) {
          setState(() => pagina = index);
        },
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
          NavigationDestination(
            icon: Icon(Icons.history),
            selectedIcon: Icon(Icons.history),
            label: 'Historial',
          ),
        ],
      ),
    );
  }

  Widget inicio() {
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
        const SizedBox(height: 24),
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
                      'Usa tu cámara para comenzar.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              Icon(Icons.recycling, color: Colors.white, size: 55),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          '¿Qué quieres hacer?',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: texto,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFD1FAE5),
              child: Icon(Icons.camera_alt, color: Color(0xFF047857)),
            ),
            title: const Text(
              'Escanear un residuo',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Toma una foto o elige una imagen.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              setState(() => pagina = 1);
            },
          ),
        ),
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFDBEAFE),
              child: Icon(Icons.history, color: Color(0xFF1D4ED8)),
            ),
            title: const Text(
              'Mi historial',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${historial.length} registros de prueba'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              setState(() => pagina = 2);
            },
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Consejo ecológico',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 8),
        const Card(
          child: ListTile(
            leading: Icon(Icons.lightbulb_outline, color: verde),
            title: Text('Separa los residuos'),
            subtitle: Text(
              'Mantener los materiales aprovechables limpios '
              'y secos facilita su aprovechamiento.',
            ),
          ),
        ),
      ],
    );
  }

  Widget escaner() {
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
          'Toma una fotografía o selecciónala desde tu dispositivo.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 24),
        Container(
          height: 300,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5EE),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFD1E8DA)),
          ),
          clipBehavior: Clip.antiAlias,
          child: imagen == null
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      size: 65,
                      color: Color(0xFF059669),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Tu imagen aparecerá aquí',
                      style: TextStyle(
                        color: texto,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Procura tener buena iluminación',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                )
              : Image.memory(
                  imagen!,
                  fit: BoxFit.contain,
                  width: double.infinity,
                ),
        ),
        if (nombreImagen.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            nombreImagen,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: cargando ? null : mostrarOpcionesImagen,
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('Tomar foto o elegir imagen'),
          style: FilledButton.styleFrom(
            backgroundColor: verde,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(54),
          ),
        ),
        if (imagen != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                imagen = null;
                nombreImagen = '';
              });
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Elegir otra imagen'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: guardarEjemplo,
            child: const Text('Guardar registro de prueba'),
          ),
          const SizedBox(height: 8),
          const Text(
            'La imagen todavía no ha sido analizada. '
            'La identificación automática se implementará después.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget historialPage() {
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
        const SizedBox(height: 8),
        const Text(
          'Aquí aparecerán tus clasificaciones guardadas.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 20),
        if (historial.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Column(
                children: [
                  Icon(Icons.history, size: 52, color: verde),
                  SizedBox(height: 12),
                  Text(
                    'Aún no tienes registros',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Cuando guardes un resultado, aparecerá aquí.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ...historial.map(
            (registro) => Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFD1FAE5),
                  child: Icon(Icons.recycling, color: Color(0xFF047857)),
                ),
                title: Text(registro.nombre),
                subtitle: Text(
                  '${registro.contenedor}\n'
                  '${registro.fecha.day}/'
                  '${registro.fecha.month}/'
                  '${registro.fecha.year}',
                ),
                isThreeLine: true,
              ),
            ),
          ),
      ],
    );
  }
}
