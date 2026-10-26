import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekan_radari/controllers/places_controller.dart';
import 'package:mekan_radari/models/place_model.dart';
import 'package:mekan_radari/screens/home_screen.dart';
import 'package:mekan_radari/screens/place_detail_sheet.dart';
import 'package:mekan_radari/widgets/empty_venues_view.dart';
import 'package:mekan_radari/widgets/interactive_venue_map.dart';
import 'package:mekan_radari/widgets/venue_card.dart';
import '../fakes/fake_places_repository.dart';
import '../fakes/fake_storage_repository.dart';

Place _createHomePlace() {
  return const Place(
    id: 'h-1',
    name: 'Kadıköy Waffle Evi',
    category: 'Tatlı & Pastane',
    subCategory: 'Waffle',
    rating: 4.8,
    reviewCount: 210,
    latitude: 40.9865,
    longitude: 29.0268,
    distanceMeters: 180.0,
    address: 'Kadıköy',
    openingHours: '10:00 - 00:00',
    isOpenNow: true,
    priceLevel: 2,
    tags: ['waffle', 'tatlı'],
    popularItems: ['Meyveli Waffle'],
    reviews: [],
    starDistribution: {},
    dataSource: 'overpass',
  );
}

void main() {
  group('HomeScreen Coordinator Widget Tests', () {
    testWidgets('renders VenueCard list when places exist in list mode', (tester) async {
      final place = _createHomePlace();
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(placesToReturn: [place]),
        storageRepository: FakeStorageRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VenueCard), findsOneWidget);
      expect(find.text('Kadıköy Waffle Evi'), findsOneWidget);
    });

    testWidgets('renders EmptyVenuesView when 0 venues match filters', (tester) async {
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(placesToReturn: const []),
        storageRepository: FakeStorageRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EmptyVenuesView), findsOneWidget);
    });

    testWidgets('switches to InteractiveVenueMap when view mode is toggled', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final place = _createHomePlace();
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(placesToReturn: [place]),
        storageRepository: FakeStorageRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      controller.toggleViewMode();
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveVenueMap), findsOneWidget);
    });

    testWidgets('tapping a venue card opens PlaceDetailSheet bottom sheet', (tester) async {
      final place = _createHomePlace();
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(placesToReturn: [place]),
        storageRepository: FakeStorageRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kadıköy Waffle Evi'));
      await tester.pumpAndSettle();

      expect(find.byType(PlaceDetailSheet), findsOneWidget);
    });
  });
}
