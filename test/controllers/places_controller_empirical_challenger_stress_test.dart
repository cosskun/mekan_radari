import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mekan_radari/controllers/places_controller.dart';
import 'package:mekan_radari/models/location_preset.dart';
import 'package:mekan_radari/models/place_model.dart';
import 'package:mekan_radari/repositories/places_repository.dart';
import 'package:mekan_radari/repositories/places_repository_impl.dart';

import '../fakes/fake_places_repository.dart';
import '../fakes/fake_storage_repository.dart';

Place _createDummyPlace({
  required String id,
  required String name,
  String category = 'Tatlı & Pastane',
  String subCategory = 'Pastane',
  double rating = 4.8,
  int reviewCount = 50,
  double lat = 40.9862,
  double lon = 29.0264,
  double distanceMeters = 200.0,
  List<String> tags = const ['tatlı', 'pasta'],
  List<String> popularItems = const ['Baklava', 'Cheesecake'],
}) {
  return Place(
    id: id,
    name: name,
    category: category,
    subCategory: subCategory,
    rating: rating,
    reviewCount: reviewCount,
    latitude: lat,
    longitude: lon,
    distanceMeters: distanceMeters,
    address: 'Kadıköy, İstanbul',
    phone: '+90 216 000 0000',
    website: 'https://mekan.test',
    openingHours: '09:00 - 23:00',
    isOpenNow: true,
    priceLevel: 2,
    tags: tags,
    popularItems: popularItems,
    reviews: const [],
    starDistribution: const {5: 40, 4: 10},
    dataSource: 'overpass',
  );
}

class _ChallengerAsyncPlacesRepository implements PlacesRepository {
  final List<Place> places;
  final Random rng = Random(1337);

  _ChallengerAsyncPlacesRepository(this.places);

  @override
  double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const Distance distance = Distance();
    return distance.as(
      LengthUnit.Meter,
      LatLng(lat1.clamp(-90.0, 90.0), lon1.clamp(-180.0, 180.0)),
      LatLng(lat2.clamp(-90.0, 90.0), lon2.clamp(-180.0, 180.0)),
    );
  }

  @override
  Future<List<Place>> fetchNearbyPlaces({
    required double lat,
    required double lon,
    required double radiusMeters,
    String? googleApiKey,
    String? searchQuery,
  }) async {
    // Inject asynchronous jitter between 1ms and 15ms
    await Future.delayed(Duration(milliseconds: rng.nextInt(15) + 1));
    return places;
  }

  @override
  Future<List<LocationPreset>> searchAddress(String query) async {
    await Future.delayed(Duration(milliseconds: rng.nextInt(10) + 1));
    return [
      LocationPreset(
        name: query,
        subtitle: 'Adres',
        latitude: 40.9862,
        longitude: 29.0264,
      ),
    ];
  }
}

