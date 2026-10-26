import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekan_radari/controllers/places_controller.dart';
import 'package:mekan_radari/models/place_model.dart';
import 'package:mekan_radari/widgets/category_chips_bar.dart';
import '../fakes/fake_places_repository.dart';
import '../fakes/fake_storage_repository.dart';

void main() {
  group('CategoryChipsBar Widget Tests', () {
    testWidgets('renders all 6 categories from PlaceCategoryFilter.allCategories', (tester) async {
      tester.view.physicalSize = const Size(1400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
        initialCategoryId: 'dessert',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryChipsBar(controller: controller),
          ),
        ),
      );

      for (final cat in PlaceCategoryFilter.allCategories) {
        expect(find.byKey(ValueKey('category_chip_${cat.id}')), findsOneWidget);
        expect(find.text('${cat.emoji} ${cat.label}'), findsOneWidget);
      }
    });

    testWidgets('indicates selected category and updates on tap', (tester) async {
      String? selectedCallbackId;
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
        initialCategoryId: 'dessert',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryChipsBar(
              controller: controller,
              onCategorySelected: (id) => selectedCallbackId = id,
            ),
          ),
        ),
      );

      // Verify 'dessert' chip is selected
      final dessertChip = tester.widget<ChoiceChip>(
        find.byKey(const ValueKey('category_chip_dessert')),
      );
      expect(dessertChip.selected, isTrue);

      final coffeeChip = tester.widget<ChoiceChip>(
        find.byKey(const ValueKey('category_chip_coffee')),
      );
      expect(coffeeChip.selected, isFalse);

      // Tap 'coffee' chip
      await tester.tap(find.byKey(const ValueKey('category_chip_coffee')));
      await tester.pumpAndSettle();

      expect(controller.selectedCategoryId, 'coffee');
      expect(selectedCallbackId, 'coffee');

      // Now coffee chip should be selected
      final updatedCoffeeChip = tester.widget<ChoiceChip>(
        find.byKey(const ValueKey('category_chip_coffee')),
      );
      expect(updatedCoffeeChip.selected, isTrue);
    });
  });
}
