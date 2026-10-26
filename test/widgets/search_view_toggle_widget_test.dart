import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekan_radari/controllers/places_controller.dart';
import 'package:mekan_radari/widgets/search_view_toggle_bar.dart';
import '../fakes/fake_places_repository.dart';
import '../fakes/fake_storage_repository.dart';

void main() {
  group('SearchViewToggleBar Widget Tests', () {
    testWidgets('renders search field and toggle button', (tester) async {
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchViewToggleBar(controller: controller),
          ),
        ),
      );

      expect(find.byKey(const Key('search_text_field')), findsOneWidget);
      expect(find.byKey(const Key('map_list_toggle_button')), findsOneWidget);
      expect(find.text('Harita'), findsOneWidget);
    });

    testWidgets('entering text updates controller and shows clear button', (tester) async {
      String? changedText;
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchViewToggleBar(
              controller: controller,
              onSearchChanged: (val) => changedText = val,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('search_clear_button')), findsNothing);

      await tester.enterText(find.byKey(const Key('search_text_field')), 'Baklava');
      await tester.pumpAndSettle();

      expect(controller.searchQuery, 'Baklava');
      expect(changedText, 'Baklava');
      expect(find.byKey(const Key('search_clear_button')), findsOneWidget);

      // Press clear button
      await tester.tap(find.byKey(const Key('search_clear_button')));
      await tester.pumpAndSettle();

      expect(controller.searchQuery, '');
      expect(find.byKey(const Key('search_clear_button')), findsNothing);
    });

    testWidgets('tapping toggle button toggles view mode', (tester) async {
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchViewToggleBar(controller: controller),
          ),
        ),
      );

      expect(controller.isMapView, isFalse);
      expect(find.text('Harita'), findsOneWidget);

      await tester.tap(find.byKey(const Key('map_list_toggle_button')));
      await tester.pumpAndSettle();

      expect(controller.isMapView, isTrue);
      expect(find.text('Liste'), findsOneWidget);
    });
  });
}
