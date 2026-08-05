/// WhatsApp launcher — F-M11 (M-WA-1/2/3).
///
/// - Phone is revealed ON DEMAND via RPC at tap time and never lives in
///   list/card payloads (M-WA-1). This file only knows how to *launch*.
/// - The preloaded availability message NEVER contains coordinates or the
///   exact address (M-WA-3). Whether the host shares the address inside the
///   conversation is the host's own decision, made outside the app.
/// - If WhatsApp cannot be launched, the user gets the WhatsApp Web fallback
///   plus a copy action — never a silent failure (M-WA-2).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/design_tokens.dart';

/// Type aliases so tests can inject fakes for the top-level url_launcher
/// functions (which cannot be mocktail-mocked).
typedef CanLaunch = Future<bool> Function(Uri uri);
typedef Launch = Future<bool> Function(Uri uri);

/// `https://wa.me/<digits>?text=<encoded message>` — digits normalized
/// (non-digits stripped). Never carries coordinates or address (M-WA-1/3).
String buildWhatsAppUrl(String phone, String message) {
  final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  return 'https://wa.me/$digits?text=${Uri.encodeComponent(message)}';
}

/// Preloaded availability message — host alias only, no location data
/// (M-WA-3).
String buildAvailabilityMessage(String hostAlias) =>
    'Hola $hostAlias 👋 Vi tu casa de motero en Moteros. ¿Está disponible?';

/// Launches the wa.me chat, or shows the WhatsApp Web fallback sheet with a
/// copy action when WhatsApp cannot be launched (M-WA-2) — never silent.
///
/// [canLaunch]/[launch] exist for tests; production uses the real url_launcher
/// functions.
Future<void> launchWhatsAppContact(
  BuildContext context,
  String phone,
  String message, {
  CanLaunch? canLaunch,
  Launch? launch,
}) async {
  final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  final waUri = Uri.parse(buildWhatsAppUrl(phone, message));
  final canLaunchFn = canLaunch ?? canLaunchUrl;
  final launchFn = launch ??
      (Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

  try {
    if (await canLaunchFn(waUri)) {
      await launchFn(waUri);
      return;
    }
  } catch (_) {
    // Fall through to the fallback — never silent.
  }

  // Fallback (M-WA-2): WhatsApp Web + copy the message.
  final webUri = Uri.parse(
    'https://web.whatsapp.com/send?phone=$digits&text=${Uri.encodeComponent(message)}',
  );
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.chat_bubble_outline,
                    color: AppColors.success, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'WhatsApp requerido',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'No se pudo abrir WhatsApp. Abrí la versión web o copiá el '
              'mensaje para enviarlo manualmente.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  launchFn(webUri);
                },
                icon: const Icon(Icons.language, size: 18),
                label: const Text('Abrir WhatsApp Web',
                    style: AppTypography.button),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: message));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Mensaje copiado al portapapeles'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copiar mensaje', style: AppTypography.button),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
