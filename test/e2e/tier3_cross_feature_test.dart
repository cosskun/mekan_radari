import 'package:flutter_test/flutter_test.dart';
import 'package:mekan_radari/controllers/places_controller.dart';
import 'package:mekan_radari/models/place_model.dart';

import '../fakes/fake_places_repository.dart';
import '../fakes/fake_storage_repository.dart';

Place _createCrossPlace({
  required String id,
  required String name,
  required String category,
  required String subCategory,
  required double rating,
  required int reviewCount,
  required double latitude,
  required double longitude,
  required double distanceMeters,
  List<String> tags = const [],
  List<String> popularItems = const [],
  String address = 'İstanbul, Türkiye',
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
    phone: null,
    website: null,
    openingHours: '08:00 - 23:00',
    isOpenNow: true,
    priceLevel: 2,
    tags: tags,
    popularItems: popularItems,
    reviews: const [],
    starDistribution: const {5: 0.9, 4: 0.1},
    dataSource: 'overpass',
  );
}

void main() {
  group('Tier 3: Cross-Feature Interactions E2E Suite', () {
    late FakePlacesRepository fakePlacesRepo;
    late FakeStorageRepository fakeStorageRepo;

    setUp(() {
      fakePlacesRepo = FakePlacesRepository();
      fakeStorageRepo = FakeStorageRepository();
    });

    test('Matrix 1: [Category: Coffee] + [Radius: 250m] + [MinRating: 4.8] + [Search: "Espresso"] + [Sort: Distance]', () async {
      final venues = [
        // Match: Coffee, 150m, 4.9, has Espresso
        _createCrossPlace(
          id: 'c1',
          name: 'Kronotrop Coffee Bar',
          category: 'Kahve & Kafe',
          subCategory: 'Kafe',
          rating: 4.9,
          reviewCount: 300,
          latitude: 40.9870,
          longitude: 29.0264,
          distanceMeters: 150.0,
          popularItems: ['Espresso Blend', 'V60'],
          tags: ['kahve', 'espresso'],
        ),
        // Match: Coffee, 220m, 4.8, has Espresso
        _createCrossPlace(
          id: 'c2',
          name: 'Coffee Manifesto',
          category: 'Kahve & Kafe',
          subCategory: 'Kafe',
          rating: 4.8,
          reviewCount: 150,
          latitude: 40.9880,
          longitude: 29.0264,
          distanceMeters: 220.0,
          popularItems: ['Double Espresso', 'Cold Brew'],
          tags: ['kahve'],
        ),
        // Reject: Coffee, 400m (outside 250m radius)
        _createCrossPlace(
          id: 'c3',
          name: 'Federal Coffee',
          category: 'Kahve & Kafe',
          subCategory: 'Kafe',
          rating: 4.9,
          reviewCount: 120,
          latitude: 40.9900,
          longitude: 29.0264,
          distanceMeters: 400.0,
          popularItems: ['Espresso'],
          tags: ['kahve'],
        ),
        // Reject: Coffee, 100m, but rating 4.6 (< 4.8)
        _createCrossPlace(
          id: 'c4',
          name: 'Corner Cafe',
          category: 'Kahve & Kafe',
          subCategory: 'Kafe',
          rating: 4.6,
          reviewCount: 80,
          latitude: 40.9865,
          longitude: 29.0264,
          distanceMeters: 100.0,
          popularItems: ['Espresso'],
          tags: ['kahve'],
        ),
        // Reject: Restaurant on Espresso Sokak (matches search query via address, but rejected by Coffee category)
        _createCrossPlace(
          id: 'c5',
          name: 'Kebapçı Mehmet',
          category: 'Restoran & Yemek',
          subCategory: 'Kebap',
          rating: 4.9,
          reviewCount: 500,
          latitude: 40.9866,
          longitude: 29.0264,
          distanceMeters: 120.0,
          popularItems: ['Urfa Kebap', 'Lahmacun'],
          tags: ['kebap'],
          address: 'Espresso Sokak No: 12, Kadıköy/İstanbul',
        ),
      ];

      fakePlacesRepo.placesToReturn = venues;
      fakePlacesRepo.distanceCalculator = (lat1, lon1, lat2, lon2) {
        if (lat2 == 40.9870) return 150.0;
        if (lat2 == 40.9880) return 220.0;
        if (lat2 == 40.9900) return 400.0;
        if (lat2 == 40.9865) return 100.0;
        if (lat2 == 40.9866) return 120.0;
        return 0.0;
      };

      final controller = PlacesController(
        placesRepository: fakePlacesRepo,
        storageRepository: fakeStorageRepo,
      );

      await controller.loadPlaces();

      // Apply Matrix 1 parameters
      controller.setCategoryId('coffee');
      controller.setRadiusMeters(250.0);
      controller.setMinRating(4.8);
      controller.setSearchQuery('Espresso');
      controller.setSortOption(SortOption.distance);

      final results = controller.filteredPlaces;

      // Only c1 and c2 satisfy ALL conditions
      expect(results.length, equals(2));
      expect(results[0].id, equals('c1')); // 150m < 220m
      expect(results[1].id, equals('c2'));
    });

    test('Matrix 2: [Favorites Only: True] + [Category: Dessert] + [Radius: 500m] + [Sort: Rating]', () async {
      final venues = [
        // Fav, Dessert, 4.7
        _createCrossPlace(
          id: 'fav_d1',
          name: 'Ali Usta Dondurma',
          category: 'Tatlı & Pastane',
          subCategory: 'Dondurma',
          rating: 4.7,
          reviewCount: 400,
          latitude: 40.9870,
          longitude: 29.0264,
          distanceMeters: 200.0,
          popularItems: ['Dondurma'],
          tags: ['tatlı'],
        ),
        // Fav, Dessert, 4.9 (higher rating)
        _createCrossPlace(
          id: 'fav_d2',
          name: 'Çikolata Dükkanı',
          category: 'Tatlı & Pastane',
          subCategory: 'Çikolata',
          rating: 4.9,
          reviewCount: 250,
          latitude: 40.9880,
          longitude: 29.0264,
          distanceMeters: 300.0,
          popularItems: ['Asuman Tatlısı'],
          tags: ['tatlı'],
        ),
        // Not Favorite, Dessert, 5.0 (Should be EXCLUDED despite high rating)
        _createCrossPlace(
          id: 'not_fav',
          name: 'Muhteşem Baklava',
          category: 'Tatlı & Pastane',
          subCategory: 'Pastane',
          rating: 5.0,
          reviewCount: 800,
          latitude: 40.9865,
          longitude: 29.0264,
          distanceMeters: 100.0,
          popularItems: ['Baklava'],
          tags: ['tatlı'],
        ),
        // Fav, Coffee, 4.9 (Should be EXCLUDED by category)
        _createCrossPlace(
          id: 'fav_coffee',
          name: 'Kahve Kulübü',
          category: 'Kahve & Kafe',
          subCategory: 'Kafe',
          rating: 4.9,
          reviewCount: 150,
          latitude: 40.9875,
          longitude: 29.0264,
          distanceMeters: 180.0,
          popularItems: ['Filtre Kahve'],
          tags: ['kahve'],
        ),
      ];

      fakePlacesRepo.placesToReturn = venues;
      fakePlacesRepo.distanceCalculator = (lat1, lon1, lat2, lon2) {
        if (lat2 == 40.9870) return 200.0;
        if (lat2 == 40.9880) return 300.0;
        if (lat2 == 40.9865) return 100.0;
        if (lat2 == 40.9875) return 180.0;
        return 0.0;
      };

      // Set favorites in storage
      final storage = FakeStorageRepository(
        initialFavorites: {'fav_d1', 'fav_d2', 'fav_coffee'},
      );

      final controller = PlacesController(
        placesRepository: fakePlacesRepo,
        storageRepository: storage,
      );

      await controller.init();

      controller.setCategoryId('dessert');
      controller.setRadiusMeters(500.0);
      controller.setMinRating(4.0);
      controller.toggleFavoritesOnly();
      controller.setSortOption(SortOption.rating);

      final results = controller.filteredPlaces;

      // Only fav_d2 (4.9) and fav_d1 (4.7) match
      expect(results.length, equals(2));
      expect(results[0].id, equals('fav_d2')); // 4.9 > 4.7
      expect(results[1].id, equals('fav_d1'));
    });

    test('Matrix 3: [Category: Restaurant] + [Search: "Kebap"] + [MinReviewCount: 50] + [Sort: Reviews]', () async {
      final venues = [
        _createCrossPlace(
          id: 'r1',
          name: 'Kebapçı Halil',
          category: 'Restoran & Yemek',
          subCategory: 'Kebap',
          rating: 4.8,
          reviewCount: 350,
          latitude: 40.9870,
          longitude: 29.0264,
          distanceMeters: 250.0,
          popularItems: ['Urfa Kebap', 'Küşleme'],
          tags: ['kebap'],
        ),
        _createCrossPlace(
          id: 'r2',
          name: 'Adana Ocakbaşı',
          category: 'Restoran & Yemek',
          subCategory: 'Kebap',
          rating: 4.7,
          reviewCount: 950,
          latitude: 40.9880,
          longitude: 29.0264,
          distanceMeters: 350.0,
          popularItems: ['Adana Kebap', 'Çöp Şiş'],
          tags: ['kebap'],
        ),
        // Filtered out: only 20 reviews (< 50)
        _createCrossPlace(
          id: 'r3',
          name: 'Yeni Kebap Evi',
          category: 'Restoran & Yemek',
          subCategory: 'Kebap',
          rating: 4.9,
          reviewCount: 20,
          latitude: 40.9875,
          longitude: 29.0264,
          distanceMeters: 180.0,
          popularItems: ['Beyti Kebap'],
          tags: ['kebap'],
        ),
      ];

      fakePlacesRepo.placesToReturn = venues;
      fakePlacesRepo.distanceCalculator = (lat1, lon1, lat2, lon2) {
        if (lat2 == 40.9870) return 250.0;
        if (lat2 == 40.9880) return 350.0;
        if (lat2 == 40.9875) return 180.0;
        return 0.0;
      };

      final controller = PlacesController(
        placesRepository: fakePlacesRepo,
        storageRepository: fakeStorageRepo,
      );

      await controller.loadPlaces();

      controller.setCategoryId('restaurant');
      controller.setSearchQuery('Kebap');
      controller.setMinReviewCount(50);
      controller.setSortOption(SortOption.reviews);

      final results = controller.filteredPlaces;

      expect(results.length, equals(2));
      // r2 has 950 reviews > r1 with 350 reviews
      expect(results[0].id, equals('r2'));
      expect(results[1].id, equals('r1'));
    });

    test('Matrix 4: [Search: Turkish "Şekerci"] + [Radius: 1000m] + [Review Added] + [Dynamic Recalculation]', () async {
      final initialVenue = _createCrossPlace(
        id: 'sek_1',
        name: 'Tarihi Moda Şekercisi',
        category: 'Tatlı & Pastane',
        subCategory: 'Şekerleme',
        rating: 4.4, // initially below 4.5
        reviewCount: 1, // point = 4.4
        latitude: 40.9870,
        longitude: 29.0264,
        distanceMeters: 600.0,
        popularItems: ['Akide Şekeri', 'Lokum'],
        tags: ['tatlı', 'şeker'],
      );

      fakePlacesRepo.placesToReturn = [initialVenue];
      fakePlacesRepo.distanceCalculator = (lat1, lon1, lat2, lon2) => 600.0;

      final controller = PlacesController(
        placesRepository: fakePlacesRepo,
        storageRepository: fakeStorageRepo,
        initialRadiusMeters: 1000.0,
        initialMinRating: 4.5,
      );

      await controller.loadPlaces();
      controller.setSearchQuery('şekerci');

      // Venue rating 4.4 is < 4.5 minRating -> not in filtered list
      expect(controller.filteredPlaces, isEmpty);

      // Add a 5-star user review: (4.4 * 1 + 5.0) / 2 = 9.4 / 2 = 4.7
      await controller.addUserReview(
        'sek_1',
        const PlaceReview(
          id: 'user_sek',
          authorName: 'Elif',
          authorBadge: 'Yerel Rehber',
          rating: 5.0,
          relativeTime: 'Şimdi',
          comment: 'Harika akide şekerleri!',
          isUserReview: true,
        ),
      );

      // Now rating is 4.7 >= 4.5 -> Venue enters filtered list immediately!
      expect(controller.filteredPlaces.length, equals(1));
      expect(controller.filteredPlaces.first.id, equals('sek_1'));
      expect(controller.filteredPlaces.first.rating, equals(4.7));
      expect(controller.filteredPlaces.first.reviewCount, equals(2));
    });

    test('Matrix 5: [Location Relocated to Beşiktaş] + [Category: Bakery] + [MinRating: 4.0] + [Favorites Filter Active]', () async {
      final besiktasVenues = [
        _createCrossPlace(
          id: 'b_bakery_fav',
          name: 'Karaköy Güllüoğlu Beşiktaş',
          category: 'Fırın & Kahvaltı',
          subCategory: 'Fırın',
          rating: 4.6,
          reviewCount: 300,
          latitude: 41.0435,
          longitude: 29.0055,
          distanceMeters: 100.0,
          popularItems: ['Kruvasan', 'Simit'],
          tags: ['fırın'],
        ),
        _createCrossPlace(
          id: 'b_bakery_not_fav',
          name: 'Mahalle Fırını',
          category: 'Fırın & Kahvaltı',
          subCategory: 'Fırın',
          rating: 4.8,
          reviewCount: 150,
          latitude: 41.0440,
          longitude: 29.0060,
          distanceMeters: 150.0,
          popularItems: ['Ekmek'],
          tags: ['fırın'],
        ),
      ];

      fakePlacesRepo.placesToReturn = besiktasVenues;
      fakePlacesRepo.distanceCalculator = (lat1, lon1, lat2, lon2) {
        if (lat2 == 41.0435) return 100.0;
        if (lat2 == 41.0440) return 150.0;
        return 0.0;
      };

      final storage = FakeStorageRepository(
        initialFavorites: {'b_bakery_fav'},
      );

      final controller = PlacesController(
        placesRepository: fakePlacesRepo,
        storageRepository: storage,
      );

      await controller.init();

      // Relocate center to Beşiktaş
      await controller.setLocation(
        lat: 41.0430,
        lon: 29.0053,
        label: 'Beşiktaş - Çarşı & Akaretler',
      );

      controller.setCategoryId('bakery');
      controller.setMinRating(4.0);
      controller.toggleFavoritesOnly();

      expect(controller.centerLat, equals(41.0430));
      expect(controller.locationLabel, equals('Beşiktaş - Çarşı & Akaretler'));

      final results = controller.filteredPlaces;
      expect(results.length, equals(1));
      expect(results.first.id, equals('b_bakery_fav'));
    });

    test('Matrix 6: Dynamic Sorting Invariance (Order changes, total members remain invariant)', () async {
      final venues = [
        _createCrossPlace(
          id: 'p1',
          name: 'Place Alpha',
          category: 'Tatlı & Pastane',
          subCategory: 'Pastane',
          rating: 4.5,
          reviewCount: 50,
          latitude: 40.9870,
          longitude: 29.0264,
          distanceMeters: 100.0,
          popularItems: ['Baklava'],
        ),
        _createCrossPlace(
          id: 'p2',
          name: 'Place Beta',
          category: 'Tatlı & Pastane',
          subCategory: 'Pastane',
          rating: 4.9,
          reviewCount: 20,
          latitude: 40.9880,
          longitude: 29.0264,
          distanceMeters: 300.0,
          popularItems: ['Baklava'],
        ),
        _createCrossPlace(
          id: 'p3',
          name: 'Place Gamma',
          category: 'Tatlı & Pastane',
          subCategory: 'Pastane',
          rating: 4.7,
          reviewCount: 300,
          latitude: 40.9890,
          longitude: 29.0264,
          distanceMeters: 200.0,
          popularItems: ['Baklava'],
        ),
      ];

      fakePlacesRepo.placesToReturn = venues;
      fakePlacesRepo.distanceCalculator = (lat1, lon1, lat2, lon2) {
        if (lat2 == 40.9870) return 100.0;
        if (lat2 == 40.9880) return 300.0;
        if (lat2 == 40.9890) return 200.0;
        return 0.0;
      };

      final controller = PlacesController(
        placesRepository: fakePlacesRepo,
        storageRepository: fakeStorageRepo,
        initialCategoryId: 'all',
      );

      await controller.loadPlaces();

      // 1. Sort by Distance
      controller.setSortOption(SortOption.distance);
      final byDistance = controller.filteredPlaces.map((p) => p.id).toList();
      expect(byDistance, equals(['p1', 'p3', 'p2'])); // 100m, 200m, 300m

      // 2. Sort by Rating
      controller.setSortOption(SortOption.rating);
      final byRating = controller.filteredPlaces.map((p) => p.id).toList();
      expect(byRating, equals(['p2', 'p3', 'p1'])); // 4.9, 4.7, 4.5

      // 3. Sort by Reviews
      controller.setSortOption(SortOption.reviews);
      final byReviews = controller.filteredPlaces.map((p) => p.id).toList();
      expect(byReviews, equals(['p3', 'p1', 'p2'])); // 300, 50, 20

      // Invariance check: Set of IDs in all 3 sorting modes is identical
      expect(byDistance.toSet(), equals(byRating.toSet()));
      expect(byRating.toSet(), equals(byReviews.toSet()));
    });
  });
}
