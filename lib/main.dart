import 'package:flutter/material.dart';

void main() => runApp(const EcoApp());

class EcoApp extends StatelessWidget {
  const EcoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'EcoGuía',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        ),
        home: const EcoHome(),
      );
}

class EcoHome extends StatefulWidget {
  const EcoHome({super.key});

  @override
  State<EcoHome> createState() => _EcoHomeState();
}

class _EcoHomeState extends State<EcoHome> {
  int _selectedIndex = 0;

  static const _pages = [_WelcomePage(), _RecommendationsPage(), _ClassificationPage()];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(child: _pages[_selectedIndex]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) => setState(() => _selectedIndex = index),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
            NavigationDestination(icon: Icon(Icons.lightbulb_outline), selectedIcon: Icon(Icons.lightbulb), label: 'Consejos'),
            NavigationDestination(icon: Icon(Icons.camera_alt_outlined), selectedIcon: Icon(Icons.camera_alt), label: 'Clasificar'),
          ],
        ),
      );
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.eco, size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 20),
            Text('EcoGuía', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Pequeñas acciones para cuidar el medio ambiente.'),
            const SizedBox(height: 30),
            const Card(child: ListTile(leading: Icon(Icons.recycling), title: Text('Aprende a reciclar'), subtitle: Text('Consulta consejos o clasifica un objeto.'))),
          ],
        ),
      );
}

class _RecommendationsPage extends StatelessWidget {
  const _RecommendationsPage();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recomendaciones', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Ideas sencillas para tu día a día.'),
            const SizedBox(height: 20),
            const _TipCard(icon: Icons.water_drop_outlined, title: 'Ahorra agua', text: 'Cierra la llave mientras te cepillas los dientes.'),
            const _TipCard(icon: Icons.shopping_bag_outlined, title: 'Usa reutilizables', text: 'Lleva una bolsa y botella reutilizable.'),
            const _TipCard(icon: Icons.power_outlined, title: 'Ahorra energía', text: 'Apaga las luces que no estés usando.'),
          ],
        ),
      );
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(leading: Icon(icon, color: Theme.of(context).colorScheme.primary), title: Text(title), subtitle: Text(text)),
      );
}

class _ClassificationPage extends StatelessWidget {
  const _ClassificationPage();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Clasifica tu residuo', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Toma o selecciona una foto y te diremos dónde desecharlo.'),
            const SizedBox(height: 32),
            Expanded(
              child: Center(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outline), borderRadius: BorderRadius.circular(16)),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_a_photo_outlined, size: 58),
                      SizedBox(height: 12),
                      Text('Aquí aparecerá la foto del objeto', textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.photo_camera_outlined), label: const Text('Agregar foto')),
            ),
          ],
        ),
      );
}
