import 'package:flutter/material.dart';

import '../controllers/places_controller.dart';

/// Horizontal filter row containing star rating chips, review count popup, and sort popup.
class FilterAndSortBar extends StatelessWidget {
  final PlacesController controller;
  final List<double> ratingPresets;
  final List<int> reviewCountPresets;
  final ValueChanged<double>? onRatingSelected;
  final ValueChanged<int>? onReviewCountSelected;
  final ValueChanged<SortOption>? onSortSelected;

  const FilterAndSortBar({
    super.key,
    required this.controller,
    this.ratingPresets = const [0.0, 4.0, 4.3, 4.5, 4.7],
    this.reviewCountPresets = const [0, 50, 100, 200, 500],
    this.onRatingSelected,
    this.onReviewCountSelected,
    this.onSortSelected,
  });

  String _formatSortOption(SortOption option) {
    switch (option) {
      case SortOption.distance:
        return 'En Yakın';
      case SortOption.rating:
        return 'En Yüksek Puan';
      case SortOption.reviews:
        return 'En Çok Yorum';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final currentRating = controller.minRating;
        final currentReviewCount = controller.minReviewCount;
        final currentSort = controller.sortOption;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const Text(
                'Min. Puan:',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(width: 6),
              ...ratingPresets.map((star) {
                final isSelected = (currentRating - star).abs() < 0.05;
                final label =
                    star == 0.0 ? 'Tümü' : '${star.toStringAsFixed(1)}+ ★';

                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    key: ValueKey('rating_chip_${star.toStringAsFixed(1)}'),
                    onTap: () {
                      controller.setMinRating(star);
                      onRatingSelected?.call(star);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFFBBF24)
                            : const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFFBBF24)
                              : Colors.white12,
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(width: 8),

              // Minimum Review Count Filter Popup
              PopupMenuButton<int>(
                key: const Key('review_count_popup_button'),
                initialValue: currentReviewCount,
                color: const Color(0xFF1E293B),
                onSelected: (val) {
                  controller.setMinReviewCount(val);
                  onReviewCountSelected?.call(val);
                },
                itemBuilder: (_) => reviewCountPresets.map((count) {
                  return PopupMenuItem<int>(
                    key: ValueKey('review_count_item_$count'),
                    value: count,
                    child: Text(
                      count == 0
                          ? '💬 Tüm Yorum Sayıları'
                          : '💬 En Az $count+ Yorum',
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }).toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: currentReviewCount > 0
                        ? const Color(0xFF38BDF8).withValues(alpha: 0.2)
                        : const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: currentReviewCount > 0
                          ? const Color(0xFF38BDF8)
                          : Colors.white24,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.reviews_rounded,
                        size: 14,
                        color: Color(0xFF38BDF8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        currentReviewCount == 0
                            ? 'Yorum Sayısı'
                            : '$currentReviewCount+ Yorum',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Sort Option Popup
              PopupMenuButton<SortOption>(
                key: const Key('sort_option_popup_button'),
                initialValue: currentSort,
                color: const Color(0xFF1E293B),
                onSelected: (val) {
                  controller.setSortOption(val);
                  onSortSelected?.call(val);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    key: Key('sort_item_distance'),
                    value: SortOption.distance,
                    child: Text(
                      '📏 En Yakın Mesafe',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  PopupMenuItem(
                    key: Key('sort_item_rating'),
                    value: SortOption.rating,
                    child: Text(
                      '⭐ En Yüksek Puan',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  PopupMenuItem(
                    key: Key('sort_item_reviews'),
                    value: SortOption.reviews,
                    child: Text(
                      '💬 En Çok Yorum Alan',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.sort_rounded,
                        size: 15,
                        color: Color(0xFFFBBF24),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatSortOption(currentSort),
                        key: const Key('active_sort_label'),
                        style: const TextStyle(
                          color: Colors.white,
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
