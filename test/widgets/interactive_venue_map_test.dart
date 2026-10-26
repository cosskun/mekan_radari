import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekan_radari/controllers/places_controller.dart';
import 'package:mekan_radari/models/place_model.dart';
import 'package:mekan_radari/widgets/interactive_venue_map.dart';
import '../fakes/fake_places_repository.dart';
import '../fakes/fake_storage_repository.dart';

Place _createMapPlace() {
  return const Place(
    id: 'map-p1',
    name: 'Nostalji Kafe',
    category: 'Tatlı & Pastane',
    subCategory: 'Kafe',
    rating: 4.9,
    reviewCount: 95,
    latitude: 40.9870,
    longitude: 29.0270,
    distanceMeters: 120.0,
    address: 'Moda',
    openingHours: '10:00 - 22:00',
    isOpenNow: true,
    priceLevel: 1,
    tags: ['tatlı'],
    popularItems: ['Sütlaç'],
    reviews: [],
    starDistribution: {},
    dataSource: 'overpass',
  );
}

void main() {
  group('InteractiveVenueMap Widget Tests', () {
    testWidgets('renders map layers, center marker, and bottom tip', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final place = _createMapPlace();
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(placesToReturn: [place]),
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

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byIcon(Icons.person_pin_circle_rounded), findsOneWidget);
      expect(find.text('Nostalji Kafe'), findsOneWidget);
      expect(find.text('4.9'), findsOneWidget);
      expect(find.byIcon(Icons.touch_app_rounded), findsOneWidget);
      expect(find.textContaining('İpucu: Haritada istediğiniz sokağa basılı tutarak'), findsOneWidget);
    });

    testWidgets('zoomForRadius calculates correct zoom levels across radii', (tester) async {
      expect(InteractiveVenueMap.zoomForRadius(50.0), 18.0);
      expect(InteractiveVenueMap.zoomForRadius(100.0), 17.2);
      expect(InteractiveVenueMap.zoomForRadius(250.0), 16.3);
      expect(InteractiveVenueMap.zoomForRadius(500.0), 15.4);
      expect(InteractiveVenueMap.zoomForRadius(1200.0), 14.4);
      expect(InteractiveVenueMap.zoomForRadius(2500.0), 13.3);
    });

    testWidgets('tapping venue marker invokes onPlaceTap callback', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      Place? tappedPlace;
      final place = _createMapPlace();
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(placesToReturn: [place]),
        storageRepository: FakeStorageRepository(),
      );
      await controller.init();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveVenueMap(
              controller: controller,
              tileUrlTemplate: '',
              onPlaceTap: (p) => tappedPlace = p,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Nostalji Kafe'));
      expect(tappedPlace?.id, 'map-p1');
    });
  });
}
