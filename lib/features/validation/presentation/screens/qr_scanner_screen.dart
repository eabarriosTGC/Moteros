import 'package:flutter/material.dart';

class QrScannerScreen extends StatelessWidget {
  const QrScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Validar Destino')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_scanner, size: 120, color: Colors.white70),
            SizedBox(height: 24),
            Text('Escanea el código QR del lugar'),
          ],
        ),
      ),
    );
  }
}
