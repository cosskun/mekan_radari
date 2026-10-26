import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekan_radari/controllers/places_controller.dart';
import 'package:mekan_radari/main.dart';
import 'package:mekan_radari/screens/home_screen.dart';
import 'package:mekan_radari/widgets/category_chips_bar.dart';
import 'package:mekan_radari/widgets/filter_and_sort_bar.dart';
import 'package:mekan_radari/widgets/home_app_bar.dart';
import 'package:mekan_radari/widgets/radius_slider_bar.dart';
import 'package:mekan_radari/widgets/results_summary_strip.dart';
import 'package:mekan_radari/widgets/search_view_toggle_bar.dart';
import 'fakes/fake_places_repository.dart';
import 'fakes/fake_storage_repository.dart';

void main() {
  group('Mekan Radari App & HomeScreen Smoke Tests', () {
    testWidgets('Mekan Radari app smoke test', (WidgetTester tester) async {
      await tester.pumpWidget(const MekanRadariApp());
      expect(find.textContaining('Mekan Radarı'), findsOneWidget);
    });

    testWidgets('HomeScreen smoke test mounts all core coordinator sub-widgets', (tester) async {
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HomeAppBar), findsOneWidget);
      expect(find.byType(SearchViewToggleBar), findsOneWidget);
      expect(find.byType(CategoryChipsBar), findsOneWidget);
      expect(find.byType(RadiusSliderBar), findsOneWidget);
      expect(find.byType(FilterAndSortBar), findsOneWidget);
      expect(find.byType(ResultsSummaryStrip), findsOneWidget);
    });
  });
}
