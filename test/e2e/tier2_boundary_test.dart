import 'package:flutter_test/flutter_test.dart';
import 'package:mekan_radari/controllers/places_controller.dart';
import 'package:mekan_radari/models/place_model.dart';

import '../fakes/fake_places_repository.dart';
import '../fakes/fake_storage_repository.dart';

Place _createBoundaryPlace({
  required String id,
  required String name,
  String category = 'Tatlı & Pastane',
  String subCategory = 'Pastane',
  double rating = 4.5,
  int reviewCount = 0,
  double latitude = 40.9862,
  double longitude = 29.0264,
  double distanceMeters = 200.0,
  int priceLevel = 1,
  List<String> popularItems = const ['Baklava'],
  List<String> tags = const ['tatlı'],
}) {
  return Place(
    id: id,
    name: name,
    category: category,
    subCategory: subCategory,
    rating: rating,
    reviewCount: reviewCount,
    latitude: latitude,
    longitude: longitude,
    distanceMeters: distanceMeters,
    address: 'Kadıköy/İstanbul',
    phone: null,
    website: null,
    openingHours: '10:00 - 22:00',
    isOpenNow: true,
    priceLevel: priceLevel,
    tags: tags,
    popularItems: popularItems,
    reviews: const [],
    starDistribution: const {5: 1.0},
    dataSource: 'overpass',
  );
}

