import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../controllers/places_controller.dart';
import '../models/location_preset.dart';
import '../theme/app_theme.dart';
import 'api_settings_dialog.dart';
import 'location_picker_sheet.dart';

/// Top application bar for [HomeScreen].
///
/// Implements [PreferredSizeWidget] and automatically rebuilds when [PlacesController]
/// changes location label or favorites filter mode.
class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final PlacesController controller;
  final VoidCallback? onLocationTap;
  final Future<void> Function()? onGpsPressed;
  final VoidCallback? onFavoritesTap;
  final VoidCallback? onApiSettingsTap;
  final void Function(double lat, double lon)? onLocationChanged;
  final bool showApiSettings;

  const HomeAppBar({
    super.key,
    required this.controller,
    this.onLocationTap,
    this.onGpsPressed,
    this.onFavoritesTap,
    this.onApiSettingsTap,
    this.onLocationChanged,
    this.showApiSettings = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  /// Performs GPS location detection with full permission checks and SnackBar feedback.
  static Future<void> useCurrentGpsLocation({
    required BuildContext context,
    required PlacesController controller,
    void Function(double lat, double lon)? onLocationChanged,
  }) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Cihazınızda konum servisi kapalı. Lütfen açın veya haritadan konum seçin.',
              ),
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Konum izni verilmedi. Arama kutusundan istediğiniz semti seçebilirsiniz.',
              ),
            ),
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      final province = LocationPreset.detectProvince(pos.latitude, pos.longitude);
      final label =
          'GPS • $province (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})';

      await controller.setLocation(
        lat: pos.latitude,
        lon: pos.longitude,
        label: label,
      );

      onLocationChanged?.call(pos.latitude, pos.longitude);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('GPS alınamadı: $e')),
        );
      }
    }
  }

  void _handleLocationTap(BuildContext context) {
    if (onLocationTap != null) {
      onLocationTap!();
    } else {
      LocationPickerSheet.show(
        context: context,
        controller: controller,
        onLocationSelected: onLocationChanged,
        onGpsPressed: onGpsPressed,
      );
    }
  }

  void _handleGpsTap(BuildContext context) {
    if (onGpsPressed != null) {
      onGpsPressed!();
    } else {
      useCurrentGpsLocation(
        context: context,
        controller: controller,
        onLocationChanged: onLocationChanged,
      );
    }
  }

  void _handleApiSettingsTap(BuildContext context) {
    if (onApiSettingsTap != null) {
      onApiSettingsTap!();
    } else {
      ApiSettingsDialog.show(context: context, controller: controller);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleSpacing: 16,
          title: InkWell(
            onTap: () => _handleLocationTap(context),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.radar_rounded,
                      color: AppColors.primaryDark,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mekan Radarı • Konum Seç',
                          style: TextStyle(
                            color: AppColors.primaryDark,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                controller.locationLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppColors.textTertiary,
                              size: 18,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'GPS Konumumu Bul',
              onPressed: () => _handleGpsTap(context),
              icon: const Icon(
                Icons.my_location_rounded,
                color: AppColors.blue,
              ),
            ),
            IconButton(
              tooltip: 'Favorilerim',
              onPressed: onFavoritesTap ?? controller.toggleFavoritesOnly,
              icon: Icon(
                controller.showFavoritesOnly
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: controller.showFavoritesOnly
                    ? AppColors.red
                    : AppColors.textSecondary,
              ),
            ),
            if (showApiSettings || onApiSettingsTap != null)
              IconButton(
                tooltip: 'Veri Kaynağı Ayarları',
                onPressed: () => _handleApiSettingsTap(context),
                icon: const Icon(
                  Icons.vpn_key_rounded,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        );
      },
    );
  }
}
