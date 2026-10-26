import 'package:flutter/material.dart';

import '../controllers/places_controller.dart';
import '../models/place_model.dart';

/// Horizontally scrollable row of venue category filter chips.
class CategoryChipsBar extends StatelessWidget {
  final PlacesController controller;
  final List<PlaceCategoryFilter> categories;
  final ValueChanged<String>? onCategorySelected;
  final double height;
  final EdgeInsetsGeometry padding;

  const CategoryChipsBar({
    super.key,
    required this.controller,
    this.categories = PlaceCategoryFilter.allCategories,
    this.onCategorySelected,
    this.height = 36.0,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final selectedId = controller.selectedCategoryId;

        return SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: padding,
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cat = categories[index];
              final isSelected = cat.id == selectedId;

              return ChoiceChip(
                key: ValueKey('category_chip_${cat.id}'),
                label: Text('${cat.emoji} ${cat.label}'),
                selected: isSelected,
                onSelected: (_) {
                  controller.setCategoryId(cat.id);
                  onCategorySelected?.call(cat.id);
                },
                selectedColor: const Color(0xFFF59E0B),
                backgroundColor: const Color(0xFF0F172A),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.black : Colors.white70,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 12.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFFF59E0B)
                      : Colors.white12,
                ),
                showCheckmark: false,
              );
            },
          ),
        );
      },
    );
  }
}
