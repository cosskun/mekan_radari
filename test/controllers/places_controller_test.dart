import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mekan_radari/controllers/places_controller.dart';
import 'package:mekan_radari/models/location_preset.dart';
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
  group('Group 1: Initial State & Constructor Defaults', () {
    test('initializes with correct default parameters', () {
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
      );

      expect(controller.centerLat, equals(40.9862));
      expect(controller.centerLon, equals(29.0264));
      expect(controller.locationLabel, equals('Kadıköy - Moda & Çarşı'));
      expect(controller.searchQuery, isEmpty);
      expect(controller.selectedCategoryId, equals('dessert'));
      expect(controller.radiusMeters, equals(500.0));
      expect(controller.minRating, equals(4.5));
      expect(controller.minReviewCount, equals(0));
      expect(controller.sortOption, equals(SortOption.distance));
      expect(controller.isMapView, isFalse);
      expect(controller.showFavoritesOnly, isFalse);
      expect(controller.isLoading, isFalse);
      expect(controller.statusMessage, isNull);
      expect(controller.googleApiKey, isNull);
      expect(controller.isDisposed, isFalse);
      expect(controller.allPlaces, isEmpty);
      expect(controller.filteredPlaces, isEmpty);
      expect(controller.closestPlaceOutsideRadius, isNull);
      expect(controller.favoriteIds, isEmpty);
      expect(controller.userReviewsMap, isEmpty);
      expect(controller.isFavorite('non-existent'), isFalse);
    });

    test('respects custom initial coordinates and parameters', () {
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
        initialLat: 41.0422,
        initialLon: 29.0067,
        initialLocationLabel: 'Beşiktaş - Çarşı',
        initialRadiusMeters: 750.0,
        initialCategoryId: 'coffee',
        initialMinRating: 4.0,
        initialMinReviewCount: 20,
        initialSortOption: SortOption.rating,
      );

      expect(controller.centerLat, equals(41.0422));
      expect(controller.centerLon, equals(29.0067));
      expect(controller.locationLabel, equals('Beşiktaş - Çarşı'));
      expect(controller.radiusMeters, equals(750.0));
      expect(controller.selectedCategoryId, equals('coffee'));
      expect(controller.minRating, equals(4.0));
      expect(controller.minReviewCount, equals(20));
      expect(controller.sortOption, equals(SortOption.rating));
    });

    test('clamps invalid or NaN constructor parameters defensively', () {
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
        initialRadiusMeters: double.nan,
        initialMinRating: double.nan,
        initialMinReviewCount: -15,
      );

      expect(controller.radiusMeters, equals(500.0));
      expect(controller.minRating, equals(4.5));
      expect(controller.minReviewCount, equals(0));

      final outOfBoundsController = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
        initialRadiusMeters: 5000.0,
        initialMinRating: 6.5,
      );

      expect(outOfBoundsController.radiusMeters, equals(3000.0));
      expect(outOfBoundsController.minRating, equals(5.0));
    });
  });

  group('Group 2: Controller Lifecycle (init and loadPlaces)', () {
    test('init() synchronizes storage data and calls loadPlaces()', () async {
      const review = PlaceReview(
        id: 'r1',
        authorName: 'Ali',
        authorBadge: 'Rehber',
        rating: 5.0,
        relativeTime: '1 gün önce',
        comment: 'Süper',
      );
      final fakeStorage = FakeStorageRepository(
        initialFavorites: {'p1'},
        initialReviews: {
          'p1': [review],
        },
        initialGoogleApiKey: 'AIzaFakeKey',
      );
      final fakePlaces = FakePlacesRepository(
        placesToReturn: [
          _createTestPlace(id: 'p1', name: 'Place 1'),
          _createTestPlace(id: 'p2', name: 'Place 2'),
        ],
      );

      final controller = PlacesController(
        placesRepository: fakePlaces,
        storageRepository: fakeStorage,
      );

      await controller.init();

      expect(controller.favoriteIds, contains('p1'));
      expect(controller.userReviewsMap['p1'], hasLength(1));
      expect(controller.userReviewsMap['p1']!.first.authorName, equals('Ali'));
      expect(controller.googleApiKey, equals('AIzaFakeKey'));
      expect(controller.allPlaces, hasLength(2));
      expect(controller.isLoading, isFalse);
      expect(controller.statusMessage, isNull);
    });

    test('loadPlaces() manages loading flag transitions and notifies listeners',
        () async {
      final fakePlaces = FakePlacesRepository(
        placesToReturn: [_createTestPlace(id: 'p1', name: 'Place 1')],
      );
      final controller = PlacesController(
        placesRepository: fakePlaces,
        storageRepository: FakeStorageRepository(),
      );

      final loadingStates = <bool>[];
      int notificationCount = 0;
      controller.addListener(() {
        notificationCount++;
        loadingStates.add(controller.isLoading);
      });

      await controller.loadPlaces();

      expect(notificationCount, greaterThanOrEqualTo(2));
      expect(loadingStates, contains(true));
      expect(controller.isLoading, isFalse);
      expect(controller.allPlaces, hasLength(1));
    });

    test(
        'loadPlaces() recalculates venue distances using placesRepository.calculateDistance',
        () async {
      final fakePlaces = FakePlacesRepository(
        placesToReturn: [
          _createTestPlace(
            id: 'p1',
            name: 'Place 1',
            latitude: 41.0000,
            longitude: 29.0000,
            distanceMeters: 50.0,
          ),
        ],
        distanceCalculator: (lat1, lon1, lat2, lon2) => 320.0,
      );
      final controller = PlacesController(
        placesRepository: fakePlaces,
        storageRepository: FakeStorageRepository(),
      );

      await controller.loadPlaces();

      expect(controller.allPlaces.first.distanceMeters, equals(320.0));
    });
  });

  group('Group 3: Filter & State Setters', () {
    late PlacesController controller;
    late int notifyCount;

    setUp(() {
      controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
      );
      notifyCount = 0;
      controller.addListener(() => notifyCount++);
    });

    test('setSearchQuery updates searchQuery and notifies listeners', () {
      controller.setSearchQuery('cheesecake');
      expect(controller.searchQuery, equals('cheesecake'));
      expect(notifyCount, equals(1));

      // Duplicate value does not notify
      controller.setSearchQuery('cheesecake');
      expect(notifyCount, equals(1));
    });

    test('setCategoryId updates selectedCategoryId and notifies listeners', () {
      controller.setCategoryId('coffee');
      expect(controller.selectedCategoryId, equals('coffee'));
      expect(notifyCount, equals(1));

      controller.setCategoryId('coffee');
      expect(notifyCount, equals(1));
    });

    test('setRadiusMeters updates radiusMeters and notifies listeners', () {
      controller.setRadiusMeters(1000.0);
      expect(controller.radiusMeters, equals(1000.0));
      expect(notifyCount, equals(1));

      controller.setRadiusMeters(1000.0);
      expect(notifyCount, equals(1));
    });

    test('setMinRating updates minRating and notifies listeners', () {
      controller.setMinRating(4.7);
      expect(controller.minRating, equals(4.7));
      expect(notifyCount, equals(1));

      controller.setMinRating(4.7);
      expect(notifyCount, equals(1));
    });

    test('setMinReviewCount updates minReviewCount and notifies listeners', () {
      controller.setMinReviewCount(50);
      expect(controller.minReviewCount, equals(50));
      expect(notifyCount, equals(1));

      controller.setMinReviewCount(50);
      expect(notifyCount, equals(1));
    });

    test('setRadiusMeters clamps to [50.0, 3000.0] and guards against NaN', () {
      var count = 0;
      controller.addListener(() => count++);

      controller.setRadiusMeters(10.0);
      expect(controller.radiusMeters, equals(50.0));
      expect(count, equals(1));

      controller.setRadiusMeters(5000.0);
      expect(controller.radiusMeters, equals(3000.0));
      expect(count, equals(2));

      // NaN guard: value unchanged, listeners not notified
      controller.setRadiusMeters(double.nan);
      expect(controller.radiusMeters, equals(3000.0));
      expect(count, equals(2));
    });

    test('setMinRating clamps to [0.0, 5.0] and guards against NaN', () {
      var count = 0;
      controller.addListener(() => count++);

      controller.setMinRating(-1.5);
      expect(controller.minRating, equals(0.0));
      expect(count, equals(1));

      controller.setMinRating(6.5);
      expect(controller.minRating, equals(5.0));
      expect(count, equals(2));

      // NaN guard: value unchanged, listeners not notified
      controller.setMinRating(double.nan);
      expect(controller.minRating, equals(5.0));
      expect(count, equals(2));
    });

    test('setMinReviewCount clamps negative values to 0', () {
      var count = 0;
      controller.addListener(() => count++);

      controller.setMinReviewCount(-10);
      expect(controller.minReviewCount, equals(0));
      expect(count, equals(0)); // initial was 0, no-op

      controller.setMinReviewCount(25);
      expect(controller.minReviewCount, equals(25));
      expect(count, equals(1));

      controller.setMinReviewCount(-5);
      expect(controller.minReviewCount, equals(0));
      expect(count, equals(2));
    });

    test('setSortOption updates sortOption and notifies listeners', () {
      controller.setSortOption(SortOption.rating);
      expect(controller.sortOption, equals(SortOption.rating));
      expect(notifyCount, equals(1));

      controller.setSortOption(SortOption.rating);
      expect(notifyCount, equals(1));
    });

    test('toggleViewMode toggles isMapView and notifies listeners', () {
      controller.toggleViewMode();
      expect(controller.isMapView, isTrue);
      expect(notifyCount, equals(1));

      controller.toggleViewMode();
      expect(controller.isMapView, isFalse);
      expect(notifyCount, equals(2));
    });

    test('toggleFavoritesOnly toggles showFavoritesOnly and notifies listeners',
        () {
      controller.toggleFavoritesOnly();
      expect(controller.showFavoritesOnly, isTrue);
      expect(notifyCount, equals(1));

      controller.toggleFavoritesOnly();
      expect(controller.showFavoritesOnly, isFalse);
      expect(notifyCount, equals(2));
    });
  });

  group('Group 4: Multi-Criteria Filtering (filteredPlaces)', () {
    late PlacesController controller;
    late Place pDessertNear;
    late Place pDessertLowRating;
    late Place pCoffeeNear;
    late Place pRestaurantNear;
    late Place pDessertFar;

    setUp(() async {
      pDessertNear = _createTestPlace(
        id: 'p_dessert_near',
        name: 'Moda Pastanesi',
        category: 'Tatlı & Pastane',
        rating: 4.8,
        reviewCount: 200,
        distanceMeters: 200.0,
        tags: const ['pasta', 'tatlı'],
      );
      pDessertLowRating = _createTestPlace(
        id: 'p_dessert_low_rating',
        name: 'Karaköy Güllüoğlu',
        category: 'Tatlı & Pastane',
        rating: 4.2,
        reviewCount: 150,
        distanceMeters: 350.0,
        tags: const ['baklava', 'tatlı'],
      );
      pCoffeeNear = _createTestPlace(
        id: 'p_coffee_near',
        name: 'Kronotrop Coffee',
        category: 'Kahve & Kafe',
        rating: 4.9,
        reviewCount: 300,
        distanceMeters: 280.0,
        tags: const ['kahve', 'espresso'],
      );
      pRestaurantNear = _createTestPlace(
        id: 'p_restaurant_near',
        name: 'Çiya Sofrası',
        category: 'Restoran & Yemek',
        rating: 4.6,
        reviewCount: 500,
        distanceMeters: 450.0,
        tags: const ['kebap', 'yemek'],
      );
      pDessertFar = _createTestPlace(
        id: 'p_dessert_far',
        name: 'Moda Dondurmacısı',
        category: 'Tatlı & Pastane',
        rating: 4.9,
        reviewCount: 100,
        distanceMeters: 1500.0,
        tags: const ['dondurma', 'tatlı'],
      );

      final fakePlaces = FakePlacesRepository(
        placesToReturn: [
          pDessertNear,
          pDessertLowRating,
          pCoffeeNear,
          pRestaurantNear,
          pDessertFar,
        ],
        // Preserve distances provided on the places
        distanceCalculator: (lat1, lon1, lat2, lon2) {
          if (lat2 == pDessertNear.latitude && lon2 == pDessertNear.longitude) {
            return pDessertNear.distanceMeters;
          }
          return 200.0;
        },
      );

      // Custom repository ensuring exact distances are maintained
      fakePlaces.distanceCalculator = (lat1, lon1, lat2, lon2) {
        if (lat2 == pDessertNear.latitude && lon2 == pDessertNear.longitude) {
          return 200.0;
        }
        if (lat2 == pDessertLowRating.latitude &&
            lon2 == pDessertLowRating.longitude) {
          return 350.0;
        }
        if (lat2 == pCoffeeNear.latitude && lon2 == pCoffeeNear.longitude) {
          return 280.0;
        }
        if (lat2 == pRestaurantNear.latitude &&
            lon2 == pRestaurantNear.longitude) {
          return 450.0;
        }
        if (lat2 == pDessertFar.latitude && lon2 == pDessertFar.longitude) {
          return 1500.0;
        }
        return 200.0;
      };

      // Set unique coordinates for each place so distanceCalculator can match
      fakePlaces.placesToReturn = [
        pDessertNear.copyWith(distanceMeters: 200.0),
        pDessertLowRating.copyWith(distanceMeters: 350.0),
        pCoffeeNear.copyWith(distanceMeters: 280.0),
        pRestaurantNear.copyWith(distanceMeters: 450.0),
        pDessertFar.copyWith(distanceMeters: 1500.0),
      ];

      controller = PlacesController(
        placesRepository: fakePlaces,
        storageRepository: FakeStorageRepository(),
      );

      // We bypass distance recalculation override in tests by setting custom distanceCalculator
      fakePlaces.distanceCalculator = (lat1, lon1, lat2, lon2) {
        for (final p in fakePlaces.placesToReturn) {
          if (p.latitude == lat2 && p.longitude == lon2) {
            return p.distanceMeters;
          }
        }
        return 200.0;
      };

      // Assign distinct lat/lon to each
      final distinctPlaces = [
        pDessertNear = Place(
          id: 'p_dessert_near',
          name: 'Moda Pastanesi',
          category: 'Tatlı & Pastane',
          subCategory: 'Pastane',
          rating: 4.8,
          reviewCount: 200,
          latitude: 40.9861,
          longitude: 29.0261,
          distanceMeters: 200.0,
          address: 'Moda Cd. No:1, Kadıköy/İstanbul',
          openingHours: '09:00 - 23:00',
          isOpenNow: true,
          priceLevel: 2,
          tags: const ['pasta', 'tatlı'],
          popularItems: const ['Cheesecake'],
          reviews: const [],
          starDistribution: const {5: 0.8, 4: 0.2},
          dataSource: 'overpass',
        ),
        pDessertLowRating = Place(
          id: 'p_dessert_low_rating',
          name: 'Karaköy Güllüoğlu',
          category: 'Tatlı & Pastane',
          subCategory: 'Baklava',
          rating: 4.2,
          reviewCount: 150,
          latitude: 40.9862,
          longitude: 29.0262,
          distanceMeters: 350.0,
          address: 'Rıhtım Cd. No:2, Kadıköy/İstanbul',
          openingHours: '09:00 - 23:00',
          isOpenNow: true,
          priceLevel: 2,
          tags: const ['baklava', 'tatlı'],
          popularItems: const ['Baklava'],
          reviews: const [],
          starDistribution: const {5: 0.8, 4: 0.2},
          dataSource: 'overpass',
        ),
        pCoffeeNear = Place(
          id: 'p_coffee_near',
          name: 'Kronotrop Coffee',
          category: 'Kahve & Kafe',
          subCategory: 'Kahve',
          rating: 4.9,
          reviewCount: 300,
          latitude: 40.9863,
          longitude: 29.0263,
          distanceMeters: 280.0,
          address: 'Moda Cd. No:3, Kadıköy/İstanbul',
          openingHours: '09:00 - 23:00',
          isOpenNow: true,
          priceLevel: 2,
          tags: const ['kahve', 'espresso'],
          popularItems: const ['Cold Brew'],
          reviews: const [],
          starDistribution: const {5: 0.9, 4: 0.1},
          dataSource: 'overpass',
        ),
        pRestaurantNear = Place(
          id: 'p_restaurant_near',
          name: 'Çiya Sofrası',
          category: 'Restoran & Yemek',
          subCategory: 'Restoran',
          rating: 4.6,
          reviewCount: 500,
          latitude: 40.9864,
          longitude: 29.0264,
          distanceMeters: 450.0,
          address: 'Güneşli Bahçe Sk. No:4, Kadıköy/İstanbul',
          openingHours: '09:00 - 23:00',
          isOpenNow: true,
          priceLevel: 2,
          tags: const ['kebap', 'yemek'],
          popularItems: const ['Kebap'],
          reviews: const [],
          starDistribution: const {5: 0.8, 4: 0.2},
          dataSource: 'overpass',
        ),
        pDessertFar = Place(
          id: 'p_dessert_far',
          name: 'Moda Dondurmacısı',
          category: 'Tatlı & Pastane',
          subCategory: 'Dondurma',
          rating: 4.9,
          reviewCount: 100,
          latitude: 40.9865,
          longitude: 29.0265,
          distanceMeters: 1500.0,
          address: 'Moda Sahil No:5, Kadıköy/İstanbul',
          openingHours: '09:00 - 23:00',
          isOpenNow: true,
          priceLevel: 2,
          tags: const ['dondurma', 'tatlı'],
          popularItems: const ['Dondurma'],
          reviews: const [],
          starDistribution: const {5: 0.9, 4: 0.1},
          dataSource: 'overpass',
        ),
      ];

      fakePlaces.placesToReturn = distinctPlaces;
      fakePlaces.distanceCalculator = (lat1, lon1, lat2, lon2) {
        for (final p in distinctPlaces) {
          if ((p.latitude - lat2).abs() < 0.00001 &&
              (p.longitude - lon2).abs() < 0.00001) {
            return p.distanceMeters;
          }
        }
        return 200.0;
      };

      await controller.loadPlaces();
    });

    test(
        'Category filter dessert includes matching label and keywords while excluding others',
        () {
      controller.setRadiusMeters(3000.0);
      controller.setMinRating(0.0);
      controller.setCategoryId('dessert');

      final results = controller.filteredPlaces;
      final ids = results.map((p) => p.id).toList();

      expect(ids, contains('p_dessert_near'));
      expect(ids, contains('p_dessert_low_rating'));
      expect(ids, contains('p_dessert_far'));
      expect(ids, isNot(contains('p_coffee_near')));
      expect(ids, isNot(contains('p_restaurant_near')));
    });

    test('Category filter all includes all categories', () {
      controller.setRadiusMeters(3000.0);
      controller.setMinRating(0.0);
      controller.setCategoryId('all');

      final results = controller.filteredPlaces;
      expect(results, hasLength(5));
    });

    test('Radius filter strictly excludes places beyond radiusMeters', () {
      controller.setMinRating(0.0);
      controller.setCategoryId('dessert');
      controller.setRadiusMeters(300.0);

      final results = controller.filteredPlaces;
      final ids = results.map((p) => p.id).toList();

      expect(ids, contains('p_dessert_near'));
      expect(ids, isNot(contains('p_dessert_low_rating'))); // 350m > 300m
      expect(ids, isNot(contains('p_dessert_far'))); // 1500m > 300m
    });

    test('Min rating filter strictly excludes places below minRating', () {
      controller.setRadiusMeters(3000.0);
      controller.setCategoryId('dessert');
      controller.setMinRating(4.5);

      final results = controller.filteredPlaces;
      final ids = results.map((p) => p.id).toList();

      expect(ids, contains('p_dessert_near')); // 4.8 >= 4.5
      expect(ids, contains('p_dessert_far')); // 4.9 >= 4.5
      expect(ids, isNot(contains('p_dessert_low_rating'))); // 4.2 < 4.5
    });

    test('Min review count filter excludes places with reviewCount < minReviewCount',
        () {
      controller.setRadiusMeters(3000.0);
      controller.setMinRating(0.0);
      controller.setCategoryId('dessert');
      controller.setMinReviewCount(180);

      final results = controller.filteredPlaces;
      final ids = results.map((p) => p.id).toList();

      expect(ids, contains('p_dessert_near')); // 200 >= 180
      expect(ids, isNot(contains('p_dessert_low_rating'))); // 150 < 180
      expect(ids, isNot(contains('p_dessert_far'))); // 100 < 180
    });

    test(
        'Search query matches case-insensitively across name, address, tags, and items',
        () {
      controller.setRadiusMeters(3000.0);
      controller.setMinRating(0.0);
      controller.setCategoryId('all');

      // Search 'güllüoğlu'
      controller.setSearchQuery('güllüoğlu');
      expect(controller.filteredPlaces.map((p) => p.id),
          equals(['p_dessert_low_rating']));

      // Search uppercase 'MODA'
      controller.setSearchQuery('MODA');
      final modaIds = controller.filteredPlaces.map((p) => p.id).toList();
      expect(modaIds, contains('p_dessert_near'));
      expect(modaIds, contains('p_dessert_far'));

      // Non-existent search query returns empty
      controller.setSearchQuery('nonexistent_venue_query');
      expect(controller.filteredPlaces, isEmpty);
    });

    test('Favorites only filter restricts results to favorited places',
        () async {
      controller.setRadiusMeters(3000.0);
      controller.setMinRating(0.0);
      controller.setCategoryId('all');

      await controller.toggleFavorite('p_dessert_near');
      controller.toggleFavoritesOnly();

      final results = controller.filteredPlaces;
      expect(results, hasLength(1));
      expect(results.first.id, equals('p_dessert_near'));
    });

    test('Multi-criteria combination applies all filters conjunctively (AND)',
        () {
      controller.setCategoryId('dessert');
      controller.setRadiusMeters(500.0);
      controller.setMinRating(4.5);
      controller.setMinReviewCount(100);
      controller.setSearchQuery('Moda');

      final results = controller.filteredPlaces;
      expect(results, hasLength(1));
      expect(results.first.id, equals('p_dessert_near'));
    });
  });

  group('Group 5: Sorting Pipelines', () {
    late PlacesController controller;
    late Place venueA;
    late Place venueB;
    late Place venueC;

    setUp(() async {
      venueA = _createTestPlace(
        id: 'venue_a',
        name: 'Venue A',
        distanceMeters: 100.0,
        rating: 4.6,
        reviewCount: 100,
        latitude: 40.9810,
        longitude: 29.0210,
      );
      venueB = _createTestPlace(
        id: 'venue_b',
        name: 'Venue B',
        distanceMeters: 300.0,
        rating: 4.8,
        reviewCount: 50,
        latitude: 40.9820,
        longitude: 29.0220,
      );
      venueC = _createTestPlace(
        id: 'venue_c',
        name: 'Venue C',
        distanceMeters: 200.0,
        rating: 4.8,
        reviewCount: 200,
        latitude: 40.9830,
        longitude: 29.0230,
      );

      final fakePlaces = FakePlacesRepository(
        placesToReturn: [venueA, venueB, venueC],
        distanceCalculator: (lat1, lon1, lat2, lon2) {
          if ((lat2 - venueA.latitude).abs() < 0.0001) return 100.0;
          if ((lat2 - venueB.latitude).abs() < 0.0001) return 300.0;
          if ((lat2 - venueC.latitude).abs() < 0.0001) return 200.0;
          return 150.0;
        },
      );

      controller = PlacesController(
        placesRepository: fakePlaces,
        storageRepository: FakeStorageRepository(),
        initialRadiusMeters: 1000.0,
        initialMinRating: 0.0,
        initialCategoryId: 'all',
      );

      await controller.loadPlaces();
    });

    test('SortOption.distance sorts ascending by distanceMeters', () {
      controller.setSortOption(SortOption.distance);
      final ids = controller.filteredPlaces.map((p) => p.id).toList();
      expect(ids, equals(['venue_a', 'venue_c', 'venue_b']));
    });

    test(
        'SortOption.rating sorts descending by rating with reviewCount as tie-breaker',
        () {
      controller.setSortOption(SortOption.rating);
      final ids = controller.filteredPlaces.map((p) => p.id).toList();
      // Venue C (4.8, 200 revs) > Venue B (4.8, 50 revs) > Venue A (4.6, 100 revs)
      expect(ids, equals(['venue_c', 'venue_b', 'venue_a']));
    });

    test('SortOption.reviews sorts descending by reviewCount', () {
      controller.setSortOption(SortOption.reviews);
      final ids = controller.filteredPlaces.map((p) => p.id).toList();
      // Venue C (200) > Venue A (100) > Venue B (50)
      expect(ids, equals(['venue_c', 'venue_a', 'venue_b']));
    });
  });

  group('Group 6: Adaptive Radius Suggestion (closestPlaceOutsideRadius)', () {
    late PlacesController controller;
    late Place pDessertNear;
    late Place pDessertFar;

    setUp(() async {
      pDessertNear = _createTestPlace(
        id: 'p_near',
        name: 'Tatlıcı Yakın',
        category: 'Tatlı & Pastane',
        rating: 4.8,
        distanceMeters: 200.0,
        latitude: 40.9850,
        longitude: 29.0250,
      );
      pDessertFar = _createTestPlace(
        id: 'p_far',
        name: 'Tatlıcı Uzak',
        category: 'Tatlı & Pastane',
        rating: 4.9,
        distanceMeters: 1500.0,
        latitude: 40.9890,
        longitude: 29.0290,
      );

      final fakePlaces = FakePlacesRepository(
        placesToReturn: [pDessertNear, pDessertFar],
        distanceCalculator: (lat1, lon1, lat2, lon2) {
          if ((lat2 - pDessertNear.latitude).abs() < 0.0001) return 200.0;
          return 1500.0;
        },
      );

      controller = PlacesController(
        placesRepository: fakePlaces,
        storageRepository: FakeStorageRepository(),
        initialRadiusMeters: 100.0, // Both places outside 100m
        initialMinRating: 4.5,
        initialCategoryId: 'dessert',
      );

      await controller.loadPlaces();
    });

    test('returns closest matching place outside radius when filteredPlaces is empty',
        () {
      expect(controller.filteredPlaces, isEmpty);
      final closest = controller.closestPlaceOutsideRadius;
      expect(closest, isNotNull);
      expect(closest!.id, equals('p_near'));
      expect(closest.distanceMeters, equals(200.0));
    });

    test('returns null when no venues match category and rating outside radius',
        () {
      controller.setMinRating(5.0); // Neither place has 5.0
      expect(controller.closestPlaceOutsideRadius, isNull);
    });

    test('returns null when filteredPlaces is not empty', () {
      controller.setRadiusMeters(500.0); // Now p_near is inside radius
      expect(controller.filteredPlaces, isNotEmpty);
      expect(controller.closestPlaceOutsideRadius, isNull);
    });

    test('expandRadiusToClosestPlace expands radius to encompass closest venue',
        () {
      controller.setRadiusMeters(100.0);
      expect(controller.filteredPlaces, isEmpty);
      expect(controller.closestPlaceOutsideRadius?.id, equals('p_near'));

      controller.expandRadiusToClosestPlace();

      // Expected new radius: (200.0 + 50).clamp(100.0, 3000.0) == 250.0
      expect(controller.radiusMeters, equals(250.0));
      expect(controller.filteredPlaces, isNotEmpty);
      expect(controller.filteredPlaces.first.id, equals('p_near'));
    });

    test('closestPlaceOutsideRadius respects active searchQuery filter and returns matching venue', () {
      controller.setRadiusMeters(100.0);
      expect(controller.filteredPlaces, isEmpty);

      // pDessertNear has name 'Tatlıcı Yakın', pDessertFar has name 'Tatlıcı Uzak'
      controller.setSearchQuery('Uzak');
      final closest = controller.closestPlaceOutsideRadius;
      expect(closest, isNotNull);
      expect(closest!.id, equals('p_far'));
      expect(closest.distanceMeters, equals(1500.0));
    });

    test('closestPlaceOutsideRadius returns null when no venue outside radius matches active searchQuery', () {
      controller.setRadiusMeters(100.0);
      expect(controller.filteredPlaces, isEmpty);

      controller.setSearchQuery('Bulunamaz Cheesecake');
      expect(controller.closestPlaceOutsideRadius, isNull);
    });

    test('findClosestPlaceOutsideRadius static method filters by searchQuery and word-boundary category', () {
      final closest = PlacesController.findClosestPlaceOutsideRadius(
        places: [pDessertNear, pDessertFar],
        selectedCategoryId: 'dessert',
        radiusMeters: 100.0,
        minRating: 4.5,
        searchQuery: 'Uzak',
      );
      expect(closest, isNotNull);
      expect(closest!.id, equals('p_far'));
    });
  });

  group('Group 7: Favorite Toggling & Storage Synchronization', () {
    late PlacesController controller;
    late FakeStorageRepository fakeStorage;

    setUp(() {
      fakeStorage = FakeStorageRepository();
      controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: fakeStorage,
      );
    });

    test('toggleFavorite adds placeId to favorites and saves to StorageRepository',
        () async {
      await controller.toggleFavorite('place-123');

      expect(controller.favoriteIds, contains('place-123'));
      expect(controller.isFavorite('place-123'), isTrue);

      final persistedFavs = await fakeStorage.loadFavoriteIds();
      expect(persistedFavs, contains('place-123'));
    });

    test(
        'toggleFavorite removes placeId from favorites and saves to StorageRepository',
        () async {
      await controller.toggleFavorite('place-123');
      expect(controller.favoriteIds, contains('place-123'));

      await controller.toggleFavorite('place-123');
      expect(controller.favoriteIds, isNot(contains('place-123')));
      expect(controller.isFavorite('place-123'), isFalse);

      final persistedFavs = await fakeStorage.loadFavoriteIds();
      expect(persistedFavs, isNot(contains('place-123')));
    });
  });

  group('Group 8: User Reviews & Weighted Average Rating Calculation', () {
    late PlacesController controller;
    late FakeStorageRepository fakeStorage;

    setUp(() async {
      fakeStorage = FakeStorageRepository();
      final fakePlaces = FakePlacesRepository(
        placesToReturn: [
          _createTestPlace(
            id: 'p1',
            name: 'Test Place 1',
            rating: 4.0,
            reviewCount: 10,
          ),
        ],
        distanceCalculator: (lat1, lon1, lat2, lon2) => 150.0,
      );

      controller = PlacesController(
        placesRepository: fakePlaces,
        storageRepository: fakeStorage,
      );

      await controller.loadPlaces();
    });

    test(
        'addUserReview persists review to StorageRepository and updates userReviewsMap',
        () async {
      const review = PlaceReview(
        id: 'rev_1',
        authorName: 'Can',
        authorBadge: 'Ziyaretçi',
        rating: 5.0,
        relativeTime: 'Şimdi',
        comment: 'Nefis tatlar',
      );

      await controller.addUserReview('p1', review);

      expect(controller.userReviewsMap['p1'], hasLength(1));
      expect(controller.userReviewsMap['p1']!.first.comment, equals('Nefis tatlar'));

      final storedReviews = await fakeStorage.getReviewsForPlace('p1');
      expect(storedReviews, hasLength(1));
      expect(storedReviews.first.comment, equals('Nefis tatlar'));
    });

    test(
        'addUserReview recomputes weighted average rating and updates reviewCount in allPlaces',
        () async {
      // Initial: 4.0 rating with 10 reviews (score = 40.0)
      // New review: 5.0 rating (total score = 45.0, total reviews = 11)
      // Expected: 45.0 / 11 = 4.0909 -> formatted 4.1
      const review1 = PlaceReview(
        id: 'rev_1',
        authorName: 'Can',
        authorBadge: 'Ziyaretçi',
        rating: 5.0,
        relativeTime: 'Şimdi',
        comment: 'Harika',
      );

      await controller.addUserReview('p1', review1);

      final updatedPlace =
          controller.allPlaces.firstWhere((p) => p.id == 'p1');
      expect(updatedPlace.rating, equals(4.1));
      expect(updatedPlace.reviewCount, equals(11));
    });

    test(
        'subsequent reviews correctly accumulate weighted average without double-counting',
        () async {
      // Review 1
      const review1 = PlaceReview(
        id: 'rev_1',
        authorName: 'Can',
        authorBadge: 'Ziyaretçi',
        rating: 5.0,
        relativeTime: 'Şimdi',
        comment: 'Harika 1',
      );
      await controller.addUserReview('p1', review1);

      // Review 2: another 5.0
      // Total score = 40.0 + 5.0 + 5.0 = 50.0, total reviews = 12
      // Expected: 50.0 / 12 = 4.1666... -> formatted 4.2
      const review2 = PlaceReview(
        id: 'rev_2',
        authorName: 'Deniz',
        authorBadge: 'Ziyaretçi',
        rating: 5.0,
        relativeTime: 'Şimdi',
        comment: 'Harika 2',
      );
      await controller.addUserReview('p1', review2);

      final updatedPlace =
          controller.allPlaces.firstWhere((p) => p.id == 'p1');
      expect(updatedPlace.rating, equals(4.2));
      expect(updatedPlace.reviewCount, equals(12));
    });

    test(
        'calculateWeightedRating static method handles edge cases properly',
        () {
      // Empty user ratings preserves existing rating
      expect(
        PlacesController.calculateWeightedRating(
          existingRating: 4.5,
          existingReviewCount: 20,
          userRatings: [],
        ),
        equals(4.5),
      );

      // Clamping to [1.0, 5.0]
      expect(
        PlacesController.calculateWeightedRating(
          existingRating: 5.0,
          existingReviewCount: 1,
          userRatings: [10.0],
        ),
        equals(5.0),
      );

      expect(
        PlacesController.calculateWeightedRating(
          existingRating: 1.0,
          existingReviewCount: 1,
          userRatings: [-5.0],
        ),
        equals(1.0),
      );
    });
  });

  group('Group 9: Coordinate Updates & Address Search', () {
    test(
        'setLocation updates coordinates, location label, reloads places, and recalculates distances',
        () async {
      final fakePlaces = FakePlacesRepository(
        placesToReturn: [
          _createTestPlace(
            id: 'p1',
            name: 'Place 1',
            latitude: 41.0422,
            longitude: 29.0067,
          ),
        ],
        distanceCalculator: (lat1, lon1, lat2, lon2) {
          const Distance distance = Distance();
          return distance.as(
            LengthUnit.Meter,
            LatLng(lat1, lon1),
            LatLng(lat2, lon2),
          );
        },
      );

      final controller = PlacesController(
        placesRepository: fakePlaces,
        storageRepository: FakeStorageRepository(),
      );

      await controller.setLocation(
        lat: 41.0422,
        lon: 29.0067,
        label: 'Beşiktaş - Çarşı',
      );

      expect(controller.centerLat, equals(41.0422));
      expect(controller.centerLon, equals(29.0067));
      expect(controller.locationLabel, equals('Beşiktaş - Çarşı'));
      expect(controller.allPlaces, hasLength(1));
      // At identical coordinates, distance is 0m
      expect(controller.allPlaces.first.distanceMeters, equals(0.0));
    });

    test('searchAddress delegates query to PlacesRepository.searchAddress',
        () async {
      const preset = LocationPreset(
        name: 'Kadıköy',
        subtitle: 'İstanbul',
        latitude: 40.9862,
        longitude: 29.0264,
      );
      final fakePlaces = FakePlacesRepository(
        presetsToReturn: [preset],
      );
      final controller = PlacesController(
        placesRepository: fakePlaces,
        storageRepository: FakeStorageRepository(),
      );

      final presets = await controller.searchAddress('Kadıköy');

      expect(presets, hasLength(1));
      expect(presets.first.name, equals('Kadıköy'));
    });

    test('searchAddress returns empty list for empty or whitespace query',
        () async {
      final fakePlaces = FakePlacesRepository(
        presetsToReturn: [
          const LocationPreset(
            name: 'Kadıköy',
            subtitle: 'İstanbul',
            latitude: 40.9862,
            longitude: 29.0264,
          ),
        ],
      );
      final controller = PlacesController(
        placesRepository: fakePlaces,
        storageRepository: FakeStorageRepository(),
      );

      final presets = await controller.searchAddress('   ');
      expect(presets, isEmpty);
    });
  });

  group('Group 10: Error Handling, Resilience & Guards', () {
    test(
        'loadPlaces handles repository exception gracefully without unhandled crashes',
        () async {
      final fakePlaces = FakePlacesRepository(shouldThrow: true);
      final controller = PlacesController(
        placesRepository: fakePlaces,
        storageRepository: FakeStorageRepository(),
      );

      await controller.loadPlaces();

      expect(controller.isLoading, isFalse);
      expect(controller.statusMessage, isNotNull);
      expect(controller.statusMessage, contains('Simulated FakePlacesRepository error'));
      expect(controller.allPlaces, isEmpty);
    });

    test('searchAddress handles repository exception gracefully', () async {
      final fakePlaces = FakePlacesRepository(shouldThrow: true);
      final controller = PlacesController(
        placesRepository: fakePlaces,
        storageRepository: FakeStorageRepository(),
      );

      final results = await controller.searchAddress('fail');
      expect(results, isEmpty);
    });

    test('calling notifyListeners after dispose does not throw', () {
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
      );

      controller.dispose();
      expect(controller.isDisposed, isTrue);

      // Should not throw FlutterError
      expect(() => controller.notifyListeners(), returnsNormally);
    });

    test('setGoogleApiKey trims, persists, and refreshes places', () async {
      final fakeStorage = FakeStorageRepository();
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: fakeStorage,
      );

      await controller.setGoogleApiKey('  AIzaSampleKey123  ');

      expect(controller.googleApiKey, equals('AIzaSampleKey123'));
      final storedKey = await fakeStorage.loadGoogleApiKey();
      expect(storedKey, equals('AIzaSampleKey123'));

      // Empty or whitespace clears key
      await controller.setGoogleApiKey('   ');
      expect(controller.googleApiKey, isNull);
    });
  });

  group('Group 11: Turkish Case-Folding & Word-Boundary Category Matching', () {
    test('turkishToLower correctly lowercases dotted and dotless I according to Turkish rules', () {
      expect(PlacesController.turkishToLower(''), equals(''));
      expect(PlacesController.turkishToLower('ISPARTA'), equals('ısparta'));
      expect(PlacesController.turkishToLower('İSTANBUL'), equals('istanbul'));
      expect(PlacesController.turkishToLower('ÇITIR FIRIN'), equals('çıtır fırın'));
      expect(PlacesController.turkishToLower('ŞEKERLİ KAHVE'), equals('şekerli kahve'));
      expect(PlacesController.turkishToLower('ÖZEL DÜRÜM'), equals('özel dürüm'));
    });

    test('matchesCategoryKeywords matches whole words and compound keywords cleanly', () {
      // Standalone keyword match
      expect(
        PlacesController.matchesCategoryKeywords('Taze Köfte ve Et', ['et']),
        isTrue,
      );

      // Hyphen or delimiter-separated token match
      expect(
        PlacesController.matchesCategoryKeywords('Nusr-Et Burger', ['et']),
        isTrue,
      );

      // Substring rejection: 'et' in 'Lezzeti', 'Paket', 'Market'
      expect(
        PlacesController.matchesCategoryKeywords('Sokak Lezzeti Paketi', ['et']),
        isFalse,
      );

      // Multi-word keyword match
      expect(
        PlacesController.matchesCategoryKeywords('Anne Eli Ev Yemekleri Lokantası', ['ev yemekleri']),
        isTrue,
      );

      // Turkish non-ASCII character keyword match
      expect(
        PlacesController.matchesCategoryKeywords('Taze Demleme Çay Evi', ['çay']),
        isTrue,
      );
    });

    test('matchesCategory matches by exact label or word-boundary keywords', () {
      final restaurantCategory =
          PlaceCategoryFilter.allCategories.firstWhere((c) => c.id == 'restaurant');
      final fastFoodCategory =
          PlaceCategoryFilter.allCategories.firstWhere((c) => c.id == 'fast_food');

      final burgerPlace = _createTestPlace(
        id: 'b1',
        name: 'Burgerci',
        category: 'Burger & Sokak Lezzeti',
        subCategory: 'Fast Food',
        popularItems: const ['Burger', 'Patates'],
      );

      // Matches own label
      expect(PlacesController.matchesCategory(burgerPlace, fastFoodCategory), isTrue);

      // Does not falsely cross-match restaurant because 'et' is inside 'Lezzeti'
      expect(PlacesController.matchesCategory(burgerPlace, restaurantCategory), isFalse);
    });
  });
}
