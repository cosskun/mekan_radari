import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mekan_radari/controllers/places_controller.dart';
import 'package:mekan_radari/models/place_model.dart';

import '../fakes/fake_places_repository.dart';
import '../fakes/fake_storage_repository.dart';

Place _createPlace({
  required String id,
  required String name,
  String category = 'Tatlı & Pastane',
  String subCategory = 'Pastane',
  double rating = 4.2,
  int reviewCount = 20,
  double latitude = 40.9862,
  double longitude = 29.0264,
  double distanceMeters = 200.0,
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
    address: 'Adres $id',
    phone: '+90 216 000 0000',
    website: 'https://test.com',
    openingHours: '09:00 - 23:00',
    isOpenNow: true,
    priceLevel: 2,
    tags: const ['tatlı', 'pasta'],
    popularItems: const ['Cheesecake'],
    reviews: reviews,
    starDistribution: const {5: 0.8, 4: 0.2},
    dataSource: 'overpass',
  );
}

class AsyncControllablePlacesRepo extends FakePlacesRepository {
  final List<Completer<List<Place>>> _completers = [];
  final List<bool> _throwFlags = [];

  Completer<List<Place>> createPendingFetch({bool willThrow = false}) {
    final c = Completer<List<Place>>();
    _completers.add(c);
    _throwFlags.add(willThrow);
    return c;
  }

  @override
  Future<List<Place>> fetchNearbyPlaces({
    required double lat,
    required double lon,
    required double radiusMeters,
    String? googleApiKey,
    String? searchQuery,
  }) async {
    if (_completers.isNotEmpty) {
      final c = _completers.removeAt(0);
      final throws = _throwFlags.removeAt(0);
      final places = await c.future;
      if (throws) {
        throw Exception('Simulated network failure');
      }
      return places;
    }
    return placesToReturn;
  }
}

