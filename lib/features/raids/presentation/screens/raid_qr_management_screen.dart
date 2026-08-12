library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/raid_conquest_repository.dart';
import '../arrival_credential.dart';

class RaidQrManagementScreen extends StatefulWidget {
  final Map<String, dynamic> raid;

  const RaidQrManagementScreen({super.key, required this.raid});

  @override
  State<RaidQrManagementScreen> createState() => _RaidQrManagementScreenState();
}

class _RaidQrManagementScreenState extends State<RaidQrManagementScreen> {
  final _repository = RaidConquestRepository();
  List<Map<String, dynamic>> _codes = const [];
  bool _loading = true;

  int get _raidId => (widget.raid['id'] as num).toInt();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final codes = await _repository.listQrCodes(_raidId);
      if (!mounted) return;
      setState(() {
        _codes = codes;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack(RaidConquestRepository.friendlyError(error));
    }
  }

  Future<void> _create() async {
    final controller = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Nuevo código físico'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 120,
          decoration: const InputDecoration(
            labelText: 'Ubicación del código',
            hintText: 'Ej: Entrada principal',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('GENERAR'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || label == null || label.isEmpty) return;
    try {
      final generated = await _repository.generateQr(raidId: _raidId, label: label);
      if (!mounted) return;
      await _showGenerated(generated);
      await _load();
    } catch (error) {
      if (mounted) _snack(RaidConquestRepository.friendlyError(error));
    }
  }

  Future<void> _showGenerated(Map<String, dynamic> generated) async {
    final token = generated['qr_token'].toString();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(generated['label'].toString(), style: const TextStyle(color: Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(
              data: token,
              version: QrVersions.auto,
              size: 260,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
            ),
            if (generated['manual_code'] != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Código manual para compartir',
                style: TextStyle(
                    color: Colors.black87, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                formatManualCode(generated['manual_code'].toString()),
                style: const TextStyle(
                    color: Colors.black,
                    fontSize: 22,
                    letterSpacing: 4,
                    fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(
                      text: formatManualCode(
                              generated['manual_code'].toString())
                          .replaceAll('-', '')));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Código copiado')),
                    );
                  }
                },
                icon: const Icon(Icons.copy),
                label: const Text('COPIAR'),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Guarda una captura para imprimir. Por seguridad, el código completo solo se muestra ahora.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black87),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: token));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Código copiado')),
                );
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('COPIAR'),
          ),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('LISTO')),
        ],
      ),
    );
  }

  Future<void> _toggle(Map<String, dynamic> code, bool active) async {
    try {
      await _repository.setQrActive(code['id'].toString(), active);
      await _load();
    } catch (error) {
      if (mounted) _snack(RaidConquestRepository.friendlyError(error));
    }
  }

  void _snack(String message) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('CÓDIGOS DEL DESTINO'),
        backgroundColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.qr_code_2),
        label: const Text('GENERAR'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnAmber,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _codes.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: Text(
                      'Aún no hay códigos. Genera uno por cada ubicación física donde será instalado.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    96,
                  ),
                  itemCount: _codes.length,
                  itemBuilder: (context, index) {
                    final code = _codes[index];
                    final active = code['is_active'] as bool? ?? false;
                    return Card(
                      color: AppColors.surface,
                      child: SwitchListTile(
                        value: active,
                        activeThumbColor: AppColors.success,
                        onChanged: (value) => _toggle(code, value),
                        secondary: Icon(
                          Icons.qr_code,
                          color: active ? AppColors.primary : AppColors.textMuted,
                        ),
                        title: Text(code['label'].toString()),
                        subtitle: Text(active ? 'Activo' : 'Desactivado'),
                      ),
                    );
                  },
                ),
    );
  }
}
