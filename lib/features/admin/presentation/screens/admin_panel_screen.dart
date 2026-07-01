import 'package:flutter/material.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Panel Admin')),
      body: const Center(
        child: Text('Gestión de aliados y contenido - Próximamente'),
      ),
    );
  }
}
