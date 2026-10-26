import 'package:flutter/material.dart';

import '../controllers/places_controller.dart';
import '../theme/app_theme.dart';

/// Configuration dialog for Google Places API Key.
///
/// Explains that OpenStreetMap operates without API keys, while allowing
/// optional entry, saving, and clearing of Google Places API Key.
class ApiSettingsDialog extends StatefulWidget {
  final PlacesController controller;

  const ApiSettingsDialog({
    super.key,
    required this.controller,
  });

  /// Displays the API settings dialog.
  static Future<void> show({
    required BuildContext context,
    required PlacesController controller,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => ApiSettingsDialog(controller: controller),
    );
  }

  @override
  State<ApiSettingsDialog> createState() => _ApiSettingsDialogState();
}

class _ApiSettingsDialogState extends State<ApiSettingsDialog> {
  late final TextEditingController _keyController;

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController(
      text: widget.controller.googleApiKey ?? '',
    );
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  void _saveApiKey() {
    final val = _keyController.text.trim();
    Navigator.pop(context);
    widget.controller.setGoogleApiKey(val.isEmpty ? null : val);
  }

  void _clearApiKey() {
    Navigator.pop(context);
    widget.controller.setGoogleApiKey(null);
  }

  @override
  Widget build(BuildContext context) {
    final hasStoredKey = widget.controller.googleApiKey != null &&
        widget.controller.googleApiKey!.isNotEmpty;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      title: const Row(
        children: [
          Icon(Icons.cloud_sync_rounded, color: AppColors.primary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Veri Kaynağı & API Ayarları',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.greenLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.green.withValues(alpha: 0.4),
                ),
              ),
              child: const Text(
                '✓ Şu Anda Aktif: Canlı OpenStreetMap (Overpass & Nominatim) Motoru.\n\n'
                'Hiçbir API anahtarına ihtiyaç duymadan çevrenizdeki gerçek dünyadaki '
                'tatlıcıları, kafeleri ve restoranları gerçek koordinat ve metre mesafeleriyle çeker. '
                'Her karttaki "Google Yorumları" butonuyla da o mekanın gerçek Google sayfasını açabilirsiniz.',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 12.5, height: 1.4),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'İsteğe Bağlı Google Places API (New) Anahtarı:',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _keyController,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText:
                    'AIzaSy... (Boş bırakırsanız ücretsiz canlı motor çalışır)',
                hintStyle:
                    const TextStyle(color: AppColors.textDisabled, fontSize: 12),
                filled: true,
                fillColor: AppColors.inputBackground,
                suffixIcon: _keyController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          color: AppColors.textTertiary,
                          size: 18,
                        ),
                        onPressed: () {
                          setState(() {
                            _keyController.clear();
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        if (hasStoredKey)
          TextButton(
            onPressed: _clearApiKey,
            child: const Text(
              'Anahtarı Temizle',
              style: TextStyle(color: AppColors.red),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'İptal',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: _saveApiKey,
          child: const Text(
            'Kaydet & Yenile',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
