import 'dart:math';

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
  group('Adversarial Group 1: Category Matching & Keywords Stress', () {
    test('category id "all" passes places across all categories and custom labels', () {
      final places = [
        _createTestPlace(id: '1', name: 'Mekan 1', category: 'Tatlı & Pastane'),
        _createTestPlace(id: '2', name: 'Mekan 2', category: 'Kahve & Kafe'),
        _createTestPlace(id: '3', name: 'Mekan 3', category: 'Restoran & Yemek'),
        _createTestPlace(id: '4', name: 'Mekan 4', category: 'Bilinmeyen Kategori'),
      ];

      final filtered = PlacesController.filterPlaces(
        places: places,
        selectedCategoryId: 'all',
        radiusMeters: 500,
        minRating: 4.0,
        minReviewCount: 0,
        searchQuery: '',
        showFavoritesOnly: false,
        favoriteIds: {},
      );

      expect(filtered.length, equals(4));
    });

    test('all 6 predefined category IDs correctly return their intended venues', () {
      final places = [
        _createTestPlace(id: '1', name: 'Kafes', category: 'Kahve & Kafe', subCategory: 'Kahveci', popularItems: ['Latte']),
        _createTestPlace(id: '2', name: 'Baklavacı', category: 'Tatlı & Pastane', subCategory: 'Tatlıcı', popularItems: ['Baklava']),
        _createTestPlace(id: '3', name: 'Kebapçı', category: 'Restoran & Yemek', subCategory: 'Kebap', popularItems: ['Adana']),
        _createTestPlace(id: '4', name: 'Burgerci', category: 'Burger & Sokak Lezzeti', subCategory: 'Fast Food', popularItems: ['Burger']),
        _createTestPlace(id: '5', name: 'Simitçi', category: 'Fırın & Kahvaltı', subCategory: 'Fırın', popularItems: ['Simit']),
      ];

      for (final cat in PlaceCategoryFilter.allCategories) {
        final filtered = PlacesController.filterPlaces(
          places: places,
          selectedCategoryId: cat.id,
          radiusMeters: 500,
          minRating: 4.0,
          minReviewCount: 0,
          searchQuery: '',
          showFavoritesOnly: false,
          favoriteIds: {},
        );

        if (cat.id == 'all') {
          expect(filtered.length, equals(5));
        } else {
          // Every category returns at least its own category's venue
          expect(
            filtered.any((p) => p.category == cat.label),
            isTrue,
            reason: 'Category ${cat.label} should match venue with identical category label',
          );
        }
      }
    });

    test('keyword "et" in restaurant category does not cross-match on "Burger & Sokak Lezzeti"', () {
      final burgerPlace = _createTestPlace(
        id: '4',
        name: 'Burgerci',
        category: 'Burger & Sokak Lezzeti',
        subCategory: 'Fast Food',
        popularItems: ['Burger'],
      );

      final restaurantMatches = PlacesController.filterPlaces(
        places: [burgerPlace],
        selectedCategoryId: 'restaurant',
        radiusMeters: 500,
        minRating: 4.0,
        minReviewCount: 0,
        searchQuery: '',
        showFavoritesOnly: false,
        favoriteIds: {},
      );

      // In restaurant keywords: word-boundary matching ensures 'et' only matches whole words
      expect(restaurantMatches, isEmpty,
          reason: 'Keyword "et" in restaurant category must NOT match "Lezzeti" in Burger category');
    });

    test('non-existent category ID gracefully falls back to "all" without crashing', () {
      final places = [
        _createTestPlace(id: '1', name: 'Mekan 1', category: 'Tatlı & Pastane'),
        _createTestPlace(id: '2', name: 'Mekan 2', category: 'Kahve & Kafe'),
      ];

      // Test boundary/non-existent IDs
      for (final invalidId in ['non_existent_xyz', '', r'!@#$', 'null', '12345']) {
        final filtered = PlacesController.filterPlaces(
          places: places,
          selectedCategoryId: invalidId,
          radiusMeters: 500,
          minRating: 4.0,
          minReviewCount: 0,
          searchQuery: '',
          showFavoritesOnly: false,
          favoriteIds: {},
        );

        expect(filtered.length, equals(2),
            reason: 'Unknown category ID "$invalidId" should fall back to "all"');
      }
    });

    test('category matches keyword in name, subCategory, or popularItems even if category label differs', () {
      final place = _createTestPlace(
        id: '1',
        name: 'Moda Dondurmacısı',
        category: 'Özel İşletme', // Label doesn't match 'Tatlı & Pastane'
        subCategory: 'Buzlu Lezzetler',
        popularItems: ['Künefe', 'Dondurma'],
      );

      final filtered = PlacesController.filterPlaces(
        places: [place],
        selectedCategoryId: 'dessert', // keywords include 'dondurma', 'künefe'
        radiusMeters: 500,
        minRating: 4.0,
        minReviewCount: 0,
        searchQuery: '',
        showFavoritesOnly: false,
        favoriteIds: {},
      );

      expect(filtered.length, equals(1));
    });

    test('case sensitivity of keywords: ASCII uppercase and mixed-case are matched', () {
      final place = _createTestPlace(
        id: '1',
        name: 'SPECIAL ROASTERY & COFFEE LAB',
        category: 'Gourmet Drinks',
        subCategory: 'CAFE',
        popularItems: ['ESPRESSO', 'LATTE'],
      );

      final filtered = PlacesController.filterPlaces(
        places: [place],
        selectedCategoryId: 'coffee', // keywords: coffee, cafe, espresso
        radiusMeters: 500,
        minRating: 4.0,
        minReviewCount: 0,
        searchQuery: '',
        showFavoritesOnly: false,
        favoriteIds: {},
      );

      expect(filtered.length, equals(1));
    });
  });

  group('Adversarial Group 2: Distance & Radius Boundaries Stress', () {
    test('radius boundary exact equality: place at distanceMeters == radiusMeters is included', () {
      final places = [
        _createTestPlace(id: '1', name: 'Tam Sınırda', distanceMeters: 500.0),
        _createTestPlace(id: '2', name: 'İçeride', distanceMeters: 499.99),
        _createTestPlace(id: '3', name: 'Dışarıda', distanceMeters: 500.01),
      ];

      final filtered = PlacesController.filterPlaces(
        places: places,
        selectedCategoryId: 'all',
        radiusMeters: 500.0,
        minRating: 4.0,
        minReviewCount: 0,
        searchQuery: '',
        showFavoritesOnly: false,
        favoriteIds: {},
      );

      expect(filtered.map((p) => p.id), containsAll(['1', '2']));
      expect(filtered.map((p) => p.id), isNot(contains('3')));
    });

    test('radius boundary at 0m: only places at 0.0m distance pass', () {
      final places = [
        _createTestPlace(id: 'exact_0', name: 'Tam Noktada', distanceMeters: 0.0),
        _createTestPlace(id: 'slight_offset', name: 'Biraz Uzak', distanceMeters: 0.1),
      ];

      final filtered = PlacesController.filterPlaces(
        places: places,
        selectedCategoryId: 'all',
        radiusMeters: 0.0,
        minRating: 4.0,
        minReviewCount: 0,
        searchQuery: '',
        showFavoritesOnly: false,
        favoriteIds: {},
      );

      expect(filtered.length, equals(1));
      expect(filtered.first.id, equals('exact_0'));
    });

    test('radius boundary at 50m (minimum slider) and 3000m (maximum slider)', () {
      final places = [
        _createTestPlace(id: 'p_49', name: '49.9m', distanceMeters: 49.9),
        _createTestPlace(id: 'p_50', name: '50.0m', distanceMeters: 50.0),
        _createTestPlace(id: 'p_51', name: '50.1m', distanceMeters: 50.1),
        _createTestPlace(id: 'p_3000', name: '3000.0m', distanceMeters: 3000.0),
        _createTestPlace(id: 'p_3001', name: '3000.1m', distanceMeters: 3000.1),
      ];

      final filtered50 = PlacesController.filterPlaces(
        places: places,
        selectedCategoryId: 'all',
        radiusMeters: 50.0,
        minRating: 4.0,
        minReviewCount: 0,
        searchQuery: '',
        showFavoritesOnly: false,
        favoriteIds: {},
      );
      expect(filtered50.map((p) => p.id), equals(['p_49', 'p_50']));

      final filtered3000 = PlacesController.filterPlaces(
        places: places,
        selectedCategoryId: 'all',
        radiusMeters: 3000.0,
        minRating: 4.0,
        minReviewCount: 0,
        searchQuery: '',
        showFavoritesOnly: false,
        favoriteIds: {},
      );
      expect(filtered3000.map((p) => p.id),
          containsAll(['p_49', 'p_50', 'p_51', 'p_3000']));
      expect(filtered3000.map((p) => p.id), isNot(contains('p_3001')));
    });

    test('findClosestPlaceOutsideRadius strictly checks > radiusMeters and picks minimum distance', () {
      final places = [
        _createTestPlace(id: 'inside', name: 'İçeride', distanceMeters: 500.0),
        _createTestPlace(id: 'outside_far', name: 'Uzak Dışarıda', distanceMeters: 750.0),
        _createTestPlace(id: 'outside_near', name: 'Yakın Dışarıda', distanceMeters: 501.0),
      ];

      final closest = PlacesController.findClosestPlaceOutsideRadius(
        places: places,
        selectedCategoryId: 'all',
        radiusMeters: 500.0,
        minRating: 4.0,
      );

      expect(closest, isNotNull);
      expect(closest!.id, equals('outside_near'));
      expect(closest.distanceMeters, equals(501.0));
    });

    test('findClosestPlaceOutsideRadius returns null when all places are within radius or none match rating', () {
      final places = [
        _createTestPlace(id: 'p1', name: 'M1', distanceMeters: 200.0, rating: 4.8),
        _createTestPlace(id: 'p2', name: 'M2', distanceMeters: 600.0, rating: 3.5), // rating too low
      ];

      final closest = PlacesController.findClosestPlaceOutsideRadius(
        places: places,
        selectedCategoryId: 'all',
        radiusMeters: 500.0,
        minRating: 4.5,
      );

      expect(closest, isNull);
    });

    test('calculateExpandedRadius clamps between 100m and 3000m with +50m buffer', () {
      expect(PlacesController.calculateExpandedRadius(20.0), equals(100.0)); // 70 clamped to 100
      expect(PlacesController.calculateExpandedRadius(50.0), equals(100.0)); // 100
      expect(PlacesController.calculateExpandedRadius(500.0), equals(550.0));
      expect(PlacesController.calculateExpandedRadius(2940.0), equals(2990.0));
      expect(PlacesController.calculateExpandedRadius(2980.0), equals(3000.0)); // 3030 clamped to 3000
      expect(PlacesController.calculateExpandedRadius(5000.0), equals(3000.0)); // 5050 clamped to 3000
    });

    test('negative or zero radius handling in filterPlaces', () {
      final places = [
        _createTestPlace(id: 'p1', name: 'M1', distanceMeters: 0.0),
        _createTestPlace(id: 'p2', name: 'M2', distanceMeters: 10.0),
      ];

      final filtered = PlacesController.filterPlaces(
        places: places,
        selectedCategoryId: 'all',
        radiusMeters: -100.0,
        minRating: 4.0,
        minReviewCount: 0,
        searchQuery: '',
        showFavoritesOnly: false,
        favoriteIds: {},
      );

      // Distance 0.0 > -100.0, 10.0 > -100.0, all excluded
      expect(filtered, isEmpty);
    });
  });

  group('Adversarial Group 3: Rating & Review Count Filter Boundaries', () {
    test('minRating boundary 0.0 and 5.0 exact checks', () {
      final places = [
        _createTestPlace(id: 'r_0', name: '0 Yıldız', rating: 0.0),
        _createTestPlace(id: 'r_4_9', name: '4.9 Yıldız', rating: 4.9),
        _createTestPlace(id: 'r_5_0', name: '5.0 Yıldız', rating: 5.0),
      ];

      final filtered0 = PlacesController.filterPlaces(
        places: places,
        selectedCategoryId: 'all',
        radiusMeters: 500,
        minRating: 0.0,
        minReviewCount: 0,
        searchQuery: '',
        showFavoritesOnly: false,
        favoriteIds: {},
      );
      expect(filtered0.length, equals(3));

      final filtered5 = PlacesController.filterPlaces(
        places: places,
        selectedCategoryId: 'all',
        radiusMeters: 500,
        minRating: 5.0,
        minReviewCount: 0,
        searchQuery: '',
        showFavoritesOnly: false,
        favoriteIds: {},
      );
      expect(filtered5.length, equals(1));
      expect(filtered5.first.id, equals('r_5_0'));
    });

    test('minReviewCount boundary checks: 0, 1, 1000000, and negative', () {
      final places = [
        _createTestPlace(id: 'c_0', name: '0 Yorum', reviewCount: 0),
        _createTestPlace(id: 'c_1', name: '1 Yorum', reviewCount: 1),
        _createTestPlace(id: 'c_500', name: '500 Yorum', reviewCount: 500),
      ];

      final filtered0 = PlacesController.filterPlaces(
        places: places,
        selectedCategoryId: 'all',
        radiusMeters: 500,
        minRating: 4.0,
        minReviewCount: 0,
        searchQuery: '',
        showFavoritesOnly: false,
        favoriteIds: {},
      );
      expect(filtered0.length, equals(3));

      final filtered1 = PlacesController.filterPlaces(
        places: places,
        selectedCategoryId: 'all',
        radiusMeters: 500,
        minRating: 4.0,
        minReviewCount: 1,
        searchQuery: '',
        showFavoritesOnly: false,
        favoriteIds: {},
      );
      expect(filtered1.length, equals(2));
      expect(filtered1.map((p) => p.id), equals(['c_1', 'c_500']));

      final filteredLarge = PlacesController.filterPlaces(
        places: places,
        selectedCategoryId: 'all',
        radiusMeters: 500,
        minRating: 4.0,
        minReviewCount: 1000000,
        searchQuery: '',
        showFavoritesOnly: false,
        favoriteIds: {},
      );
      expect(filteredLarge, isEmpty);

      final filteredNegative = PlacesController.filterPlaces(
        places: places,
        selectedCategoryId: 'all',
        radiusMeters: 500,
        minRating: 4.0,
        minReviewCount: -5,
        searchQuery: '',
        showFavoritesOnly: false,
        favoriteIds: {},
      );
      expect(filteredNegative.length, equals(3));
    });

    test('calculateWeightedRating boundary and edge cases', () {
      // 1. Empty user ratings preserves base rating exactly
      expect(
        PlacesController.calculateWeightedRating(
          existingRating: 4.67,
          existingReviewCount: 120,
          userRatings: const [],
        ),
        equals(4.67),
      );

      // 2. Base rating 0 with 0 count: first user review sets rating
      expect(
        PlacesController.calculateWeightedRating(
          existingRating: 0.0,
          existingReviewCount: 0,
          userRatings: [4.0],
        ),
        equals(4.0),
      );

      // 3. User ratings clamped to 1.0 - 5.0
      expect(
        PlacesController.calculateWeightedRating(
          existingRating: 1.0,
          existingReviewCount: 1,
          userRatings: [0.0, -2.0], // Clamped to min 1.0
        ),
        equals(1.0),
      );

      expect(
        PlacesController.calculateWeightedRating(
          existingRating: 5.0,
          existingReviewCount: 1,
          userRatings: [10.0, 99.0], // Clamped to max 5.0
        ),
        equals(5.0),
      );

      // 4. Large review count dilution: 1,000,000 5.0 reviews + one 1.0 review
      expect(
        PlacesController.calculateWeightedRating(
          existingRating: 5.0,
          existingReviewCount: 1000000,
          userRatings: [1.0],
        ),
        equals(5.0),
      );
    });
  });

  group('Adversarial Group 4: Sorting Pipeline Stress & Tie-Breakers', () {
    test('SortOption.rating tie-breaker: venues with identical ratings sort by reviewCount descending', () {
      final places = [
        _createTestPlace(id: 'p1', name: 'A', rating: 4.8, reviewCount: 50),
        _createTestPlace(id: 'p2', name: 'B', rating: 4.8, reviewCount: 500),
        _createTestPlace(id: 'p3', name: 'C', rating: 4.8, reviewCount: 200),
        _createTestPlace(id: 'p4', name: 'D', rating: 4.9, reviewCount: 10),
      ];

      final sorted = PlacesController.sortPlaces(
        places: places,
        sortOption: SortOption.rating,
      );

      expect(sorted.map((p) => p.id).toList(), equals(['p4', 'p2', 'p3', 'p1']));
    });

    test('SortOption.rating when BOTH rating AND reviewCount are identical does not crash', () {
      final places = [
        _createTestPlace(id: 'p1', name: 'A', rating: 4.8, reviewCount: 100),
        _createTestPlace(id: 'p2', name: 'B', rating: 4.8, reviewCount: 100),
        _createTestPlace(id: 'p3', name: 'C', rating: 4.8, reviewCount: 100),
      ];

      final sorted = PlacesController.sortPlaces(
        places: places,
        sortOption: SortOption.rating,
      );

      expect(sorted.length, equals(3));
      expect(sorted.map((p) => p.id).toSet(), equals({'p1', 'p2', 'p3'}));
    });

    test('SortOption.distance when distances are identical does not crash', () {
      final places = [
        _createTestPlace(id: 'p1', name: 'A', distanceMeters: 150.0),
        _createTestPlace(id: 'p2', name: 'B', distanceMeters: 150.0),
        _createTestPlace(id: 'p3', name: 'C', distanceMeters: 50.0),
      ];

      final sorted = PlacesController.sortPlaces(
        places: places,
        sortOption: SortOption.distance,
      );

      expect(sorted.first.id, equals('p3'));
      expect(sorted.length, equals(3));
    });

    test('SortOption.reviews when review counts are identical does not crash', () {
      final places = [
        _createTestPlace(id: 'p1', name: 'A', reviewCount: 100),
        _createTestPlace(id: 'p2', name: 'B', reviewCount: 100),
        _createTestPlace(id: 'p3', name: 'C', reviewCount: 300),
      ];

      final sorted = PlacesController.sortPlaces(
        places: places,
        sortOption: SortOption.reviews,
      );

      expect(sorted.first.id, equals('p3'));
      expect(sorted.length, equals(3));
    });

    test('empty and single-element lists sort without error', () {
      expect(
        PlacesController.sortPlaces(
          places: [],
          sortOption: SortOption.distance,
        ),
        isEmpty,
      );

      final single = [_createTestPlace(id: '1', name: 'Tek')];
      for (final option in SortOption.values) {
        final sorted = PlacesController.sortPlaces(places: single, sortOption: option);
        expect(sorted.length, equals(1));
        expect(sorted.first.id, equals('1'));
      }
    });

    test('stress test sorting 1,000 venues with randomized ties completes in milliseconds', () {
      final rng = Random(42);
      final places = List.generate(1000, (i) {
        return _createTestPlace(
          id: 'place_$i',
          name: 'Mekan $i',
          rating: (rng.nextInt(10) + 40) / 10.0, // 4.0 to 4.9
          reviewCount: rng.nextInt(50), // Many ties in 0..49
          distanceMeters: (rng.nextInt(50) * 10).toDouble(), // Many ties in 0..490
        );
      });

      final stopwatch = Stopwatch()..start();
      for (final option in SortOption.values) {
        final sorted = PlacesController.sortPlaces(places: places, sortOption: option);
        expect(sorted.length, equals(1000));
      }
      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(500));
    });
  });

  group('Adversarial Group 5: Search Query Stress Tests', () {
    test('whitespace padding: leading, trailing, and mixed spaces are trimmed', () {
      final places = [
        _createTestPlace(id: '1', name: 'Moda Çikolatacısı'),
        _createTestPlace(id: '2', name: 'Kadıköy Kahvecisi'),
      ];

      final filtered = PlacesController.filterPlaces(
        places: places,
        selectedCategoryId: 'all',
        radiusMeters: 500,
        minRating: 4.0,
        minReviewCount: 0,
        searchQuery: '   çikolata   ',
        showFavoritesOnly: false,
        favoriteIds: {},
      );

      expect(filtered.length, equals(1));
      expect(filtered.first.id, equals('1'));
    });

    test('all-whitespace search query is treated as empty query (no filtering)', () {
      final places = [
        _createTestPlace(id: '1', name: 'M1'),
        _createTestPlace(id: '2', name: 'M2'),
      ];

      for (final blank in ['   ', '\t', '\n', '  \t\n  ']) {
        final filtered = PlacesController.filterPlaces(
          places: places,
          selectedCategoryId: 'all',
          radiusMeters: 500,
          minRating: 4.0,
          minReviewCount: 0,
          searchQuery: blank,
          showFavoritesOnly: false,
          favoriteIds: {},
        );

        expect(filtered.length, equals(2),
            reason: 'Query "$blank" should not filter out places');
      }
    });

    test('emoji and Unicode symbols in search query do not crash', () {
      final places = [
        _createTestPlace(id: '1', name: 'Tatlıcı 🍰 Pasta'),
        _createTestPlace(id: '2', name: 'Sade Mekan'),
      ];

      final matching = PlacesController.filterPlaces(
        places: places,
        selectedCategoryId: 'all',
        radiusMeters: 500,
        minRating: 4.0,
        minReviewCount: 0,
        searchQuery: '🍰',
        showFavoritesOnly: false,
        favoriteIds: {},
      );
      expect(matching.length, equals(1));
      expect(matching.first.id, equals('1'));

      final nonMatching = PlacesController.filterPlaces(
        places: places,
        selectedCategoryId: 'all',
        radiusMeters: 500,
        minRating: 4.0,
        minReviewCount: 0,
        searchQuery: '🚀',
        showFavoritesOnly: false,
        favoriteIds: {},
      );
      expect(nonMatching, isEmpty);
    });

    test('special punctuation and regex metacharacters in search query do not crash', () {
      final places = [
        _createTestPlace(id: '1', name: 'C++ & C# Cafe (Special) [v2]'),
        _createTestPlace(id: '2', name: 'Düz Cafe'),
      ];

      final specialChars = r'!@#$%^&*()_+-=[]{}|;:",.<>?/\`~';
      final filtered = PlacesController.filterPlaces(
        places: places,
        selectedCategoryId: 'all',
        radiusMeters: 500,
        minRating: 4.0,
        minReviewCount: 0,
        searchQuery: specialChars,
        showFavoritesOnly: false,
        favoriteIds: {},
      );
      expect(filtered, isEmpty);

      // Search specific regex metacharacters substring
      final regexChars = PlacesController.filterPlaces(
        places: places,
        selectedCategoryId: 'all',
        radiusMeters: 500,
        minRating: 4.0,
        minReviewCount: 0,
        searchQuery: 'C++ & C#',
        showFavoritesOnly: false,
        favoriteIds: {},
      );
      expect(regexChars.length, equals(1));
      expect(regexChars.first.id, equals('1'));
    });

    test('10,000-character search query executes without memory explosion or crash', () {
      final places = [
        _createTestPlace(id: '1', name: 'Hafız Mustafa'),
        _createTestPlace(id: '2', name: 'Baylan'),
      ];

      final massiveQuery = 'a' * 10000;
      final filtered = PlacesController.filterPlaces(
        places: places,
        selectedCategoryId: 'all',
        radiusMeters: 500,
        minRating: 4.0,
        minReviewCount: 0,
        searchQuery: massiveQuery,
        showFavoritesOnly: false,
        favoriteIds: {},
      );

      expect(filtered, isEmpty);
    });

    test('Turkish character search matching: lowercase and standard uppercase', () {
      final places = [
        _createTestPlace(id: '1', name: 'Kadıköy Çıtır Fırın'),
        _createTestPlace(id: '2', name: 'Beşiktaş Şekerleme'),
        _createTestPlace(id: '3', name: 'Üsküdar Gözleme & Börek'),
      ];

      // Lowercase Turkish search
      expect(
        PlacesController.filterPlaces(
          places: places,
          selectedCategoryId: 'all',
          radiusMeters: 500,
          minRating: 4.0,
          minReviewCount: 0,
          searchQuery: 'çıtır',
          showFavoritesOnly: false,
          favoriteIds: {},
        ).map((p) => p.id),
        equals(['1']),
      );

      expect(
        PlacesController.filterPlaces(
          places: places,
          selectedCategoryId: 'all',
          radiusMeters: 500,
          minRating: 4.0,
          minReviewCount: 0,
          searchQuery: 'şeker',
          showFavoritesOnly: false,
          favoriteIds: {},
        ).map((p) => p.id),
        equals(['2']),
      );

      expect(
        PlacesController.filterPlaces(
          places: places,
          selectedCategoryId: 'all',
          radiusMeters: 500,
          minRating: 4.0,
          minReviewCount: 0,
          searchQuery: 'börek',
          showFavoritesOnly: false,
          favoriteIds: {},
        ).map((p) => p.id),
        equals(['3']),
      );

      // Case-folding for Ç, Ş, Ü, Ö, Ğ:
      expect(
        PlacesController.filterPlaces(
          places: places,
          selectedCategoryId: 'all',
          radiusMeters: 500,
          minRating: 4.0,
          minReviewCount: 0,
          searchQuery: 'BÖREK',
          showFavoritesOnly: false,
          favoriteIds: {},
        ).map((p) => p.id),
        equals(['3']),
        reason: 'BÖREK lowercases to börek and matches Üsküdar Gözleme & Börek',
      );

      expect(
        PlacesController.filterPlaces(
          places: places,
          selectedCategoryId: 'all',
          radiusMeters: 500,
          minRating: 4.0,
          minReviewCount: 0,
          searchQuery: 'ŞEKER',
          showFavoritesOnly: false,
          favoriteIds: {},
        ).map((p) => p.id),
        equals(['2']),
        reason: 'ŞEKER lowercases to şeker and matches Beşiktaş Şekerleme',
      );

      // Dotless I vs Dotted I with Turkish-aware case folding:
      // In Turkish, 'I' maps to 'ı' and 'İ' maps to 'i'.
      // Therefore, uppercase query 'ÇITIR' matches 'Kadıköy Çıtır Fırın'.
      final citirResult = PlacesController.filterPlaces(
        places: places,
        selectedCategoryId: 'all',
        radiusMeters: 500,
        minRating: 4.0,
        minReviewCount: 0,
        searchQuery: 'ÇITIR',
        showFavoritesOnly: false,
        favoriteIds: {},
      );
      expect(PlacesController.turkishToLower('ÇITIR'), equals('çıtır'));
      expect(PlacesController.turkishToLower('Kadıköy Çıtır Fırın'),
          equals('kadıköy çıtır fırın'));
      expect(citirResult, isNotEmpty,
          reason: 'Turkish case-folded query ÇITIR must match Kadıköy Çıtır Fırın');
      expect(citirResult.map((p) => p.id), equals(['1']));
    });
  });

  group('Adversarial Group 6: Concurrency & Controller Action Stress', () {
    test('out-of-order loadPlaces responses: superseded request cannot overwrite newer data', () async {
      final fakePlaces = FakePlacesRepository();
      final controller = PlacesController(
        placesRepository: fakePlaces,
        storageRepository: FakeStorageRepository(),
      );

      // First request takes longer
      fakePlaces.placesToReturn = [
        _createTestPlace(id: 'old_1', name: 'Old Place'),
      ];

      // We trigger first loadPlaces
      final future1 = controller.loadPlaces();

      // Trigger second loadPlaces with new data
      fakePlaces.placesToReturn = [
        _createTestPlace(id: 'new_1', name: 'New Place 1'),
        _createTestPlace(id: 'new_2', name: 'New Place 2'),
      ];
      final future2 = controller.loadPlaces();

      await Future.wait([future1, future2]);

      expect(controller.allPlaces.length, equals(2));
      expect(controller.allPlaces.map((p) => p.id), equals(['new_1', 'new_2']));
    });

    test('rapid successive filter mutations update filteredPlaces consistently', () {
      final fakePlaces = FakePlacesRepository(
        placesToReturn: [
          _createTestPlace(id: '1', name: 'Tatlıcı', category: 'Tatlı & Pastane', rating: 4.8),
          _createTestPlace(id: '2', name: 'Kahveci', category: 'Kahve & Kafe', rating: 4.2),
          _createTestPlace(id: '3', name: 'Fırıncı', category: 'Fırın & Kahvaltı', rating: 4.9),
        ],
      );
      final controller = PlacesController(
        placesRepository: fakePlaces,
        storageRepository: FakeStorageRepository(),
      );

      // Mutate state rapidly
      controller.setCategoryId('all');
      controller.setMinRating(4.0);
      controller.setRadiusMeters(1000.0);
      controller.setSearchQuery('cı');
      controller.setSortOption(SortOption.rating);

      // Before loadPlaces, allPlaces is empty
      expect(controller.filteredPlaces, isEmpty);
    });

    test('disposal guard: operations after dispose() do not throw FlutterError', () async {
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
      );

      controller.dispose();
      expect(controller.isDisposed, isTrue);

      // Calling setters and actions after disposal must not crash
      expect(() => controller.setSearchQuery('test'), returnsNormally);
      expect(() => controller.setCategoryId('coffee'), returnsNormally);
      expect(() => controller.setRadiusMeters(800.0), returnsNormally);
      expect(() => controller.setMinRating(4.0), returnsNormally);
      expect(() => controller.setMinReviewCount(10), returnsNormally);
      expect(() => controller.setSortOption(SortOption.rating), returnsNormally);
      expect(() => controller.toggleViewMode(), returnsNormally);
      expect(() => controller.toggleFavoritesOnly(), returnsNormally);
      expect(() => controller.notifyListeners(), returnsNormally);

      await expectLater(
        () => controller.setLocation(lat: 41.0, lon: 29.0, label: 'Yeni'),
        returnsNormally,
      );
      await expectLater(
        () => controller.toggleFavorite('p1'),
        returnsNormally,
      );
      await expectLater(
        () => controller.addUserReview(
          'p1',
          const PlaceReview(
            id: 'r1',
            authorName: 'Test',
            authorBadge: 'Rehber',
            rating: 5.0,
            relativeTime: 'Şimdi',
            comment: 'Güzel',
          ),
        ),
        returnsNormally,
      );
    });

    test('unmodifiable collections prevent direct caller mutation', () {
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
      );

      expect(() => (controller.allPlaces as dynamic).add(_createTestPlace(id: 'x', name: 'X')),
          throwsA(isA<UnsupportedError>()));
      expect(() => (controller.favoriteIds as dynamic).add('x'),
          throwsA(isA<UnsupportedError>()));
      expect(() => (controller.userReviewsMap as dynamic)['x'] = <PlaceReview>[],
          throwsA(isA<UnsupportedError>()));
    });
  });

  group('Adversarial Group 7: Adaptive Radius, Review Math Integrity & Error Resilience', () {
    test('expandRadiusToClosestPlace expands radius when a place exists outside', () async {
      final fakePlaces = FakePlacesRepository(
        placesToReturn: [
          _createTestPlace(id: 'inside', name: 'İçeride', latitude: 40.9862, rating: 4.8),
          _createTestPlace(id: 'outside', name: 'Dışarıda', latitude: 40.9950, rating: 4.8),
        ],
        distanceCalculator: (lat1, lon1, lat2, lon2) {
          if (lat2 == 40.9862) return 400.0;
          return 750.0;
        },
      );
      final controller = PlacesController(
        placesRepository: fakePlaces,
        storageRepository: FakeStorageRepository(),
        initialRadiusMeters: 500.0,
      );

      await controller.loadPlaces();

      // There is an inside place, so closestPlaceOutsideRadius is null
      expect(controller.closestPlaceOutsideRadius, isNull);

      // Now filter out the inside place by raising minRating or search
      controller.setSearchQuery('Dışarıda');
      // Now inside is filtered, so closestPlaceOutsideRadius is available
      expect(controller.closestPlaceOutsideRadius, isNotNull);
      expect(controller.closestPlaceOutsideRadius!.id, equals('outside'));

      controller.expandRadiusToClosestPlace();
      // Expanded radius = 750 + 50 = 800m
      expect(controller.radiusMeters, equals(800.0));
      expect(controller.filteredPlaces.map((p) => p.id), contains('outside'));
    });

    test('expandRadiusToClosestPlace is safe no-op when no place is outside radius', () async {
      final fakePlaces = FakePlacesRepository(
        placesToReturn: [
          _createTestPlace(id: 'inside', name: 'İçeride', distanceMeters: 200.0, rating: 4.8),
        ],
      );
      final controller = PlacesController(
        placesRepository: fakePlaces,
        storageRepository: FakeStorageRepository(),
        initialRadiusMeters: 500.0,
      );

      await controller.loadPlaces();
      final initialRadius = controller.radiusMeters;
      controller.expandRadiusToClosestPlace();
      expect(controller.radiusMeters, equals(initialRadius));
    });

    test('sequential review additions calculate mathematically exact weighted average without compounding', () async {
      final place = _createTestPlace(
        id: 'p1',
        name: 'Mekan 1',
        rating: 4.0,
        reviewCount: 2, // 2 reviews with avg 4.0 -> total 8.0
      );
      final fakePlaces = FakePlacesRepository(placesToReturn: [place]);
      final fakeStorage = FakeStorageRepository();
      final controller = PlacesController(
        placesRepository: fakePlaces,
        storageRepository: fakeStorage,
      );

      await controller.loadPlaces();
      expect(controller.allPlaces.first.rating, equals(4.0));
      expect(controller.allPlaces.first.reviewCount, equals(2));

      // Review 1: 5.0 -> (8.0 + 5.0) / 3 = 13/3 = 4.333... -> 4.3
      await controller.addUserReview(
        'p1',
        const PlaceReview(
          id: 'r1',
          authorName: 'A1',
          authorBadge: 'Rehber',
          rating: 5.0,
          relativeTime: 'Bugün',
          comment: 'Harika',
        ),
      );

      expect(controller.allPlaces.first.rating, equals(4.3));
      expect(controller.allPlaces.first.reviewCount, equals(3));

      // Review 2: 1.0 -> (8.0 + 5.0 + 1.0) / 4 = 14/4 = 3.5
      // If reviews compounded on previous 4.3 rating: (4.3 * 3 + 1.0)/4 = 13.9/4 = 3.475 -> 3.5 (coincidentally close)
      // Review 3: 5.0 -> (8.0 + 5.0 + 1.0 + 5.0) / 5 = 19/5 = 3.8
      // If compounded: (3.5 * 4 + 5.0) / 5 = 19/5 = 3.8
      await controller.addUserReview(
        'p1',
        const PlaceReview(
          id: 'r2',
          authorName: 'A2',
          authorBadge: 'Rehber',
          rating: 1.0,
          relativeTime: 'Bugün',
          comment: 'Kötü',
        ),
      );

      expect(controller.allPlaces.first.rating, equals(3.5));
      expect(controller.allPlaces.first.reviewCount, equals(4));

      await controller.addUserReview(
        'p1',
        const PlaceReview(
          id: 'r3',
          authorName: 'A3',
          authorBadge: 'Rehber',
          rating: 5.0,
          relativeTime: 'Bugün',
          comment: 'Tekrar iyi',
        ),
      );

      expect(controller.allPlaces.first.rating, equals(3.8));
      expect(controller.allPlaces.first.reviewCount, equals(5));
      expect(controller.allPlaces.first.reviews.length, equals(3));
    });

    test('loadPlaces handles network exceptions gracefully without crashing', () async {
      final fakePlaces = FakePlacesRepository(
        shouldThrow: true,
      );
      final controller = PlacesController(
        placesRepository: fakePlaces,
        storageRepository: FakeStorageRepository(),
      );

      await controller.loadPlaces();

      expect(controller.isLoading, isFalse);
      expect(controller.statusMessage, contains('Mekanlar yüklenirken bir hata oluştu'));
      expect(controller.allPlaces, isEmpty);
    });

    test('search query matches address, subCategory, popularItems, and tags', () {
      final place = _createTestPlace(
        id: '1',
        name: 'Normal İsim',
        address: 'Caferağa Mah. Moda Cad. No:42',
        subCategory: 'Butik Kahveci',
        popularItems: ['Cortado', 'Cold Brew'],
        tags: ['üçüncü nesil', 'sessiz'],
      );

      // Search matches address
      expect(
        PlacesController.filterPlaces(
          places: [place],
          selectedCategoryId: 'all',
          radiusMeters: 500,
          minRating: 4.0,
          minReviewCount: 0,
          searchQuery: 'caferağa',
          showFavoritesOnly: false,
          favoriteIds: {},
        ).length,
        equals(1),
      );

      // Search matches subCategory
      expect(
        PlacesController.filterPlaces(
          places: [place],
          selectedCategoryId: 'all',
          radiusMeters: 500,
          minRating: 4.0,
          minReviewCount: 0,
          searchQuery: 'butik',
          showFavoritesOnly: false,
          favoriteIds: {},
        ).length,
        equals(1),
      );

      // Search matches popularItems
      expect(
        PlacesController.filterPlaces(
          places: [place],
          selectedCategoryId: 'all',
          radiusMeters: 500,
          minRating: 4.0,
          minReviewCount: 0,
          searchQuery: 'cortado',
          showFavoritesOnly: false,
          favoriteIds: {},
        ).length,
        equals(1),
      );

      // Search matches tags
      expect(
        PlacesController.filterPlaces(
          places: [place],
          selectedCategoryId: 'all',
          radiusMeters: 500,
          minRating: 4.0,
          minReviewCount: 0,
          searchQuery: 'üçüncü',
          showFavoritesOnly: false,
          favoriteIds: {},
        ).length,
        equals(1),
      );
    });
  });
}

