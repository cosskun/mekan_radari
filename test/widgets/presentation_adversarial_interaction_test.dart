import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mekan_radari/controllers/places_controller.dart';
import 'package:mekan_radari/models/location_preset.dart';
import 'package:mekan_radari/models/place_model.dart';
import 'package:mekan_radari/screens/home_screen.dart';
import 'package:mekan_radari/widgets/api_settings_dialog.dart';
import 'package:mekan_radari/widgets/category_chips_bar.dart';
import 'package:mekan_radari/widgets/empty_venues_view.dart';
import 'package:mekan_radari/widgets/filter_and_sort_bar.dart';
import 'package:mekan_radari/widgets/interactive_venue_map.dart';
import 'package:mekan_radari/widgets/location_picker_sheet.dart';
import 'package:mekan_radari/widgets/radius_slider_bar.dart';
import 'package:mekan_radari/widgets/venue_card.dart';
import '../fakes/fake_places_repository.dart';
import '../fakes/fake_storage_repository.dart';

Place _createAdversarialPlace({
  required String id,
  required String name,
  required String category,
  required String subCategory,
  required double rating,
  required int reviewCount,
  required double distanceMeters,
  List<String> tags = const ['tatlı'],
  List<String> popularItems = const ['Baklava'],
}) {
  return Place(
    id: id,
    name: name,
    category: category,
    subCategory: subCategory,
    rating: rating,
    reviewCount: reviewCount,
    latitude: 40.9860 + (distanceMeters / 111000.0),
    longitude: 29.0260,
    distanceMeters: distanceMeters,
    address: 'Kadıköy, İstanbul',
    openingHours: '09:00 - 23:00',
    isOpenNow: true,
    priceLevel: 2,
    tags: tags,
    popularItems: popularItems,
    reviews: const [],
    starDistribution: const {},
    dataSource: 'overpass',
  );
}

