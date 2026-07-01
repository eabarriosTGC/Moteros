import 'package:flutter/material.dart';

class MapExplorerScreen extends StatelessWidget {
  const MapExplorerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Explorar Rutas')),
      body: const Center(
        child: Text('Mapa de lugares cercanos - Próximamente'),
      ),
    );
  }
}