void main() {
  group('Tier 2: Boundary Value Analysis E2E Suite', () {
    late FakePlacesRepository fakePlacesRepo;
    late FakeStorageRepository fakeStorageRepo;

    setUp(() {
      fakePlacesRepo = FakePlacesRepository();
      fakeStorageRepo = FakeStorageRepository();
    });

    group('Radius Slider Boundaries & Clamping', () {
      test('enforces exact lower bound of 50.0 meters', () {
        final controller = PlacesController(
          placesRepository: fakePlacesRepo,
          storageRepository: fakeStorageRepo,
          initialRadiusMeters: 50.0,
        );
        expect(controller.radiusMeters, equals(50.0));

        controller.setRadiusMeters(50.0);
        expect(controller.radiusMeters, equals(50.0));
      });

      test('clamps negative, zero, and sub-50m values to 50.0 meters', () {
        final controller = PlacesController(
          placesRepository: fakePlacesRepo,
          storageRepository: fakeStorageRepo,
          initialRadiusMeters: -100.0,
        );
        expect(controller.radiusMeters, equals(50.0));

        controller.setRadiusMeters(0.0);
        expect(controller.radiusMeters, equals(50.0));

        controller.setRadiusMeters(49.999);
        expect(controller.radiusMeters, equals(50.0));

        controller.setRadiusMeters(-500.0);
        expect(controller.radiusMeters, equals(50.0));
      });

      test('enforces exact upper bound of 3000.0 meters', () {
        final controller = PlacesController(
          placesRepository: fakePlacesRepo,
          storageRepository: fakeStorageRepo,
          initialRadiusMeters: 3000.0,
        );
        expect(controller.radiusMeters, equals(3000.0));

        controller.setRadiusMeters(3000.0);
        expect(controller.radiusMeters, equals(3000.0));
      });

      test('clamps excessive values above 3000m to 3000.0 meters', () {
        final controller = PlacesController(
          placesRepository: fakePlacesRepo,
          storageRepository: fakeStorageRepo,
          initialRadiusMeters: 5000.0,
        );
        expect(controller.radiusMeters, equals(3000.0));

        controller.setRadiusMeters(3000.1);
        expect(controller.radiusMeters, equals(3000.0));

        controller.setRadiusMeters(100000.0);
        expect(controller.radiusMeters, equals(3000.0));
      });

      test('gracefully ignores NaN radius input', () {
        final controller = PlacesController(
          placesRepository: fakePlacesRepo,
          storageRepository: fakeStorageRepo,
          initialRadiusMeters: double.nan,
        );
        // Default fallback is 500.0
        expect(controller.radiusMeters, equals(500.0));

        controller.setRadiusMeters(double.nan);
        expect(controller.radiusMeters, equals(500.0));
      });
    });

    group('Minimum Rating Boundaries & Clamping', () {
      test('enforces exact lower bound of 0.0 rating', () {
        final controller = PlacesController(
          placesRepository: fakePlacesRepo,
          storageRepository: fakeStorageRepo,
          initialMinRating: 0.0,
        );
        expect(controller.minRating, equals(0.0));

        controller.setMinRating(0.0);
        expect(controller.minRating, equals(0.0));
      });

      test('clamps negative ratings to 0.0', () {
        final controller = PlacesController(
          placesRepository: fakePlacesRepo,
          storageRepository: fakeStorageRepo,
          initialMinRating: -5.0,
        );
        expect(controller.minRating, equals(0.0));

        controller.setMinRating(-0.1);
        expect(controller.minRating, equals(0.0));
      });

      test('enforces exact upper bound of 5.0 rating', () {
        final controller = PlacesController(
          placesRepository: fakePlacesRepo,
          storageRepository: fakeStorageRepo,
          initialMinRating: 5.0,
        );
        expect(controller.minRating, equals(5.0));

        controller.setMinRating(5.0);
        expect(controller.minRating, equals(5.0));
      });

      test('clamps ratings exceeding 5.0 to 5.0', () {
        final controller = PlacesController(
          placesRepository: fakePlacesRepo,
          storageRepository: fakeStorageRepo,
          initialMinRating: 9.9,
        );
        expect(controller.minRating, equals(5.0));

        controller.setMinRating(5.1);
        expect(controller.minRating, equals(5.0));
      });

      test('gracefully handles NaN rating input', () {
        final controller = PlacesController(
          placesRepository: fakePlacesRepo,
          storageRepository: fakeStorageRepo,
          initialMinRating: double.nan,
        );
        // Default fallback is 4.5
        expect(controller.minRating, equals(4.5));

        controller.setMinRating(double.nan);
        expect(controller.minRating, equals(4.5));
      });
    });

    group('Minimum Review Count Boundaries', () {
      test('supports 0 review count boundary (includes venues with 0 reviews)', () async {
        final zeroReviewVenue = _createBoundaryPlace(
          id: 'v_zero',
          name: 'Yeni Açılan Mekan',
          reviewCount: 0,
          rating: 5.0,
        );

        fakePlacesRepo.placesToReturn = [zeroReviewVenue];
        final controller = PlacesController(
          placesRepository: fakePlacesRepo,
          storageRepository: fakeStorageRepo,
          initialCategoryId: 'all',
          initialMinReviewCount: 0,
        );
        await controller.loadPlaces();

        expect(controller.filteredPlaces.length, equals(1));
        expect(controller.filteredPlaces.first.id, equals('v_zero'));
      });

      test('clamps negative review count to 0', () {
        final controller = PlacesController(
          placesRepository: fakePlacesRepo,
          storageRepository: fakeStorageRepo,
          initialMinReviewCount: -15,
        );
        expect(controller.minReviewCount, equals(0));

        controller.setMinReviewCount(-50);
        expect(controller.minReviewCount, equals(0));
      });
    });

    group('Weighted Rating Recalculation Extremes', () {
      test('1 existing review (rating 5.0) receiving a 1.0 star review results in 3.0', () {
        final newRating = PlacesController.calculateWeightedRating(
          existingRating: 5.0,
          existingReviewCount: 1,
          userRatings: [1.0],
        );
        // (5.0 * 1 + 1.0) / 2 = 3.0
        expect(newRating, equals(3.0));
      });

      test('venue with 0 existing reviews receiving 5.0 star review computes 5.0', () {
        final newRating = PlacesController.calculateWeightedRating(
          existingRating: 0.0,
          existingReviewCount: 0,
          userRatings: [5.0],
        );
        expect(newRating, equals(5.0));
      });

      test('venue with 10,000 existing reviews (4.8) receiving single 1.0 review shifts infinitesimally', () {
        final newRating = PlacesController.calculateWeightedRating(
          existingRating: 4.8,
          existingReviewCount: 10000,
          userRatings: [1.0],
        );
        // (4.8 * 10000 + 1.0) / 10001 = 48001 / 10001 = 4.7996 -> formatted to 1 dec: 4.8
        expect(newRating, equals(4.8));
      });

      test('returns exact existingRating when userRatings list is empty', () {
        final rating = PlacesController.calculateWeightedRating(
          existingRating: 4.6,
          existingReviewCount: 50,
          userRatings: const [],
        );
        expect(rating, equals(4.6));
      });
    });

    group('Adaptive Radius Recommendation Boundaries', () {
      test('clamps expanded radius to minimum 100.0m when distance is very small (e.g. 40m)', () {
        final expanded = PlacesController.calculateExpandedRadius(40.0);
        // (40 + 50) = 90m -> clamped to 100.0m
        expect(expanded, equals(100.0));
      });

      test('clamps expanded radius to maximum 3000.0m when distance is very large (e.g. 3500m)', () {
        final expanded = PlacesController.calculateExpandedRadius(3500.0);
        // (3500 + 50) = 3550m -> clamped to 3000.0m
        expect(expanded, equals(3000.0));
      });

      test('calculates exact (distance + 50.0) within normal boundaries', () {
        expect(PlacesController.calculateExpandedRadius(250.0), equals(300.0));
        expect(PlacesController.calculateExpandedRadius(1200.0), equals(1250.0));
        expect(PlacesController.calculateExpandedRadius(2940.0), equals(2990.0));
      });
    });

    group('Place Model Boundary Values', () {
      test('formattedDistance formats meters up to 999m and kilometers from 1000m', () {
        final p999 = _createBoundaryPlace(id: '1', name: 'P999', distanceMeters: 999.4);
        expect(p999.formattedDistance, equals('999 m'));

        final p1000 = _createBoundaryPlace(id: '2', name: 'P1000', distanceMeters: 1000.0);
        expect(p1000.formattedDistance, equals('1.00 km'));

        final p3000 = _createBoundaryPlace(id: '3', name: 'P3000', distanceMeters: 3000.0);
        expect(p3000.formattedDistance, equals('3.00 km'));
      });

      test('walkingMinutes has a minimum of 1 minute even for 0 meters', () {
        final p0 = _createBoundaryPlace(id: '1', name: 'P0', distanceMeters: 0.0);
        expect(p0.walkingMinutes, equals(1));

        final p75 = _createBoundaryPlace(id: '2', name: 'P75', distanceMeters: 75.0);
        expect(p75.walkingMinutes, equals(1));

        final p76 = _createBoundaryPlace(id: '3', name: 'P76', distanceMeters: 76.0);
        // 76 / 75 = 1.013 -> ceil is 2
        expect(p76.walkingMinutes, equals(2));
      });

      test('priceSymbol clamps priceLevel between 1 and 4', () {
        final p0 = _createBoundaryPlace(id: '0', name: 'Free', priceLevel: 0);
        expect(p0.priceSymbol, equals('₺'));

        final p1 = _createBoundaryPlace(id: '1', name: 'Cheap', priceLevel: 1);
        expect(p1.priceSymbol, equals('₺'));

        final p4 = _createBoundaryPlace(id: '4', name: 'Luxury', priceLevel: 4);
        expect(p4.priceSymbol, equals('₺₺₺₺'));

        final p9 = _createBoundaryPlace(id: '9', name: 'Extreme', priceLevel: 9);
        expect(p9.priceSymbol, equals('₺₺₺₺'));
      });
    });

    group('Empty Results & Extreme Geographic Coordinates', () {
      test('handles empty venues list safely with zero results and null closest outside', () async {
        fakePlacesRepo.placesToReturn = const [];
        final controller = PlacesController(
          placesRepository: fakePlacesRepo,
          storageRepository: fakeStorageRepo,
        );
        await controller.loadPlaces();

        expect(controller.allPlaces, isEmpty);
        expect(controller.filteredPlaces, isEmpty);
        expect(controller.closestPlaceOutsideRadius, isNull);
      });

      test('calculateDistance handles identical and extreme coordinates without NaN or error', () {
        // Equator identical
        final dZero = fakePlacesRepo.calculateDistance(0.0, 0.0, 0.0, 0.0);
        expect(dZero, equals(0.0));

        // High Latitude (Arctic circle)
        final dNorth = fakePlacesRepo.calculateDistance(70.0, 20.0, 71.0, 21.0);
        expect(dNorth.isNaN, isFalse);
        expect(dNorth, greaterThan(100000));

        // Intercontinental distance (Istanbul to Tokyo ~9000 km)
        final dTokyo = fakePlacesRepo.calculateDistance(41.0082, 28.9784, 35.6762, 139.6503);
        expect(dTokyo.isNaN, isFalse);
        expect(dTokyo, greaterThan(8500000));
        expect(dTokyo, lessThan(9500000));
      });
    });
  });
}
