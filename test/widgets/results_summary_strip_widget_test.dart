import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekan_radari/controllers/places_controller.dart';
import 'package:mekan_radari/widgets/results_summary_strip.dart';
import '../fakes/fake_places_repository.dart';
import '../fakes/fake_storage_repository.dart';

void main() {
  group('ResultsSummaryStrip Widget Tests', () {
    testWidgets('renders filtered places count and active filter summary', (tester) async {
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
        initialRadiusMeters: 500.0,
        initialMinRating: 4.5,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResultsSummaryStrip(controller: controller),
          ),
        ),
      );

      expect(find.byKey(const Key('results_count_text')), findsOneWidget);
      expect(find.text('0 mekan bulundu'), findsOneWidget);

      expect(find.byKey(const Key('active_filters_summary_text')), findsOneWidget);
      expect(find.textContaining('500 m içinde • 4.5+ ★'), findsOneWidget);

      expect(find.byKey(const Key('results_refresh_button')), findsOneWidget);
      expect(find.text('Yenile'), findsOneWidget);
    });

    testWidgets('tapping refresh invokes onRefresh callback', (tester) async {
      bool refreshed = false;
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResultsSummaryStrip(
              controller: controller,
              onRefresh: () => refreshed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('results_refresh_button')));
      await tester.pumpAndSettle();

      expect(refreshed, isTrue);
    });
  });
}