void main() {
  group('Adversarial Mission 1: Review Merging & Rating Math Stress', () {
    test(
        '50+ sequential user reviews on the same place without double-counting or exponential drift',
        () async {
      final initialPlace = _createPlace(
        id: 'place_stress_1',
        name: 'Stress Test Baklavacısı',
        rating: 4.0,
        reviewCount: 10, // Initial score = 40.0
      );

      final fakeStorage = FakeStorageRepository();
      final fakePlaces = FakePlacesRepository(placesToReturn: [initialPlace]);
      final controller = PlacesController(
        placesRepository: fakePlaces,
        storageRepository: fakeStorage,
      );

      await controller.loadPlaces();
      expect(controller.allPlaces.first.reviewCount, equals(10));
      expect(controller.allPlaces.first.rating, equals(4.0));

      // Add 60 sequential reviews with rating 5.0
      // Analytical math:
      // Total score = 4.0 * 10 + 60 * 5.0 = 40.0 + 300.0 = 340.0
      // Total review count = 10 + 60 = 70
      // Expected rating = 340.0 / 70 = 4.85714... -> toStringAsFixed(1) = 4.9
      for (int i = 1; i <= 60; i++) {
        final review = PlaceReview(
          id: 'user_rev_$i',
          authorName: 'User $i',
          authorBadge: 'Ziyaretçi',
          rating: 5.0,
          relativeTime: 'Şimdi',
          comment: 'Yorum $i',
        );
        await controller.addUserReview('place_stress_1', review);

        // Verify incremental integrity
        final currentPlace = controller.allPlaces.first;
        expect(currentPlace.reviewCount, equals(10 + i));
        expect(controller.userReviewsMap['place_stress_1']!.length, equals(i));

        // Ensure base review count did NOT compound exponentially
        final expectedSum = 40.0 + (i * 5.0);
        final expectedCount = 10 + i;
        final expectedRating = double.parse(
            (expectedSum / expectedCount).clamp(1.0, 5.0).toStringAsFixed(1));
        expect(currentPlace.rating, equals(expectedRating));
      }

      final finalPlace = controller.allPlaces.first;
      expect(finalPlace.reviewCount, equals(70));
      expect(finalPlace.rating, equals(4.9));
      expect(finalPlace.reviews.length, equals(60));

      // Reload places from repository - user reviews must persist and merge cleanly
      await controller.loadPlaces();
      final reloadedPlace = controller.allPlaces.first;
      expect(reloadedPlace.reviewCount, equals(70));
      expect(reloadedPlace.rating, equals(4.9));
      expect(reloadedPlace.reviews.length, equals(60));
    });

    test('100 sequential reviews with alternating extreme ratings (1.0 and 5.0)',
        () async {
      // Base: rating 3.0, 20 reviews (total score = 60.0)
      final initialPlace = _createPlace(
        id: 'place_alt_1',
        name: 'Alternating Reviews Venue',
        rating: 3.0,
        reviewCount: 20,
      );

      final fakeStorage = FakeStorageRepository();
      final fakePlaces = FakePlacesRepository(placesToReturn: [initialPlace]);
      final controller = PlacesController(
        placesRepository: fakePlaces,
        storageRepository: fakeStorage,
      );

      await controller.loadPlaces();

      double runningScore = 60.0;
      int runningCount = 20;

      for (int i = 1; i <= 100; i++) {
        final rating = (i % 2 == 1) ? 1.0 : 5.0;
        runningScore += rating;
        runningCount += 1;

        final review = PlaceReview(
          id: 'alt_rev_$i',
          authorName: 'Reviewer $i',
          authorBadge: 'Ziyaretçi',
          rating: rating,
          relativeTime: 'Şimdi',
          comment: 'Alternating review $i',
        );

        await controller.addUserReview('place_alt_1', review);

        final p = controller.allPlaces.first;
        final expectedRating = double.parse(
            (runningScore / runningCount).clamp(1.0, 5.0).toStringAsFixed(1));
        expect(p.reviewCount, equals(runningCount));
        expect(p.rating, equals(expectedRating));
      }

      // After 50 reviews of 1.0 and 50 reviews of 5.0:
      // user sum = 50 * 1.0 + 50 * 5.0 = 50 + 250 = 300.0
      // total score = 60.0 + 300.0 = 360.0
      // total count = 20 + 100 = 120
      // 360.0 / 120 = 3.0
      final place = controller.allPlaces.first;
      expect(place.reviewCount, equals(120));
      expect(place.rating, equals(3.0));
      expect(place.reviews.length, equals(100));
    });

    test('Rating calculation extreme values: 0-star, negative, and 5-star',
        () async {
      // 1. Zero-star on place with 0 reviews
      final zeroPlace = _createPlace(
        id: 'zero_p',
        name: 'Zero Reviews Place',
        rating: 0.0,
        reviewCount: 0,
      );
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(placesToReturn: [zeroPlace]),
        storageRepository: FakeStorageRepository(),
      );
      await controller.loadPlaces();

      // Submit 0.0 star rating
      await controller.addUserReview(
        'zero_p',
        const PlaceReview(
          id: 'zr1',
          authorName: 'Tester',
          authorBadge: '',
          rating: 0.0,
          relativeTime: 'Bugün',
          comment: 'Sıfır yıldız',
        ),
      );
      // Math: (0.0 * 0 + 0.0) / 1 = 0.0 -> clamped to 1.0
      expect(controller.allPlaces.first.rating, equals(1.0));
      expect(controller.allPlaces.first.reviewCount, equals(1));

      // 2. 5.0-star on place with 0 reviews
      final zeroPlace2 = _createPlace(
        id: 'zero_p2',
        name: 'Zero Reviews Place 2',
        rating: 0.0,
        reviewCount: 0,
      );
      final controller2 = PlacesController(
        placesRepository: FakePlacesRepository(placesToReturn: [zeroPlace2]),
        storageRepository: FakeStorageRepository(),
      );
      await controller2.loadPlaces();

      await controller2.addUserReview(
        'zero_p2',
        const PlaceReview(
          id: 'zr2',
          authorName: 'Tester',
          authorBadge: '',
          rating: 5.0,
          relativeTime: 'Bugün',
          comment: 'Harika',
        ),
      );
      expect(controller2.allPlaces.first.rating, equals(5.0));
      expect(controller2.allPlaces.first.reviewCount, equals(1));

      // 3. Static calculateWeightedRating extremes
      // User ratings empty preserving existing rating 0.0
      expect(
        PlacesController.calculateWeightedRating(
          existingRating: 0.0,
          existingReviewCount: 0,
          userRatings: [],
        ),
        equals(0.0),
      );

      // Extreme high rating clamped to 5.0
      expect(
        PlacesController.calculateWeightedRating(
          existingRating: 4.0,
          existingReviewCount: 1,
          userRatings: [9999.0],
        ),
        equals(5.0),
      );

      // Extreme negative rating clamped to 1.0
      expect(
        PlacesController.calculateWeightedRating(
          existingRating: 4.0,
          existingReviewCount: 1,
          userRatings: [-9999.0],
        ),
        equals(1.0),
      );
    });

    test(
        'Unmodifiable collections: direct mutation attempts on allPlaces, favoriteIds, and userReviewsMap throw UnsupportedError',
        () async {
      final samplePlace = _createPlace(id: 'p1', name: 'Place 1');
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(placesToReturn: [samplePlace]),
        storageRepository: FakeStorageRepository(),
      );
      await controller.loadPlaces();

      final dummyPlace = _createPlace(id: 'dummy', name: 'Dummy');

      // 1. allPlaces getter must be unmodifiable
      expect(() => controller.allPlaces.add(dummyPlace),
          throwsA(isA<UnsupportedError>()));
      expect(() => controller.allPlaces.removeAt(0),
          throwsA(isA<UnsupportedError>()));
      expect(() => controller.allPlaces.clear(),
          throwsA(isA<UnsupportedError>()));
      expect(() => controller.allPlaces[0] = dummyPlace,
          throwsA(isA<UnsupportedError>()));

      // 2. favoriteIds getter must be unmodifiable
      expect(() => controller.favoriteIds.add('p_hacked'),
          throwsA(isA<UnsupportedError>()));
      expect(() => controller.favoriteIds.remove('p1'),
          throwsA(isA<UnsupportedError>()));
      expect(() => controller.favoriteIds.clear(),
          throwsA(isA<UnsupportedError>()));

      // 3. userReviewsMap map itself must be unmodifiable
      expect(() => controller.userReviewsMap['hacked'] = [],
          throwsA(isA<UnsupportedError>()));
      expect(() => controller.userReviewsMap.clear(),
          throwsA(isA<UnsupportedError>()));
    });

    test(
        'Unmodifiable collections: filteredPlaces getter throws UnsupportedError on mutation',
        () async {
      final samplePlace = _createPlace(id: 'p1', name: 'Place 1');
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(placesToReturn: [samplePlace]),
        storageRepository: FakeStorageRepository(),
      );
      await controller.loadPlaces();

      final dummyPlace = _createPlace(id: 'dummy', name: 'Dummy');

      // Direct mutation on filteredPlaces must throw UnsupportedError
      expect(() => controller.filteredPlaces.add(dummyPlace),
          throwsA(isA<UnsupportedError>()));
    });

    test(
        'Unmodifiable collections: nested review lists in userReviewsMap throw UnsupportedError on mutation',
        () async {
      final samplePlace = _createPlace(id: 'p1', name: 'Place 1');
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(placesToReturn: [samplePlace]),
        storageRepository: FakeStorageRepository(),
      );
      await controller.loadPlaces();

      await controller.addUserReview(
        'p1',
        const PlaceReview(
          id: 'r_orig',
          authorName: 'Orig',
          authorBadge: '',
          rating: 5.0,
          relativeTime: '',
          comment: '',
        ),
      );

      // Attempting to mutate nested review list directly must throw UnsupportedError
      expect(
        () => controller.userReviewsMap['p1']!.add(
          const PlaceReview(
            id: 'r_injected',
            authorName: 'Hacker',
            authorBadge: '',
            rating: 1.0,
            relativeTime: '',
            comment: '',
          ),
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('Adversarial Mission 2: Concurrency & Race Condition Stress', () {
    test(
        'Superseded loadPlaces() responses are discarded and do not overwrite newer state (_loadRequestId invariant)',
        () async {
      final repo = AsyncControllablePlacesRepo();
      final controller = PlacesController(
        placesRepository: repo,
        storageRepository: FakeStorageRepository(),
      );

      final fetch1Completer = repo.createPendingFetch();
      final fetch2Completer = repo.createPendingFetch();

      // Initiate Request 1
      final future1 = controller.loadPlaces();
      expect(controller.isLoading, isTrue);

      // Initiate Request 2 before Request 1 finishes
      final future2 = controller.loadPlaces();
      expect(controller.isLoading, isTrue);

      // Resolve Request 2 FIRST with Place 2
      final place2 = _createPlace(id: 'place_2', name: 'Newer Place 2');
      fetch2Completer.complete([place2]);
      await future2;

      // Controller must now contain Place 2
      expect(controller.isLoading, isFalse);
      expect(controller.allPlaces, hasLength(1));
      expect(controller.allPlaces.first.id, equals('place_2'));

      // Now resolve Request 1 LATER with Place 1 (stale response)
      final place1 = _createPlace(id: 'place_1', name: 'Stale Place 1');
      fetch1Completer.complete([place1]);
      await future1;

      // Invariant: Place 1 must be DISCARDED, controller must STILL contain Place 2!
      expect(controller.isLoading, isFalse);
      expect(controller.allPlaces, hasLength(1));
      expect(controller.allPlaces.first.id, equals('place_2'));
    });

    test(
        'Superseded error response does not overwrite successful newer response',
        () async {
      final repo = AsyncControllablePlacesRepo();
      final controller = PlacesController(
        placesRepository: repo,
        storageRepository: FakeStorageRepository(),
      );

      final fetch1Completer = repo.createPendingFetch(willThrow: true);
      final fetch2Completer = repo.createPendingFetch(willThrow: false);

      final future1 = controller.loadPlaces();
      final future2 = controller.loadPlaces();

      // Complete Request 2 successfully
      final place2 = _createPlace(id: 'place_ok', name: 'OK Place');
      fetch2Completer.complete([place2]);
      await future2;

      expect(controller.statusMessage, isNull);
      expect(controller.allPlaces, hasLength(1));

      // Complete Request 1 with error
      fetch1Completer.complete([]);
      await future1;

      // Stale error must be discarded!
      expect(controller.statusMessage, isNull);
      expect(controller.isLoading, isFalse);
      expect(controller.allPlaces.first.id, equals('place_ok'));
    });

    test(
        'Superseded error response does not overwrite in-flight loading state of newer request',
        () async {
      final repo = AsyncControllablePlacesRepo();
      final controller = PlacesController(
        placesRepository: repo,
        storageRepository: FakeStorageRepository(),
      );

      final fetch1Completer = repo.createPendingFetch(willThrow: true);
      final fetch2Completer = repo.createPendingFetch(willThrow: false);

      final future1 = controller.loadPlaces();
      final future2 = controller.loadPlaces();

      // Request 1 fails while Request 2 is still in-flight
      fetch1Completer.complete([]);
      await future1;

      // Invariant: isLoading must remain true because Request 2 is still running
      expect(controller.isLoading, isTrue);
      expect(controller.statusMessage, isNot(contains('Simulated network failure')));

      // Now complete Request 2
      fetch2Completer.complete([_createPlace(id: 'p_final', name: 'Final')]);
      await future2;

      expect(controller.isLoading, isFalse);
      expect(controller.allPlaces.first.id, equals('p_final'));
      expect(controller.statusMessage, isNull);
    });

    test(
        'Rapid 20 concurrent loadPlaces() completed out of order accept only the latest request',
        () async {
      final repo = AsyncControllablePlacesRepo();
      final controller = PlacesController(
        placesRepository: repo,
        storageRepository: FakeStorageRepository(),
      );

      final completers = <Completer<List<Place>>>[];
      final futures = <Future<void>>[];

      for (int i = 0; i < 20; i++) {
        completers.add(repo.createPendingFetch());
        futures.add(controller.loadPlaces());
      }

      // Complete in reverse order (19 down to 0)
      for (int i = 19; i >= 0; i--) {
        completers[i].complete([_createPlace(id: 'place_$i', name: 'Place $i')]);
      }

      await Future.wait(futures);

      // Only place_19 (the 20th request) must be in allPlaces
      expect(controller.allPlaces, hasLength(1));
      expect(controller.allPlaces.first.id, equals('place_19'));
      expect(controller.isLoading, isFalse);
    });

    test(
        'Interleaved setLocation() calls discard stale geolocation responses',
        () async {
      final repo = AsyncControllablePlacesRepo();
      final controller = PlacesController(
        placesRepository: repo,
        storageRepository: FakeStorageRepository(),
      );

      final fetch1Completer = repo.createPendingFetch();
      final fetch2Completer = repo.createPendingFetch();

      // Call 1: Beşiktaş
      final future1 = controller.setLocation(
        lat: 41.0422,
        lon: 29.0067,
        label: 'Beşiktaş',
      );

      // Call 2: Kadıköy
      final future2 = controller.setLocation(
        lat: 40.9862,
        lon: 29.0264,
        label: 'Kadıköy',
      );

      // Resolve Kadıköy first
      fetch2Completer.complete([
        _createPlace(id: 'kadikoy_p', name: 'Kadıköy Venue', latitude: 40.9862, longitude: 29.0264),
      ]);
      await future2;

      // Resolve Beşiktaş later
      fetch1Completer.complete([
        _createPlace(id: 'besiktas_p', name: 'Beşiktaş Venue', latitude: 41.0422, longitude: 29.0067),
      ]);
      await future1;

      expect(controller.locationLabel, equals('Kadıköy'));
      expect(controller.centerLat, equals(40.9862));
      expect(controller.allPlaces, hasLength(1));
      expect(controller.allPlaces.first.id, equals('kadikoy_p'));
    });

    test('Calling all actions after dispose() does not throw or crash', () async {
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
      );

      controller.dispose();
      expect(controller.isDisposed, isTrue);

      // Verify all actions can be called without FlutterError
      expect(() => controller.notifyListeners(), returnsNormally);
      expect(() => controller.setSearchQuery('test'), returnsNormally);
      expect(() => controller.setCategoryId('dessert'), returnsNormally);
      expect(() => controller.setRadiusMeters(1000.0), returnsNormally);
      expect(() => controller.setMinRating(4.0), returnsNormally);
      expect(() => controller.setMinReviewCount(10), returnsNormally);
      expect(() => controller.setSortOption(SortOption.rating), returnsNormally);
      expect(() => controller.toggleViewMode(), returnsNormally);
      expect(() => controller.toggleFavoritesOnly(), returnsNormally);
      expect(() => controller.expandRadiusToClosestPlace(), returnsNormally);

      await expectLater(controller.toggleFavorite('p1'), completes);
      await expectLater(
        controller.addUserReview(
          'p1',
          const PlaceReview(
            id: 'r_disp',
            authorName: 'Disposed User',
            authorBadge: '',
            rating: 5.0,
            relativeTime: 'Şimdi',
            comment: 'Comment',
          ),
        ),
        completes,
      );
      await expectLater(controller.setGoogleApiKey('key'), completes);
      await expectLater(
        controller.setLocation(lat: 41.0, lon: 29.0, label: 'Test'),
        completes,
      );
      await expectLater(controller.loadPlaces(), completes);
      await expectLater(controller.searchAddress('Kadıköy'), completes);
    });

    test('In-flight fetch completing after dispose() completes safely', () async {
      final repo = AsyncControllablePlacesRepo();
      final controller = PlacesController(
        placesRepository: repo,
        storageRepository: FakeStorageRepository(),
      );

      final fetchCompleter = repo.createPendingFetch();
      final future = controller.loadPlaces();

      // Dispose while loadPlaces is pending
      controller.dispose();

      // Complete fetch
      fetchCompleter.complete([_createPlace(id: 'p_disp', name: 'Disposed Place')]);
      await future;

      // Invariant: Controller is disposed, no crash occurred
      expect(controller.isDisposed, isTrue);
    });

    test('Calling dispose() multiple times is idempotent and does not throw', () {
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
      );

      controller.dispose();
      expect(() => controller.dispose(), returnsNormally);
    });
  });

  group('Adversarial Mission 3: Adaptive Radius Stress', () {
    test(
        'Venue at exact boundary distance (distanceMeters == radiusMeters) is included in filteredPlaces and closestPlaceOutsideRadius is null',
        () async {
      final placeExactBoundary = _createPlace(
        id: 'p_exact_500',
        name: 'Exact 500m Venue',
        distanceMeters: 500.0,
        rating: 4.8,
        latitude: 40.9850,
        longitude: 29.0250,
      );
      final placeOutside = _createPlace(
        id: 'p_outside_501',
        name: 'Just Outside 501m Venue',
        distanceMeters: 501.0,
        rating: 4.8,
        latitude: 40.9840,
        longitude: 29.0240,
      );

      final fakePlaces = FakePlacesRepository(
        placesToReturn: [placeExactBoundary, placeOutside],
        distanceCalculator: (lat1, lon1, lat2, lon2) {
          if (lat2 == placeExactBoundary.latitude) return 500.0;
          return 501.0;
        },
      );

      final controller = PlacesController(
        placesRepository: fakePlaces,
        storageRepository: FakeStorageRepository(),
        initialRadiusMeters: 500.0,
        initialMinRating: 4.5,
        initialCategoryId: 'dessert',
      );

      await controller.loadPlaces();

      // Exact 500.0m is <= 500.0m, so it must be included in filteredPlaces
      expect(controller.filteredPlaces.map((p) => p.id), contains('p_exact_500'));
      expect(controller.filteredPlaces.map((p) => p.id), isNot(contains('p_outside_501')));

      // Since filteredPlaces is not empty, closestPlaceOutsideRadius MUST be null
      expect(controller.closestPlaceOutsideRadius, isNull);
    });

    test(
        'When filteredPlaces is empty, venue at exact boundary + 1m is correctly identified as closestPlaceOutsideRadius',
        () async {
      final placeOutside = _createPlace(
        id: 'p_outside_501',
        name: 'Just Outside 501m Venue',
        distanceMeters: 501.0,
        rating: 4.8,
      );

      final fakePlaces = FakePlacesRepository(
        placesToReturn: [placeOutside],
        distanceCalculator: (lat1, lon1, lat2, lon2) => 501.0,
      );

      final controller = PlacesController(
        placesRepository: fakePlaces,
        storageRepository: FakeStorageRepository(),
        initialRadiusMeters: 500.0,
        initialMinRating: 4.5,
        initialCategoryId: 'dessert',
      );

      await controller.loadPlaces();

      expect(controller.filteredPlaces, isEmpty);
      final closest = controller.closestPlaceOutsideRadius;
      expect(closest, isNotNull);
      expect(closest!.id, equals('p_outside_501'));

      // Expand radius: (501.0 + 50.0).clamp(100.0, 3000.0) == 551.0
      controller.expandRadiusToClosestPlace();
      expect(controller.radiusMeters, equals(551.0));
      expect(controller.filteredPlaces, hasLength(1));
      expect(controller.filteredPlaces.first.id, equals('p_outside_501'));
    });

    test(
        'No venues outside radius returns null and expandRadiusToClosestPlace is a no-op',
        () async {
      final placeInside = _createPlace(
        id: 'p_inside',
        name: 'Inside Venue',
        distanceMeters: 300.0,
        rating: 4.8,
      );

      final fakePlaces = FakePlacesRepository(
        placesToReturn: [placeInside],
        distanceCalculator: (lat1, lon1, lat2, lon2) => 300.0,
      );

      final controller = PlacesController(
        placesRepository: fakePlaces,
        storageRepository: FakeStorageRepository(),
        initialRadiusMeters: 500.0,
        initialMinRating: 4.5,
        initialCategoryId: 'dessert',
      );

      await controller.loadPlaces();

      // Place matches inside radius
      expect(controller.closestPlaceOutsideRadius, isNull);

      // Now set min rating higher so placeInside is excluded
      controller.setMinRating(5.0);
      expect(controller.filteredPlaces, isEmpty);

      // Since placeInside has rating 4.8 (< 5.0), it does NOT qualify as closestPlaceOutsideRadius
      expect(controller.closestPlaceOutsideRadius, isNull);

      // expandRadiusToClosestPlace does not alter radius
      controller.expandRadiusToClosestPlace();
      expect(controller.radiusMeters, equals(500.0));
    });

    test(
        'Multiple venues with identical distances outside radius: expansion encompasses all of them',
        () async {
      final placeA = _createPlace(
        id: 'place_a',
        name: 'Place A',
        distanceMeters: 600.0,
        rating: 4.8,
        latitude: 40.981,
        longitude: 29.021,
      );
      final placeB = _createPlace(
        id: 'place_b',
        name: 'Place B',
        distanceMeters: 600.0,
        rating: 4.9,
        latitude: 40.982,
        longitude: 29.022,
      );
      final placeC = _createPlace(
        id: 'place_c',
        name: 'Place C',
        distanceMeters: 600.0,
        rating: 4.7,
        latitude: 40.983,
        longitude: 29.023,
      );

      final fakePlaces = FakePlacesRepository(
        placesToReturn: [placeA, placeB, placeC],
        distanceCalculator: (lat1, lon1, lat2, lon2) => 600.0,
      );

      final controller = PlacesController(
        placesRepository: fakePlaces,
        storageRepository: FakeStorageRepository(),
        initialRadiusMeters: 400.0,
        initialMinRating: 4.5,
        initialCategoryId: 'dessert',
      );

      await controller.loadPlaces();

      expect(controller.filteredPlaces, isEmpty);
      final closest = controller.closestPlaceOutsideRadius;
      expect(closest, isNotNull);
      expect(closest!.distanceMeters, equals(600.0));

      // Expand radius: (600.0 + 50.0).clamp(100.0, 3000.0) == 650.0
      controller.expandRadiusToClosestPlace();
      expect(controller.radiusMeters, equals(650.0));

      // Invariant: ALL 3 venues at 600.0m must now be inside filteredPlaces!
      expect(controller.filteredPlaces, hasLength(3));
      final ids = controller.filteredPlaces.map((p) => p.id).toList();
      expect(ids, contains('place_a'));
      expect(ids, contains('place_b'));
      expect(ids, contains('place_c'));
    });

    test(
        'Adaptive radius calculation clamps to [100.0, 3000.0] at extremes',
        () {
      // Very close: 20m + 50m = 70m -> clamped to 100.0m
      expect(PlacesController.calculateExpandedRadius(20.0), equals(100.0));
      expect(PlacesController.calculateExpandedRadius(50.0), equals(100.0));
      expect(PlacesController.calculateExpandedRadius(0.0), equals(100.0));

      // Normal range: 500m + 50m = 550.0m
      expect(PlacesController.calculateExpandedRadius(500.0), equals(550.0));

      // Near upper limit: 2970m + 50m = 3020m -> clamped to 3000.0m
      expect(PlacesController.calculateExpandedRadius(2970.0), equals(3000.0));
      expect(PlacesController.calculateExpandedRadius(5000.0), equals(3000.0));
    });
  });
}