void main() {
  group('1. Adversarial Category Chip Toggling Tests', () {
    testWidgets('Rapid multi-tap interleaved category toggling without settle',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
        initialCategoryId: 'all',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryChipsBar(controller: controller),
          ),
        ),
      );

      final chipKeys = [
        'category_chip_dessert',
        'category_chip_coffee',
        'category_chip_restaurant',
        'category_chip_fast_food',
        'category_chip_bakery',
        'category_chip_all',
      ];

      // Perform 30 rapid successive taps across valid categories with micro-pumps
      for (var i = 0; i < 30; i++) {
        final targetKey = chipKeys[i % chipKeys.length];
        await tester.tap(find.byKey(ValueKey(targetKey)));
        await tester.pump(const Duration(milliseconds: 10));
      }

      await tester.pumpAndSettle();

      // 29 % 6 = 5 -> 'category_chip_all'
      expect(controller.selectedCategoryId, 'all');

      final allChip = tester.widget<ChoiceChip>(
        find.byKey(const ValueKey('category_chip_all')),
      );
      expect(allChip.selected, isTrue);

      final coffeeChip = tester.widget<ChoiceChip>(
        find.byKey(const ValueKey('category_chip_coffee')),
      );
      expect(coffeeChip.selected, isFalse);
    });

    testWidgets('Rapid burst tapping on the same selected chip remains idempotent',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      var callbackCount = 0;
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
        initialCategoryId: 'coffee',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryChipsBar(
              controller: controller,
              onCategorySelected: (_) => callbackCount++,
            ),
          ),
        ),
      );

      // Spam the already-selected 'coffee' chip 12 times consecutively
      for (var i = 0; i < 12; i++) {
        await tester.tap(find.byKey(const ValueKey('category_chip_coffee')));
        await tester.pump(const Duration(milliseconds: 5));
      }

      await tester.pumpAndSettle();

      expect(controller.selectedCategoryId, 'coffee');
      expect(callbackCount, 12);

      final coffeeChip = tester.widget<ChoiceChip>(
        find.byKey(const ValueKey('category_chip_coffee')),
      );
      expect(coffeeChip.selected, isTrue);
    });

    testWidgets('Rapid category toggling updates filtered venues in HomeScreen without crash',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final pDessert = _createAdversarialPlace(
        id: 'p-dessert',
        name: 'Hafız Mustafa Tatlıları',
        category: 'Tatlı & Pastane',
        subCategory: 'Tatlıcı',
        rating: 4.9,
        reviewCount: 300,
        distanceMeters: 100.0,
      );
      final pCoffee = _createAdversarialPlace(
        id: 'p-coffee',
        name: 'Federal Kahve Evi',
        category: 'Kahve & Çay',
        subCategory: 'Kafe',
        rating: 4.8,
        reviewCount: 220,
        distanceMeters: 150.0,
        tags: ['kahve', 'espresso'],
        popularItems: ['Cold Brew'],
      );

      final controller = PlacesController(
        placesRepository: FakePlacesRepository(
          placesToReturn: [pDessert, pCoffee],
        ),
        storageRepository: FakeStorageRepository(),
        initialCategoryId: 'all',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VenueCard), findsNWidgets(2));

      // Rapidly toggle to 'coffee'
      await tester.tap(find.byKey(const ValueKey('category_chip_coffee')));
      await tester.pumpAndSettle();

      expect(find.text('Federal Kahve Evi'), findsOneWidget);
      expect(find.text('Hafız Mustafa Tatlıları'), findsNothing);

      // Rapidly toggle to 'dessert'
      await tester.tap(find.byKey(const ValueKey('category_chip_dessert')));
      await tester.pumpAndSettle();

      expect(find.text('Hafız Mustafa Tatlıları'), findsOneWidget);
      expect(find.text('Federal Kahve Evi'), findsNothing);
    });
  });

  group('2. Adversarial Slider Dragging & Exact Boundary Values', () {
    testWidgets('Slider dragging to exact minimum boundary (50m) and maximum boundary (3000m)',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
        initialRadiusMeters: 500.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: RadiusSliderBar(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sliderFinder = find.byKey(const Key('radius_slider'));
      expect(sliderFinder, findsOneWidget);

      // Drag aggressively to far left (-2000px)
      await tester.drag(sliderFinder, const Offset(-2000, 0));
      await tester.pumpAndSettle();

      expect(controller.radiusMeters, 50.0);
      expect(find.text('50 m'), findsOneWidget);

      // Drag aggressively to far right (+2000px)
      await tester.drag(sliderFinder, const Offset(2000, 0));
      await tester.pumpAndSettle();

      expect(controller.radiusMeters, 3000.0);
      expect(find.text('3.0 km'), findsOneWidget);
    });

    testWidgets('High-frequency chaotic drag gestures do not throw exceptions',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
        initialRadiusMeters: 1000.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: RadiusSliderBar(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sliderFinder = find.byKey(const Key('radius_slider'));

      // Perform rapid drags across X axis
      await tester.drag(sliderFinder, const Offset(-300, 0));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.drag(sliderFinder, const Offset(500, 0));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.drag(sliderFinder, const Offset(-700, 0));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.drag(sliderFinder, const Offset(400, 0));
      await tester.pumpAndSettle();

      expect(controller.radiusMeters, greaterThanOrEqualTo(50.0));
      expect(controller.radiusMeters, lessThanOrEqualTo(3000.0));
    });

    testWidgets('Clamping immunity when out-of-range radius is injected into controller',
        (tester) async {
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
        initialRadiusMeters: -999.0, // Invalid negative radius
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RadiusSliderBar(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // RadiusSliderBar safely clamps controller.radiusMeters.clamp(50.0, 3000.0)
      expect(find.byKey(const Key('radius_slider')), findsOneWidget);
      expect(find.text('50 m'), findsOneWidget);

      // Inject upper out-of-range value
      controller.setRadiusMeters(88888.0);
      await tester.pumpAndSettle();

      expect(find.text('3.0 km'), findsOneWidget);
    });

    testWidgets('Preset boundary buttons (50m and 2500m) with auto-fetch check',
        (tester) async {
      var fetchCallCount = 0;
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
        initialRadiusMeters: 500.0,
      );
      controller.addListener(() {
        if (controller.isLoading) fetchCallCount++;
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RadiusSliderBar(controller: controller),
          ),
        ),
      );

      // Tap 50m preset
      await tester.tap(find.byKey(const ValueKey('radius_preset_50')));
      await tester.pumpAndSettle();
      expect(controller.radiusMeters, 50.0);
      expect(fetchCallCount, 0); // <= 1200 does not auto-fetch

      // Tap 2500m preset
      await tester.tap(find.byKey(const ValueKey('radius_preset_2500')));
      await tester.pumpAndSettle();
      expect(controller.radiusMeters, 2500.0);
      expect(fetchCallCount, greaterThanOrEqualTo(1)); // > 1200 triggers auto-fetch
    });
  });

  group('3. Adversarial Rating Chips & Sort Option Sequences', () {
    testWidgets('Rapid cycling through all rating chip presets', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
        initialMinRating: 0.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterAndSortBar(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ratings = [4.7, 4.0, 4.5, 4.3, 0.0, 4.7];
      for (final r in ratings) {
        await tester.tap(find.byKey(ValueKey('rating_chip_${r.toStringAsFixed(1)}')));
        await tester.pump(const Duration(milliseconds: 10));
      }
      await tester.pumpAndSettle();

      expect(controller.minRating, 4.7);

      // Spam the same 4.7 chip rapidly 8 times
      for (var i = 0; i < 8; i++) {
        await tester.tap(find.byKey(const ValueKey('rating_chip_4.7')));
        await tester.pump(const Duration(milliseconds: 10));
      }
      await tester.pumpAndSettle();

      expect(controller.minRating, 4.7);
    });

    testWidgets('Combinatorial sequence of rating, review count, and sort changes',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterAndSortBar(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1: Rating 4.3+
      await tester.tap(find.byKey(const ValueKey('rating_chip_4.3')));
      await tester.pumpAndSettle();
      expect(controller.minRating, 4.3);

      // Step 2: Review Count 200+
      await tester.tap(find.byKey(const Key('review_count_popup_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('review_count_item_200')));
      await tester.pumpAndSettle();
      expect(controller.minReviewCount, 200);

      // Step 3: Sort by rating
      await tester.tap(find.byKey(const Key('sort_option_popup_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sort_item_rating')));
      await tester.pumpAndSettle();
      expect(controller.sortOption, SortOption.rating);

      // Step 4: Rapidly switch sort to reviews and rating to 4.7
      await tester.tap(find.byKey(const Key('sort_option_popup_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sort_item_reviews')));
      await tester.pumpAndSettle();
      expect(controller.sortOption, SortOption.reviews);

      await tester.tap(find.byKey(const ValueKey('rating_chip_4.7')));
      await tester.pumpAndSettle();
      expect(controller.minRating, 4.7);
    });

    testWidgets('Popup menus dismiss gracefully without state alteration when clicking outside',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
        initialMinReviewCount: 50,
        initialSortOption: SortOption.distance,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterAndSortBar(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open review count popup
      await tester.tap(find.byKey(const Key('review_count_popup_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('review_count_item_100')), findsOneWidget);

      // Dismiss popup by tapping top-left corner
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(controller.minReviewCount, 50);

      // Open sort option popup
      await tester.tap(find.byKey(const Key('sort_option_popup_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sort_item_rating')), findsOneWidget);

      // Dismiss popup by tapping top-left corner
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(controller.sortOption, SortOption.distance);
    });
  });

  group('4. Adversarial Long-Press Map Relocation & Coordinate Updates', () {
    testWidgets('Long-press gesture on InteractiveVenueMap relocates search center',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
        initialLat: 40.9862,
        initialLon: 29.0264,
        initialRadiusMeters: 500.0,
      );
      await controller.init();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveVenueMap(
              controller: controller,
              tileUrlTemplate: '',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Execute long press on center of screen
      final centerPoint = tester.getCenter(find.byType(InteractiveVenueMap));
      await tester.longPressAt(centerPoint);
      await tester.pumpAndSettle();

      expect(controller.locationLabel, contains('Haritadan Seçilen Nokta'));
    });

    testWidgets('Multiple rapid long-press gestures across map coordinates',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
        initialLat: 40.9862,
        initialLon: 29.0264,
      );
      await controller.init();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveVenueMap(
              controller: controller,
              tileUrlTemplate: '',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger long-press gestures across 3 distinct points
      final points = [
        const Offset(200, 300),
        const Offset(400, 600),
        const Offset(300, 450),
      ];

      for (final pt in points) {
        await tester.longPressAt(pt);
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();

      expect(controller.locationLabel, contains('Haritadan Seçilen Nokta'));
      expect(controller.centerLat, isNot(40.9862));
    });

    testWidgets('Custom onMapLongPress callback intercepts gesture cleanly',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      LatLng? interceptedCoord;
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
        initialLat: 40.9862,
        initialLon: 29.0264,
      );
      await controller.init();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveVenueMap(
              controller: controller,
              tileUrlTemplate: '',
              onMapLongPress: (coord) {
                interceptedCoord = coord;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPressAt(const Offset(350, 400));
      await tester.pumpAndSettle();

      expect(interceptedCoord, isNotNull);
      // Controller location was NOT overwritten by default label
      expect(controller.locationLabel, isNot(contains('Haritadan Seçilen Nokta')));
    });

    testWidgets('Map gracefully responds to rapid external coordinate updates',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
      );
      await controller.init();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveVenueMap(
              controller: controller,
              tileUrlTemplate: '',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Externally update coordinates 5 times rapidly
      for (var i = 1; i <= 5; i++) {
        await controller.setLocation(
          lat: 41.0 + (i * 0.01),
          lon: 29.0 + (i * 0.01),
          label: 'Relocation $i',
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();

      expect(controller.centerLat, closeTo(41.05, 0.001));
      expect(controller.centerLon, closeTo(29.05, 0.001));
    });
  });

  group('5. Adversarial Dialog Dismissals & Invalid Input Tests', () {
    testWidgets('ApiSettingsDialog trims whitespace and stores null on empty/whitespace input',
        (tester) async {
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => ApiSettingsDialog.show(
                  context: ctx,
                  controller: controller,
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Enter only spaces
      await tester.enterText(find.byType(TextField), '     ');
      await tester.tap(find.text('Kaydet & Yenile'));
      await tester.pumpAndSettle();

      // Verify whitespace is converted to null
      expect(controller.googleApiKey, isNull);
    });

    testWidgets('ApiSettingsDialog cancel button dismisses dialog without altering key',
        (tester) async {
      final fakeStorage = FakeStorageRepository();
      await fakeStorage.saveGoogleApiKey('KEY_PRESERVED_123');

      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: fakeStorage,
      );
      await controller.init();
      expect(controller.googleApiKey, 'KEY_PRESERVED_123');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => ApiSettingsDialog.show(
                  context: ctx,
                  controller: controller,
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Enter adversarial text then click Cancel
      await tester.enterText(find.byType(TextField), 'MALICIOUS_OVERWRITE_KEY');
      await tester.tap(find.text('İptal'));
      await tester.pumpAndSettle();

      // Dialog dismissed, key unaltered
      expect(find.byType(ApiSettingsDialog), findsNothing);
      expect(controller.googleApiKey, 'KEY_PRESERVED_123');
    });

    testWidgets('ApiSettingsDialog dismisses upon tapping modal barrier',
        (tester) async {
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => ApiSettingsDialog.show(
                  context: ctx,
                  controller: controller,
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();
      expect(find.byType(ApiSettingsDialog), findsOneWidget);

      // Tap outside dialog bounds (barrier)
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(find.byType(ApiSettingsDialog), findsNothing);
    });

    testWidgets('LocationPickerSheet dismisses via close icon button and barrier tap',
        (tester) async {
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => LocationPickerSheet.show(
                  context: ctx,
                  controller: controller,
                ),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      // 1. Open and dismiss with close button
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();
      expect(find.byType(LocationPickerSheet), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byType(LocationPickerSheet), findsNothing);

      // 2. Open and dismiss with barrier tap
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();
      expect(find.byType(LocationPickerSheet), findsOneWidget);

      await tester.tapAt(const Offset(200, 30));
      await tester.pumpAndSettle();
      expect(find.byType(LocationPickerSheet), findsNothing);
    });

    testWidgets('LocationPickerSheet handles address search results and clear button',
        (tester) async {
      const resultPreset = LocationPreset(
        name: 'Kadıköy Çarşı',
        subtitle: 'İstanbul',
        latitude: 40.9890,
        longitude: 29.0280,
      );

      final controller = PlacesController(
        placesRepository: FakePlacesRepository(presetsToReturn: [resultPreset]),
        storageRepository: FakeStorageRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationPickerSheet(controller: controller),
          ),
        ),
      );

      final searchFieldFinder = find.byType(TextField);

      // Single character input (< 2 characters) does not trigger search
      await tester.enterText(searchFieldFinder, 'X');
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Arama Sonuçları (Canlı Harita)'), findsNothing);

      // Valid search query with live results
      await tester.enterText(searchFieldFinder, 'Kadıköy');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.text('Arama Sonuçları (Canlı Harita)'), findsOneWidget);
      expect(find.text('Kadıköy Çarşı'), findsOneWidget);

      // Clear button should be visible now that search results returned
      final clearBtnFinder = find.byIcon(Icons.clear_rounded);
      expect(clearBtnFinder, findsOneWidget);

      await tester.tap(clearBtnFinder);
      await tester.pumpAndSettle();

      expect(find.text('Arama Sonuçları (Canlı Harita)'), findsNothing);
    });
  });

  group('6. Adversarial Empty State & Adaptive Radius Triggering', () {
    testWidgets('EmptyVenuesView fallback button rapid clicks idempotently reset filters',
        (tester) async {
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
        initialRadiusMeters: 200.0,
        initialMinRating: 4.7,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyVenuesView(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final resetBtnFinder = find.text('1 km & 4.0+ Yıldız Olarak Göster');
      expect(resetBtnFinder, findsOneWidget);

      // Rapid spam tap 6 times
      for (var i = 0; i < 6; i++) {
        await tester.tap(resetBtnFinder);
        await tester.pump(const Duration(milliseconds: 10));
      }
      await tester.pumpAndSettle();

      expect(controller.radiusMeters, 1000.0);
      expect(controller.minRating, 4.0);
    });

    testWidgets('Adaptive radius button encompasses closest venue outside radius',
        (tester) async {
      final outsidePlace = _createAdversarialPlace(
        id: 'out-1',
        name: 'Göztepe Pastanesi',
        category: 'Tatlı & Pastane',
        subCategory: 'Pastane',
        rating: 4.8,
        reviewCount: 180,
        distanceMeters: 720.0,
      );

      final controller = PlacesController(
        placesRepository: FakePlacesRepository(
          placesToReturn: [outsidePlace],
          distanceCalculator: (_, _, _, _) => 720.0,
        ),
        storageRepository: FakeStorageRepository(),
        initialRadiusMeters: 500.0,
        initialMinRating: 4.5,
      );
      await controller.init();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyVenuesView(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Göztepe Pastanesi'), findsOneWidget);
      // Distance 720m + 50m = 770m
      expect(find.text('Yarıçapı 770m Yap ve Göster'), findsOneWidget);

      await tester.tap(find.text('Yarıçapı 770m Yap ve Göster'));
      await tester.pumpAndSettle();

      expect(controller.radiusMeters, 770.0);
    });

    testWidgets('Adaptive radius boundary clamping at 3000m maximum and 100m minimum',
        (tester) async {
      // Test upper clamp: venue at 3200m -> 3250m clamps to 3000.0m
      expect(PlacesController.calculateExpandedRadius(3200.0), 3000.0);

      // Test lower clamp: venue at 20m -> 70m clamps to 100.0m
      expect(PlacesController.calculateExpandedRadius(20.0), 100.0);
    });

    testWidgets('HomeScreen transitions from EmptyVenuesView to VenueCard when adaptive radius is tapped',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final outsidePlace = _createAdversarialPlace(
        id: 'out-adapt',
        name: 'Moda Çikolatacısı',
        category: 'Tatlı & Pastane',
        subCategory: 'Çikolata',
        rating: 4.9,
        reviewCount: 450,
        distanceMeters: 650.0,
      );

      final controller = PlacesController(
        placesRepository: FakePlacesRepository(
          placesToReturn: [outsidePlace],
          distanceCalculator: (_, _, _, _) => 650.0,
        ),
        storageRepository: FakeStorageRepository(),
        initialRadiusMeters: 500.0,
        initialMinRating: 4.5,
      );
      await controller.init();

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Initially outside radius (500m < 650m), so EmptyVenuesView is shown
      expect(find.byType(EmptyVenuesView), findsOneWidget);
      expect(find.byType(VenueCard), findsNothing);

      // Tap adaptive radius button: 650 + 50 = 700m
      await tester.tap(find.text('Yarıçapı 700m Yap ve Göster'));
      await tester.pumpAndSettle();

      // Now within radius (700m >= 650m), VenueCard is rendered!
      expect(find.byType(EmptyVenuesView), findsNothing);
      expect(find.byType(VenueCard), findsOneWidget);
      expect(find.text('Moda Çikolatacısı'), findsOneWidget);
    });
  });
}
