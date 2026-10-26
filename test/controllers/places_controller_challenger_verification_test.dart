import 'package:flutter_test/flutter_test.dart';
import 'package:mekan_radari/controllers/places_controller.dart';
import 'package:mekan_radari/models/place_model.dart';

import '../fakes/fake_places_repository.dart';
import '../fakes/fake_storage_repository.dart';

Place _createTestPlace({
  required String id,
  required String name,
  String category = 'Tatlı & Pastane',
  String subCategory = 'Pastane',
  double rating = 4.8,
  int reviewCount = 100,
  double latitude = 40.9862,
  double longitude = 29.0264,
  double distanceMeters = 200.0,
  String address = 'Moda Cd. No:1, Kadıköy/İstanbul',
  List<String> tags = const ['tatlı', 'pasta'],
  List<String> popularItems = const ['Cheesecake', 'Profiterol'],
  List<PlaceReview> reviews = const [],
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
    address: address,
    phone: '+90 216 555 0000',
    website: 'https://test.com',
    openingHours: '09:00 - 23:00',
    isOpenNow: true,
    priceLevel: 2,
    tags: tags,
    popularItems: popularItems,
    reviews: reviews,
    starDistribution: const {5: 0.8, 4: 0.2},
    dataSource: 'overpass',
  );
}

