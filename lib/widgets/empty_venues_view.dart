import 'package:flutter/material.dart';

import '../controllers/places_controller.dart';
import '../models/place_model.dart';

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
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.radar_rounded,
                    size: 54,
                    color: Color(0xFFFBBF24),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${formatRadius(radiusMeters)} yarıçapında ve ${minRating.toStringAsFixed(1)}+ yıldızda mekan bulunamadı.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
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
                        color: Color(0xFF38BDF8),
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.black,
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
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF38BDF8),
                        foregroundColor: Colors.black,
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
