import 'package:flutter/material.dart';

import '../controllers/places_controller.dart';
import '../models/place_model.dart';
import '../theme/app_theme.dart';

/// Empty state view presented when no venues match the active filters within
/// the radar search radius. Features an adaptive radius suggestion button
/// to encompass the closest qualifying venue.
class EmptyVenuesView extends StatelessWidget {
  final PlacesController controller;
  final VoidCallback? onExpandRadius;
  final VoidCallback? onResetFilters;

  const EmptyVenuesView({
    super.key,
    required this.controller,
    this.onExpandRadius,
    this.onResetFilters,
  });

  /// Formats meters into human-readable distance label (e.g. "500 m" or "1.5 km").
  static String formatRadius(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final radiusMeters = controller.radiusMeters;
        final minRating = controller.minRating;
        final Place? closestOutside = controller.closestPlaceOutsideRadius;

        return Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppColors.cardShadow,
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.radar_rounded,
                    size: 54,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${formatRadius(radiusMeters)} yarıçapında ve ${minRating.toStringAsFixed(1)}+ yıldızda mekan bulunamadı.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (closestOutside != null) ...[
                    Text(
                      'Ancak kriterlerinize uyan en yakın gerçek mekan "${closestOutside.name}" (${closestOutside.rating} ★) şu an tam ${closestOutside.formattedDistance} mesafede!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.blue,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: onExpandRadius ??
                          () => controller.expandRadiusToClosestPlace(),
                      icon: const Icon(Icons.open_in_full_rounded),
                      label: Text(
                        'Yarıçapı ${(closestOutside.distanceMeters + 50).round()}m Yap ve Göster',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'Mesafe yarıçapını biraz artırmayı veya minimum yıldız filtresini esnetmeyi deneyebilirsiniz.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: onResetFilters ??
                          () {
                            controller.setRadiusMeters(1000.0);
                            controller.setMinRating(4.0);
                          },
                      child: const Text(
                        '1 km & 4.0+ Yıldız Olarak Göster',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
      },
    );
  }
}
