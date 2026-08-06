/// SaveRouteDialog — diálogo de nombre de ruta (M-RTR-6 UX).
///
/// Extraído del tracker screen para testearlo sin FlutterMap (precedente del
/// repo). El botón GUARDAR se DESHABILITA con nombre vacío (antes solo
/// ignoraba el tap en silencio — parecía un botón roto). onSave recibe el
/// nombre trimmeado y hace pop antes de notificar.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/design_tokens.dart';

class SaveRouteDialog extends StatefulWidget {
  const SaveRouteDialog({super.key, required this.onSave});

  final ValueChanged<String> onSave;

  @override
  State<SaveRouteDialog> createState() => _SaveRouteDialogState();
}

class _SaveRouteDialogState extends State<SaveRouteDialog> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Guardar ruta', style: AppTypography.titleLarge),
      content: TextField(
        controller: _nameController,
        autofocus: true,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: const InputDecoration(
          hintText: 'Nombre de la ruta',
          hintStyle: TextStyle(color: AppColors.textMuted),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.primary),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCELAR', style: AppTypography.buttonSmall),
        ),
        // GUARDAR deshabilitado con nombre vacío (UX: no parecer roto).
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _nameController,
          builder: (context, value, _) {
            final name = value.text.trim();
            return TextButton(
              onPressed: name.isEmpty
                  ? null
                  : () {
                      Navigator.pop(context);
                      widget.onSave(name);
                    },
              child: const Text('GUARDAR', style: AppTypography.buttonSmall),
            );
          },
        ),
      ],
    );
  }
}