void main() {
  group('Challenger Adversarial Test: filteredPlaces Immutability', () {
    test('filteredPlaces throws UnsupportedError on add, clear, remove, removeAt when populated', () async {
      final samplePlace = _createTestPlace(id: 'p1', name: 'Sample Place');
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(placesToReturn: [samplePlace]),
        storageRepository: FakeStorageRepository(),
      );
      await controller.loadPlaces();

      final list = controller.filteredPlaces;
      expect(list.length, equals(1));

      final dummyPlace = _createTestPlace(id: 'dummy', name: 'Dummy');

      // 1. add
      expect(() => list.add(dummyPlace), throwsA(isA<UnsupportedError>()));
      // 2. clear
      expect(() => list.clear(), throwsA(isA<UnsupportedError>()));
      // 3. remove
      expect(() => list.remove(samplePlace), throwsA(isA<UnsupportedError>()));
      // 4. removeAt
      expect(() => list.removeAt(0), throwsA(isA<UnsupportedError>()));
      // 5. operator []=
      expect(() => list[0] = dummyPlace, throwsA(isA<UnsupportedError>()));
      // 6. sort
      expect(() => list.sort(), throwsA(isA<UnsupportedError>()));
      // 7. direct access on getter also throws
      expect(() => controller.filteredPlaces.add(dummyPlace), throwsA(isA<UnsupportedError>()));
      expect(() => controller.filteredPlaces.clear(), throwsA(isA<UnsupportedError>()));
      expect(() => controller.filteredPlaces.remove(samplePlace), throwsA(isA<UnsupportedError>()));
    });

    test('filteredPlaces throws UnsupportedError even when empty', () async {
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(placesToReturn: []),
        storageRepository: FakeStorageRepository(),
      );
      await controller.loadPlaces();

      final list = controller.filteredPlaces;
      expect(list, isEmpty);

      final dummyPlace = _createTestPlace(id: 'dummy', name: 'Dummy');

      expect(() => list.add(dummyPlace), throwsA(isA<UnsupportedError>()));
      expect(() => list.clear(), throwsA(isA<UnsupportedError>()));
      expect(() => list.remove(dummyPlace), throwsA(isA<UnsupportedError>()));
      expect(() => list.addAll([dummyPlace]), throwsA(isA<UnsupportedError>()));
    });
  });

  group('Challenger Adversarial Test: userReviewsMap Nested Lists & Map Immutability', () {
    test('userReviewsMap nested review lists throw UnsupportedError on add, clear, remove, removeAt', () async {
      final samplePlace = _createTestPlace(id: 'p1', name: 'Sample Place');
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(placesToReturn: [samplePlace]),
        storageRepository: FakeStorageRepository(),
      );
      await controller.loadPlaces();

      const initialReview = PlaceReview(
        id: 'r1',
        authorName: 'Author 1',
        authorBadge: '',
        rating: 5.0,
        relativeTime: '1 saat önce',
        comment: 'Harika lezzet',
      );
      await controller.addUserReview('p1', initialReview);

      const injectedReview = PlaceReview(
        id: 'r_injected',
        authorName: 'Hacker',
        authorBadge: '',
        rating: 1.0,
        relativeTime: 'şimdi',
        comment: 'Injected review',
      );

      final reviewList = controller.userReviewsMap['p1']!;
      expect(reviewList.length, equals(1));

      // 1. add
      expect(() => reviewList.add(injectedReview), throwsA(isA<UnsupportedError>()));
      // 2. clear
      expect(() => reviewList.clear(), throwsA(isA<UnsupportedError>()));
      // 3. remove
      expect(() => reviewList.remove(initialReview), throwsA(isA<UnsupportedError>()));
      // 4. removeAt
      expect(() => reviewList.removeAt(0), throwsA(isA<UnsupportedError>()));
      // 5. operator []=
      expect(() => reviewList[0] = injectedReview, throwsA(isA<UnsupportedError>()));
      // 6. Direct access through getter
      expect(() => controller.userReviewsMap['p1']!.add(injectedReview), throwsA(isA<UnsupportedError>()));
      expect(() => controller.userReviewsMap['p1']!.clear(), throwsA(isA<UnsupportedError>()));
    });

    test('userReviewsMap nested review lists loaded from init() are unmodifiable', () async {
      final fakeStorage = FakeStorageRepository(
        initialReviews: {
          'p_preload': [
            const PlaceReview(
              id: 'r_pre',
              authorName: 'Preloaded',
              authorBadge: '',
              rating: 4.0,
              relativeTime: 'dün',
              comment: 'Önceden kayıtlı yorum',
            ),
          ],
        },
      );
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: fakeStorage,
      );
      await controller.init();

      expect(controller.userReviewsMap.containsKey('p_preload'), isTrue);
      final list = controller.userReviewsMap['p_preload']!;
      expect(list.length, equals(1));

      expect(
        () => list.add(
          const PlaceReview(
            id: 'r_bad',
            authorName: 'Bad',
            authorBadge: '',
            rating: 1.0,
            relativeTime: '',
            comment: '',
          ),
        ),
        throwsA(isA<UnsupportedError>()),
      );
      expect(() => list.clear(), throwsA(isA<UnsupportedError>()));
    });

    test('userReviewsMap outer map throws UnsupportedError on insertion, modification, removal, clear', () async {
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
      );
      await controller.addUserReview(
        'p1',
        const PlaceReview(
          id: 'r1',
          authorName: 'A1',
          authorBadge: '',
          rating: 5.0,
          relativeTime: '',
          comment: '',
        ),
      );

      final map = controller.userReviewsMap;
      expect(() => map['p2'] = [], throwsA(isA<UnsupportedError>()));
      expect(() => map.remove('p1'), throwsA(isA<UnsupportedError>()));
      expect(() => map.clear(), throwsA(isA<UnsupportedError>()));
      expect(() => controller.userReviewsMap['p3'] = [], throwsA(isA<UnsupportedError>()));
    });
  });

  group('Challenger Adversarial Test: dispose() Multiple Invocations Idempotency', () {
    test('Calling dispose() 2x, 5x, 20x sequentially is completely safe and returns normally', () {
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
      );

      // 1st call
      controller.dispose();
      expect(controller.isDisposed, isTrue);

      // 2nd call
      expect(() => controller.dispose(), returnsNormally);
      expect(controller.isDisposed, isTrue);

      // 3rd, 4th, 5th calls
      expect(() => controller.dispose(), returnsNormally);
      expect(() => controller.dispose(), returnsNormally);
      expect(() => controller.dispose(), returnsNormally);

      // 20 subsequent calls
      for (int i = 0; i < 20; i++) {
        expect(() => controller.dispose(), returnsNormally);
      }
      expect(controller.isDisposed, isTrue);
    });

    test('All controller setters and notification calls after dispose() are safe and do not throw', () {
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
      );

      controller.dispose();
      expect(controller.isDisposed, isTrue);

      expect(() => controller.notifyListeners(), returnsNormally);
      expect(() => controller.setRadiusMeters(750.0), returnsNormally);
      expect(() => controller.setMinRating(4.0), returnsNormally);
      expect(() => controller.setMinReviewCount(10), returnsNormally);
      expect(() => controller.setSearchQuery('test'), returnsNormally);
      expect(() => controller.setCategoryId('cafe'), returnsNormally);
      expect(() => controller.setSortOption(SortOption.rating), returnsNormally);
      expect(() => controller.toggleViewMode(), returnsNormally);
      expect(() => controller.toggleFavoritesOnly(), returnsNormally);
    });
  });

  group('Challenger Adversarial Test: Setter & Constructor Bounds Clamping', () {
    test('setRadiusMeters guards against NaN and clamps negative, zero, and extreme values', () {
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
        initialRadiusMeters: 500.0,
      );

      // NaN: maintains current value without corrupting
      controller.setRadiusMeters(double.nan);
      expect(controller.radiusMeters, equals(500.0));

      // Negative values: clamped to 50.0
      controller.setRadiusMeters(-500.0);
      expect(controller.radiusMeters, equals(50.0));

      controller.setRadiusMeters(0.0);
      expect(controller.radiusMeters, equals(50.0));

      controller.setRadiusMeters(49.9);
      expect(controller.radiusMeters, equals(50.0));

      // Negative Infinity: clamped to 50.0
      controller.setRadiusMeters(double.negativeInfinity);
      expect(controller.radiusMeters, equals(50.0));

      // Upper boundary
      controller.setRadiusMeters(3000.0);
      expect(controller.radiusMeters, equals(3000.0));

      // Extreme large values: clamped to 3000.0
      controller.setRadiusMeters(3000.1);
      expect(controller.radiusMeters, equals(3000.0));

      controller.setRadiusMeters(100000.0);
      expect(controller.radiusMeters, equals(3000.0));

      // Positive Infinity: clamped to 3000.0
      controller.setRadiusMeters(double.infinity);
      expect(controller.radiusMeters, equals(3000.0));
    });

    test('setMinRating guards against NaN and clamps negative and extreme values', () {
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
        initialMinRating: 4.5,
      );

      // NaN: maintains current value
      controller.setMinRating(double.nan);
      expect(controller.minRating, equals(4.5));

      // Negative values: clamped to 0.0
      controller.setMinRating(-10.0);
      expect(controller.minRating, equals(0.0));

      controller.setMinRating(double.negativeInfinity);
      expect(controller.minRating, equals(0.0));

      // Upper boundary
      controller.setMinRating(5.0);
      expect(controller.minRating, equals(5.0));

      // Extreme large values: clamped to 5.0
      controller.setMinRating(5.01);
      expect(controller.minRating, equals(5.0));

      controller.setMinRating(1e6);
      expect(controller.minRating, equals(5.0));

      controller.setMinRating(double.infinity);
      expect(controller.minRating, equals(5.0));
    });

    test('setMinReviewCount clamps negative values to 0 and accepts non-negative counts', () {
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
        initialMinReviewCount: 10,
      );

      // Negative count: clamped to 0
      controller.setMinReviewCount(-1);
      expect(controller.minReviewCount, equals(0));

      controller.setMinReviewCount(-99999);
      expect(controller.minReviewCount, equals(0));

      // Valid counts
      controller.setMinReviewCount(0);
      expect(controller.minReviewCount, equals(0));

      controller.setMinReviewCount(500);
      expect(controller.minReviewCount, equals(500));

      controller.setMinReviewCount(1000000);
      expect(controller.minReviewCount, equals(1000000));
    });

    test('Constructor clamps initial values and guards against NaN', () {
      // Test NaN inputs fall back to defaults
      final cNan = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
        initialRadiusMeters: double.nan,
        initialMinRating: double.nan,
        initialMinReviewCount: -50,
      );
      expect(cNan.radiusMeters, equals(500.0));
      expect(cNan.minRating, equals(4.5));
      expect(cNan.minReviewCount, equals(0));

      // Test negative and negative infinity inputs
      final cNeg = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
        initialRadiusMeters: double.negativeInfinity,
        initialMinRating: -5.0,
        initialMinReviewCount: -1,
      );
      expect(cNeg.radiusMeters, equals(50.0));
      expect(cNeg.minRating, equals(0.0));
      expect(cNeg.minReviewCount, equals(0));

      // Test extreme positive and positive infinity inputs
      final cInf = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
        initialRadiusMeters: double.infinity,
        initialMinRating: double.infinity,
        initialMinReviewCount: 100,
      );
      expect(cInf.radiusMeters, equals(3000.0));
      expect(cInf.minRating, equals(5.0));
      expect(cInf.minReviewCount, equals(100));
    });
  });
}
