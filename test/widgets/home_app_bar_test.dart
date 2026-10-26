import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekan_radari/controllers/places_controller.dart';
import 'package:mekan_radari/widgets/home_app_bar.dart';
import '../fakes/fake_places_repository.dart';
import '../fakes/fake_storage_repository.dart';

void main() {
  group('HomeAppBar Widget Tests', () {
    testWidgets('renders title and location label', (tester) async {
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
        initialLocationLabel: 'Kadıköy - Moda & Çarşı',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: HomeAppBar(controller: controller),
          ),
        ),
      );

      expect(find.text('Mekan Radarı • Konum Seç'), findsOneWidget);
      expect(find.text('Kadıköy - Moda & Çarşı'), findsOneWidget);
      expect(find.byIcon(Icons.radar_rounded), findsOneWidget);
    });

    testWidgets('location tap invokes onLocationTap callback', (tester) async {
      bool tapped = false;
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: HomeAppBar(
              controller: controller,
              onLocationTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mekan Radarı • Konum Seç'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('favorites toggle button updates favorites mode', (tester) async {
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: HomeAppBar(controller: controller),
          ),
        ),
      );

      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsNothing);

      await tester.tap(find.byIcon(Icons.favorite_border_rounded));
      await tester.pumpAndSettle();

      expect(controller.showFavoritesOnly, isTrue);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    });

    testWidgets('GPS and settings buttons invoke respective callbacks', (tester) async {
      bool gpsTapped = false;
      bool settingsTapped = false;

      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: HomeAppBar(
              controller: controller,
              onGpsPressed: () async => gpsTapped = true,
              onApiSettingsTap: () => settingsTapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.my_location_rounded));
      await tester.pumpAndSettle();
      expect(gpsTapped, isTrue);

      await tester.tap(find.byIcon(Icons.vpn_key_rounded));
      await tester.pumpAndSettle();
      expect(settingsTapped, isTrue);
    });
  });
}