void main() {
  group('Empirical Challenger: Concurrency, Re-entrancy & Race Integrity', () {
    test('50 concurrent interleaved async operations maintain internal invariant', () async {
      final initialPlaces = List.generate(
        10,
        (i) => _createDummyPlace(
          id: 'place_$i',
          name: 'Mekan #$i',
          lat: 40.9862 + (i * 0.001),
          lon: 29.0264 + (i * 0.001),
          distanceMeters: 100.0 + (i * 50),
        ),
      );

      final repo = _ChallengerAsyncPlacesRepository(initialPlaces);
      final storage = FakeStorageRepository();
      final controller = PlacesController(
        placesRepository: repo,
        storageRepository: storage,
      );

      await controller.init();

      final futures = <Future<dynamic>>[];

      // Fire 50 interleaved operations concurrently without awaiting sequentially
      for (int i = 0; i < 50; i++) {
        switch (i % 6) {
          case 0:
            futures.add(controller.loadPlaces());
            break;
          case 1:
            futures.add(
              controller.setLocation(
                lat: 41.0000 + (i * 0.002),
                lon: 29.0000 + (i * 0.002),
                label: 'Interleaved Location $i',
              ),
            );
            break;
          case 2:
            futures.add(
              controller.addUserReview(
                'place_${i % 10}',
                PlaceReview(
                  id: 'rev_$i',
                  authorName: 'User $i',
                  authorBadge: 'Gezgin',
                  rating: ((i % 5) + 1).toDouble(),
                  comment: 'Yorum $i',
                  relativeTime: 'Şimdi',
                ),
              ),
            );
            break;
          case 3:
            futures.add(controller.toggleFavorite('place_${i % 10}'));
            break;
          case 4:
            controller.setRadiusMeters(200.0 + (i * 30));
            controller.setMinRating(3.0 + (i % 3) * 0.5);
            break;
          case 5:
            controller.setSearchQuery(i % 2 == 0 ? 'Mekan' : '');
            controller.setCategoryId(i % 2 == 0 ? 'dessert' : 'all');
            break;
        }
      }

      await Future.wait(futures);

      // Verify invariant:
      expect(controller.isLoading, isFalse);
      expect(controller.isDisposed, isFalse);
      expect(controller.allPlaces, isNotEmpty);
      expect(controller.filteredPlaces, isA<List<Place>>());
      expect(() => controller.allPlaces.clear(), throwsA(isA<UnsupportedError>()));
      expect(() => controller.filteredPlaces.clear(), throwsA(isA<UnsupportedError>()));
    });

    test('Re-entrant listener does not cause infinite recursion or throw', () async {
      final repo = FakePlacesRepository(
        placesToReturn: [_createDummyPlace(id: 'p1', name: 'Mekan 1')],
      );
      final controller = PlacesController(
        placesRepository: repo,
        storageRepository: FakeStorageRepository(),
      );

      int listenerCalls = 0;
      void listener() {
        listenerCalls++;
        if (listenerCalls < 5) {
          // Trigger a mutation inside listener (re-entrancy check)
          controller.setMinReviewCount(listenerCalls * 5);
        }
      }

      controller.addListener(listener);

      // Trigger first notification
      controller.setRadiusMeters(1000.0);

      expect(listenerCalls, greaterThanOrEqualTo(5));
      controller.removeListener(listener);
    });
  });

  group('Empirical Challenger: Lifecycle & Dispose Hammering', () {
    test('Repeated dispose() 500 times is strictly idempotent and safe', () {
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
      );

      for (int i = 0; i < 500; i++) {
        expect(() => controller.dispose(), returnsNormally);
      }
      expect(controller.isDisposed, isTrue);
    });

    test('Async operations launched right before dispose() complete harmlessly', () async {
      final repo = FakePlacesRepository();
      repo.placesToReturn = [_createDummyPlace(id: 'p1', name: 'Mekan 1')];

      final controller = PlacesController(
        placesRepository: repo,
        storageRepository: FakeStorageRepository(),
      );

      final loadFuture = controller.loadPlaces();
      final setLocationFuture = controller.setLocation(
        lat: 41.0,
        lon: 29.0,
        label: 'Yeni Yer',
      );
      final addReviewFuture = controller.addUserReview(
        'p1',
        const PlaceReview(
          id: 'r1',
          authorName: 'A',
          authorBadge: 'B',
          rating: 5.0,
          comment: 'C',
          relativeTime: 'D',
        ),
      );

      // Dispose immediately while async calls are queued
      controller.dispose();

      // All futures should complete without unhandled exception
      await expectLater(loadFuture, completes);
      await expectLater(setLocationFuture, completes);
      await expectLater(addReviewFuture, completes);

      expect(controller.isDisposed, isTrue);
    });
  });

  group('Empirical Challenger: High-Volume Performance & Scalability Oracle', () {
    test('2,000 venues: 100 sequential filter & sort queries complete in < 500ms', () {
      final rng = Random(999);
      final massiveVenues = List.generate(
        2000,
        (i) => _createDummyPlace(
          id: 'venue_$i',
          name: 'Lezzet Noktası #${i % 100} - ${i % 2 == 0 ? 'Antep Baklavacısı' : 'Specialty Roastery'}',
          rating: 3.5 + (rng.nextInt(15) / 10.0),
          reviewCount: rng.nextInt(500),
          distanceMeters: (rng.nextInt(2950) + 50).toDouble(),
          category: i % 2 == 0 ? 'Tatlı & Pastane' : 'Kahve & Çay',
          subCategory: i % 2 == 0 ? 'Baklava' : 'Kafe',
        ),
      );

      final sw = Stopwatch()..start();

      for (int q = 0; q < 100; q++) {
        final query = q % 3 == 0 ? 'antep' : (q % 3 == 1 ? 'kahve' : '');
        final cat = q % 2 == 0 ? 'dessert' : 'all';
        final sort = SortOption.values[q % SortOption.values.length];

        final filtered = PlacesController.filterPlaces(
          places: massiveVenues,
          selectedCategoryId: cat,
          radiusMeters: 1500.0,
          minRating: 4.2,
          minReviewCount: 10,
          searchQuery: query,
          showFavoritesOnly: false,
          favoriteIds: const {},
        );

        final sorted = PlacesController.sortPlaces(
          places: filtered,
          sortOption: sort,
        );

        expect(sorted, isA<List<Place>>());
      }

      sw.stop();

      // Assert total execution of 100 filter+sort iterations on 2000 venues is under 500ms
      expect(sw.elapsedMilliseconds, lessThan(500),
          reason: '2,000 venues filter+sort took ${sw.elapsedMilliseconds}ms, must be < 500ms');
    });
  });

  group('Empirical Challenger: Coordinate Singularities & Distance Calculation', () {
    test('calculateDistance handles poles, date line, and antipodal points', () {
      final repo = PlacesRepositoryImpl();

      // North Pole to South Pole
      final poleDist = repo.calculateDistance(90.0, 0.0, -90.0, 0.0);
      expect(poleDist.isNaN, isFalse);
      expect(poleDist.isInfinite, isFalse);
      expect(poleDist, closeTo(20015000.0, 50000.0)); // ~20,000 km half circumference

      // Across Date Line (+179.9 lon to -179.9 lon near equator)
      final dateLineDist = repo.calculateDistance(0.0, 179.9, 0.0, -179.9);
      expect(dateLineDist.isNaN, isFalse);
      expect(dateLineDist.isInfinite, isFalse);
      expect(dateLineDist, closeTo(22200.0, 1000.0)); // ~0.2 degrees longitude = ~22.2 km

      // Identical coordinates
      final zeroDist = repo.calculateDistance(40.9862, 29.0264, 40.9862, 29.0264);
      expect(zeroDist, equals(0.0));
    });

    test('PlacesController handles antipodal and pole relocations without crash', () async {
      final repo = FakePlacesRepository();
      final controller = PlacesController(
        placesRepository: repo,
        storageRepository: FakeStorageRepository(),
      );

      // Relocate to North Pole
      await controller.setLocation(lat: 90.0, lon: 0.0, label: 'Kuzey Kutbu');
      expect(controller.centerLat, equals(90.0));

      // Relocate to Date Line
      await controller.setLocation(lat: 0.0, lon: 180.0, label: 'Tarih Değiştirme Çizgisi');
      expect(controller.centerLon, equals(180.0));
    });
  });

  group('Empirical Challenger: Regex Security & Catastrophic Backtracking Stress', () {
    test('20,000 delimiter characters in text do not cause catastrophic regex backtracking', () {
      final maliciousDelimiters = r' ,./-_&+()!?:;"*|' * 1200; // ~20,000 chars
      final venue = _createDummyPlace(
        id: 'p_regex',
        name: 'Normal Mekan $maliciousDelimiters',
        category: 'Alakasız Kategori',
        subCategory: 'Alakasız Alt Kategori',
        popularItems: [],
      );

      final sw = Stopwatch()..start();
      final matches = PlacesController.matchesCategory(
        venue,
        PlaceCategoryFilter.allCategories.firstWhere((c) => c.id == 'dessert'),
      );
      sw.stop();

      expect(matches, isFalse);
      expect(sw.elapsedMilliseconds, lessThan(100),
          reason: 'Delimiter regex evaluation took ${sw.elapsedMilliseconds}ms, must be < 100ms');
    });

    test('Exact Turkish I / İ casing roundtrip with large strings', () {
      final testCases = [
        ('İSTANBUL', 'istanbul'),
        ('IHLAMUR', 'ıhlamur'),
        ('ÇARŞI', 'çarşı'),
        ('ÖZEL', 'özel'),
        ('ŞÖLEN', 'şölen'),
        ('Ğ', 'ğ'),
      ];

      for (final (upper, expectedLower) in testCases) {
        expect(PlacesController.turkishToLower(upper), equals(expectedLower));
      }
    });
  });
}
