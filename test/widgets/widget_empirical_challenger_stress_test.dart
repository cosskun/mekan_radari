import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekan_radari/controllers/places_controller.dart';
import 'package:mekan_radari/models/place_model.dart';
import 'package:mekan_radari/screens/home_screen.dart';
import 'package:mekan_radari/widgets/api_settings_dialog.dart';
import 'package:mekan_radari/widgets/empty_venues_view.dart';
import 'package:mekan_radari/widgets/location_picker_sheet.dart';
import 'package:mekan_radari/widgets/venue_card.dart';

import '../fakes/fake_places_repository.dart';
import '../fakes/fake_storage_repository.dart';

Place _createStressVenue({
  required String id,
  required String name,
  double distanceMeters = 300.0,
  double rating = 4.8,
  int reviewCount = 120,
  String category = 'Tatlı & Pastane',
  String subCategory = 'Pastane',
}) {
  return Place(
    id: id,
    name: name,
    category: category,
    subCategory: subCategory,
    rating: rating,
    reviewCount: reviewCount,
    latitude: 40.9862 + (distanceMeters / 111000.0),
    longitude: 29.0264,
    distanceMeters: distanceMeters,
    address: 'Moda Cad. No:1, Kadıköy',
    openingHours: '09:00 - 23:00',
    isOpenNow: true,
    priceLevel: 2,
    tags: const ['tatlı'],
    popularItems: const ['Baklava'],
    reviews: const [],
    starDistribution: const {5: 100, 4: 20},
    dataSource: 'overpass',
  );
}

void main() {
  group('Empirical Challenger UI: View Mode Hammering & List Drag', () {
    testWidgets('Rapidly toggling between Map and List view 20 times', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final venues = List.generate(
        15,
        (i) => _createStressVenue(
          id: 'v_$i',
          name: 'Mekan #$i',
          distanceMeters: 100.0 + (i * 30),
        ),
      );

      final controller = PlacesController(
        placesRepository: FakePlacesRepository(placesToReturn: venues),
        storageRepository: FakeStorageRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VenueCard), findsWidgets);

      final toggleFinder = find.byKey(const Key('map_list_toggle_button'));
      expect(toggleFinder, findsOneWidget);

      for (int i = 0; i < 20; i++) {
        await tester.tap(toggleFinder);
        await tester.pump(const Duration(milliseconds: 10));
      }
      await tester.pumpAndSettle();

      // 20 toggles returns back to initial List mode
      expect(controller.isMapView, isFalse);
      expect(find.byType(VenueCard), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('Empirical Challenger UI: Adaptive Expansion Oscillation', () {
    testWidgets('Oscillating between empty state, adaptive expansion, and preset reset', (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Venue at ~610m outside 500m initial radius
      final venue = _createStressVenue(
        id: 'far_v',
        name: 'Uzak Baklavacı',
        distanceMeters: 610.0,
      );

      final fakeRepo = FakePlacesRepository(
        placesToReturn: [venue],
        distanceCalculator: (lat1, lon1, lat2, lon2) => 610.0,
      );

      final controller = PlacesController(
        placesRepository: fakeRepo,
        storageRepository: FakeStorageRepository(),
        initialRadiusMeters: 500.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      for (int cycle = 0; cycle < 5; cycle++) {
        // Initial state of cycle: radius 500m -> Empty view with adaptive button
        controller.setRadiusMeters(500.0);
        await tester.pumpAndSettle();

        expect(find.byType(EmptyVenuesView), findsOneWidget);
        expect(find.textContaining('Yap ve Göster'), findsOneWidget);

        // Tap expansion button
        await tester.tap(find.textContaining('Yap ve Göster'));
        await tester.pumpAndSettle();

        // Should expand to 660m (610 + 50) and show VenueCard
        expect(controller.radiusMeters, equals(660.0));
        expect(find.byType(VenueCard), findsOneWidget);
      }

      expect(tester.takeException(), isNull);
    });
  });

  group('Empirical Challenger UI: Dialogs & Sheets High-Frequency Invariant', () {
    testWidgets('LocationPickerSheet rapid search, clear, preset tap, and close', (tester) async {
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
                child: const Text('Open Picker'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (int i = 0; i < 3; i++) {
        await tester.tap(find.text('Open Picker'));
        await tester.pumpAndSettle();

        expect(find.byType(LocationPickerSheet), findsOneWidget);

        final searchField = find.byType(TextField);
        await tester.enterText(searchField, 'Kadıköy $i');
        await tester.pump(const Duration(milliseconds: 20));

        // Tap Beşiktaş preset
        final besiktasPreset = find.text('Beşiktaş Sahil & Çarşı');
        if (besiktasPreset.evaluate().isNotEmpty) {
          await tester.tap(besiktasPreset);
          await tester.pumpAndSettle();
        } else {
          await tester.tap(find.byIcon(Icons.close));
          await tester.pumpAndSettle();
        }

        expect(find.byType(LocationPickerSheet), findsNothing);
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets('ApiSettingsDialog rapid open and cancel cycles', (tester) async {
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
      await tester.pumpAndSettle();

      for (int i = 0; i < 4; i++) {
        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        expect(find.byType(ApiSettingsDialog), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'AIzaSy_TEST_KEY_$i');
        await tester.tap(find.text('İptal'));
        await tester.pumpAndSettle();

        expect(find.byType(ApiSettingsDialog), findsNothing);
      }

      expect(tester.takeException(), isNull);
    });
  });
}
