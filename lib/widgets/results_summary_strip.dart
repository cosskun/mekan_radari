import 'package:flutter/material.dart';

import '../controllers/places_controller.dart';
import '../theme/app_theme.dart';
import 'radius_slider_bar.dart';

/// Information strip displaying count of matching places, active filter summary, and refresh trigger.
class ResultsSummaryStrip extends StatelessWidget {
  final PlacesController controller;
  final VoidCallback? onRefresh;

  const ResultsSummaryStrip({
    super.key,
    required this.controller,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final filteredCount = controller.filteredPlaces.length;
        final radiusLabel = RadiusSliderBar.formatRadius(controller.radiusMeters);
        final minRating = controller.minRating;
        final minReviews = controller.minReviewCount;
        final favoritesOnly = controller.showFavoritesOnly;
        final isLoading = controller.isLoading;

        final ratingPart = minRating > 0
            ? '${minRating.toStringAsFixed(1)}+ ★'
            : 'Tüm puanlar';
        final reviewPart = minReviews > 0 ? ' • $minReviews+ yorum' : '';
        final favPart = favoritesOnly ? ' • Favoriler' : '';

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Text(
                '$filteredCount mekan bulundu',
                key: const Key('results_count_text'),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '($radiusLabel içinde • $ratingPart$reviewPart$favPart)',
                  key: const Key('active_filters_summary_text'),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                key: const Key('results_refresh_button'),
                onTap: isLoading ? null : (onRefresh ?? () => controller.loadPlaces()),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      if (isLoading)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.blue,
                          ),
                        )
                      else
                        const Icon(
                          Icons.refresh_rounded,
                          size: 16,
                          color: AppColors.blue,
                        ),
                      const SizedBox(width: 4),
                      Text(
                        isLoading ? 'Yükleniyor...' : 'Yenile',
                        style: const TextStyle(
                          color: AppColors.blue,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
