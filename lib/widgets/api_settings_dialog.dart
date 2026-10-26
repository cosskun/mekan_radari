import 'package:flutter/material.dart';

import '../controllers/places_controller.dart';

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
      backgroundColor: const Color(0xFF1E293B),
      title: const Row(
        children: [
          Icon(Icons.cloud_sync_rounded, color: Color(0xFFFBBF24)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Veri Kaynağı & API Ayarları',
              style: TextStyle(color: Colors.white, fontSize: 17),
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
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.4),
                ),
              ),
              child: const Text(
                '✓ Şu Anda Aktif: Canlı OpenStreetMap (Overpass & Nominatim) Motoru.\n\n'
                'Hiçbir API anahtarına ihtiyaç duymadan çevrenizdeki gerçek dünyadaki '
                'tatlıcıları, kafeleri ve restoranları gerçek koordinat ve metre mesafeleriyle çeker. '
                'Her karttaki "Google Yorumları" butonuyla da o mekanın gerçek Google sayfasını açabilirsiniz.',
                style: TextStyle(color: Colors.white, fontSize: 12.5, height: 1.4),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'İsteğe Bağlı Google Places API (New) Anahtarı:',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _keyController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText:
                    'AIzaSy... (Boş bırakırsanız ücretsiz canlı motor çalışır)',
                hintStyle:
                    const TextStyle(color: Colors.white38, fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                suffixIcon: _keyController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          color: Colors.white54,
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
                  borderSide: BorderSide.none,
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
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'İptal',
            style: TextStyle(color: Colors.white60),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFF59E0B),
            foregroundColor: Colors.black,
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
