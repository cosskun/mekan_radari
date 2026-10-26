import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekan_radari/controllers/places_controller.dart';
import 'package:mekan_radari/models/place_model.dart';
import 'package:mekan_radari/widgets/empty_venues_view.dart';
import '../fakes/fake_places_repository.dart';
import '../fakes/fake_storage_repository.dart';

Place _createOutsidePlace() {
  return const Place(
    id: 'far-1',
    name: 'Tarihi Beyoğlu Fırını',
    category: 'Tatlı & Pastane',
    subCategory: 'Fırın',
    rating: 4.7,
    reviewCount: 340,
    latitude: 41.0100,
    longitude: 29.0300,
    distanceMeters: 850.0,
    address: 'Beyoğlu, İstanbul',
    openingHours: '08:00 - 22:00',
    isOpenNow: true,
    priceLevel: 2,
    tags: ['tatlı'],
    popularItems: ['Kruvasan'],
    reviews: [],
    starDistribution: {},
    dataSource: 'overpass',
  );
}

void main() {
  group('EmptyVenuesView Widget Tests', () {
    testWidgets('renders radar icon and empty state title for current radius and rating', (tester) async {
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
        initialRadiusMeters: 500.0,
        initialMinRating: 4.5,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyVenuesView(controller: controller),
          ),
        ),
      );

      expect(find.byIcon(Icons.radar_rounded), findsOneWidget);
      expect(
        find.text('500 m yarıçapında ve 4.5+ yıldızda mekan bulunamadı.'),
        findsOneWidget,
      );
    });

    testWidgets('renders fallback reset button when closestPlaceOutsideRadius is null', (tester) async {
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
        initialRadiusMeters: 250.0,
        initialMinRating: 4.5,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyVenuesView(controller: controller),
          ),
        ),
      );

      expect(find.text('1 km & 4.0+ Yıldız Olarak Göster'), findsOneWidget);

      await tester.tap(find.text('1 km & 4.0+ Yıldız Olarak Göster'));
      expect(controller.radiusMeters, 1000.0);
      expect(controller.minRating, 4.0);
    });

    testWidgets('renders adaptive expansion button when closest venue outside radius exists', (tester) async {
      final outsidePlace = _createOutsidePlace();
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(
          placesToReturn: [outsidePlace],
          distanceCalculator: (_, _, _, _) => 850.0,
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

      expect(
        find.textContaining('Tarihi Beyoğlu Fırını'),
        findsOneWidget,
      );
      expect(find.text('Yarıçapı 900m Yap ve Göster'), findsOneWidget);

      await tester.tap(find.text('Yarıçapı 900m Yap ve Göster'));
      expect(controller.radiusMeters, 900.0);
    });
  });
}
