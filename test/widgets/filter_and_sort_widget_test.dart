import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekan_radari/controllers/places_controller.dart';
import 'package:mekan_radari/widgets/filter_and_sort_bar.dart';
import '../fakes/fake_places_repository.dart';
import '../fakes/fake_storage_repository.dart';

void main() {
  group('FilterAndSortBar Widget Tests', () {
    testWidgets('renders rating chips and handles tap', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      double? selectedRating;
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
        initialMinRating: 4.5,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterAndSortBar(
              controller: controller,
              onRatingSelected: (val) => selectedRating = val,
            ),
          ),
        ),
      );

      expect(find.text('Min. Puan:'), findsOneWidget);
      expect(find.byKey(const ValueKey('rating_chip_0.0')), findsOneWidget);
      expect(find.byKey(const ValueKey('rating_chip_4.0')), findsOneWidget);
      expect(find.byKey(const ValueKey('rating_chip_4.3')), findsOneWidget);
      expect(find.byKey(const ValueKey('rating_chip_4.5')), findsOneWidget);
      expect(find.byKey(const ValueKey('rating_chip_4.7')), findsOneWidget);

      // Tap 4.7+ ★
      await tester.tap(find.byKey(const ValueKey('rating_chip_4.7')));
      await tester.pumpAndSettle();

      expect(controller.minRating, 4.7);
      expect(selectedRating, 4.7);
    });

    testWidgets('review count popup updates controller minReviewCount', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      int? selectedCount;
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterAndSortBar(
              controller: controller,
              onReviewCountSelected: (val) => selectedCount = val,
            ),
          ),
        ),
      );

      // Open review count popup
      await tester.tap(find.byKey(const Key('review_count_popup_button')));
      await tester.pumpAndSettle();

      // Select '100+'
      await tester.tap(find.byKey(const ValueKey('review_count_item_100')));
      await tester.pumpAndSettle();

      expect(controller.minReviewCount, 100);
      expect(selectedCount, 100);
      expect(find.text('100+ Yorum'), findsOneWidget);
    });

    testWidgets('sort option popup updates controller sortOption', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SortOption? selectedSort;
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
        initialSortOption: SortOption.distance,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterAndSortBar(
              controller: controller,
              onSortSelected: (val) => selectedSort = val,
            ),
          ),
        ),
      );

      expect(find.text('En Yakın'), findsOneWidget);

      // Open sort popup
      await tester.tap(find.byKey(const Key('sort_option_popup_button')));
      await tester.pumpAndSettle();

      // Select 'En Yüksek Puan'
      await tester.tap(find.byKey(const Key('sort_item_rating')));
      await tester.pumpAndSettle();

      expect(controller.sortOption, SortOption.rating);
      expect(selectedSort, SortOption.rating);
      expect(find.text('En Yüksek Puan'), findsOneWidget);
    });
  });
}
