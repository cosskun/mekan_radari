import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekan_radari/controllers/places_controller.dart';
import 'package:mekan_radari/widgets/radius_slider_bar.dart';
import '../fakes/fake_places_repository.dart';
import '../fakes/fake_storage_repository.dart';

void main() {
  group('RadiusSliderBar Widget Tests', () {
    test('formatRadius formats meters and kilometers accurately', () {
      expect(RadiusSliderBar.formatRadius(50.0), '50 m');
      expect(RadiusSliderBar.formatRadius(500.0), '500 m');
      expect(RadiusSliderBar.formatRadius(999.0), '999 m');
      expect(RadiusSliderBar.formatRadius(1000.0), '1.0 km');
      expect(RadiusSliderBar.formatRadius(2500.0), '2.5 km');
    });

    test('formatPresetLabel creates compact chip labels', () {
      expect(RadiusSliderBar.formatPresetLabel(50.0), '50m');
      expect(RadiusSliderBar.formatPresetLabel(500.0), '500m');
      expect(RadiusSliderBar.formatPresetLabel(1000.0), '1km');
      expect(RadiusSliderBar.formatPresetLabel(2500.0), '2.5km');
    });

    testWidgets('renders radius label and all preset buttons', (tester) async {
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
        initialRadiusMeters: 500.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RadiusSliderBar(controller: controller),
          ),
        ),
      );

      expect(find.byKey(const Key('radius_display_label')), findsOneWidget);
      expect(find.text('500 m'), findsOneWidget);

      for (final p in [50, 100, 250, 500, 1000, 2500]) {
        expect(find.byKey(ValueKey('radius_preset_$p')), findsOneWidget);
      }
    });

    testWidgets('tapping preset updates controller and invokes callback', (tester) async {
      double? tappedPreset;
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
        initialRadiusMeters: 500.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RadiusSliderBar(
              controller: controller,
              onRadiusPresetTapped: (val) => tappedPreset = val,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('radius_preset_1000')));
      await tester.pumpAndSettle();

      expect(controller.radiusMeters, 1000.0);
      expect(tappedPreset, 1000.0);
      expect(find.text('1.0 km'), findsOneWidget);
    });

    testWidgets('preset > 1200m triggers loadPlaces', (tester) async {
      var fetchCount = 0;
      final fakeRepo = FakePlacesRepository();
      final controller = PlacesController(
        placesRepository: fakeRepo,
        storageRepository: FakeStorageRepository(),
        initialRadiusMeters: 500.0,
      );
      controller.addListener(() {
        if (controller.isLoading) fetchCount++;
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RadiusSliderBar(controller: controller),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('radius_preset_2500')));
      await tester.pumpAndSettle();

      expect(controller.radiusMeters, 2500.0);
      expect(fetchCount, greaterThanOrEqualTo(1));
    });
  });
}
