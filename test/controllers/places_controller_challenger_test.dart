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
  double rating = 4.8,
  int reviewCount = 100,
  double latitude = 40.9862,
  double longitude = 29.0264,
  double distanceMeters = 200.0,
  String address = 'Moda Cd. No:1, Kadıköy/İstanbul',
  List<String> tags = const ['tatlı', 'pasta'],
  List<String> popularItems = const ['Cheesecake'],
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
  group('Empirical Challenge 1: Turkish Case Folding Matrix', () {
    test('Turkish character mapping primitives: I, İ, ı, i, Ç, Ğ, Ö, Ş, Ü', () {
      expect(PlacesController.turkishToLower('I'), equals('ı'));
      expect(PlacesController.turkishToLower('İ'), equals('i'));
      expect(PlacesController.turkishToLower('ı'), equals('ı'));
      expect(PlacesController.turkishToLower('i'), equals('i'));
      expect(PlacesController.turkishToLower('Ç'), equals('ç'));
      expect(PlacesController.turkishToLower('ç'), equals('ç'));
      expect(PlacesController.turkishToLower('Ğ'), equals('ğ'));
      expect(PlacesController.turkishToLower('ğ'), equals('ğ'));
      expect(PlacesController.turkishToLower('Ö'), equals('ö'));
      expect(PlacesController.turkishToLower('ö'), equals('ö'));
      expect(PlacesController.turkishToLower('Ş'), equals('ş'));
      expect(PlacesController.turkishToLower('ş'), equals('ş'));
      expect(PlacesController.turkishToLower('Ü'), equals('ü'));
      expect(PlacesController.turkishToLower('ü'), equals('ü'));
    });

    test('Mixed case full-word permutations', () {
      final cases = {
        'ISPARTA': 'ısparta',
        'Isparta': 'ısparta',
        'ısparta': 'ısparta',
        'İSTANBUL': 'istanbul',
        'İstanbul': 'istanbul',
        'istanbul': 'istanbul',
        'iSTANBUL': 'istanbul',
        'ÇITIR': 'çıtır',
        'Çıtır': 'çıtır',
        'çıtır': 'çıtır',
        'DÖNER': 'döner',
        'Döner': 'döner',
        'döner': 'döner',
        'KÜNEFE': 'künefe',
        'Künefe': 'künefe',
        'künefe': 'künefe',
        'ŞEKER': 'şeker',
        'Şeker': 'şeker',
        'şeker': 'şeker',
        'GÖZLEME': 'gözleme',
        'Gözleme': 'gözleme',
        'ÇAY': 'çay',
        'Çay': 'çay',
        'çay': 'çay',
        'TATLI': 'tatlı',
        'Tatlı': 'tatlı',
        'tatlı': 'tatlı',
        'FIRIN': 'fırın',
        'Fırın': 'fırın',
        'fırın': 'fırın',
        'AĞRI': 'ağrı',
        'Ağrı': 'ağrı',
        'ÖZEL SÜTLAÇ': 'özel sütlaç',
        'Özel Sütlaç': 'özel sütlaç',
        'ŞANLIURFA': 'şanlıurfa',
        'Şanlıurfa': 'şanlıurfa',
      };

      for (final entry in cases.entries) {
        expect(
          PlacesController.turkishToLower(entry.key),
          equals(entry.value),
          reason: 'Word "${entry.key}" should lowercase to "${entry.value}"',
        );
      }
    });

    test('Turkish search query matching against venue data with no false rejections', () {
      final targetVenue = _createPlace(
        id: 'target-1',
        name: 'Kadıköy Çıtır Fırın',
        category: 'Fırın & Kahvaltı',
        subCategory: 'Unlu Mamul',
        address: 'Caferağa Mah. Şair Nefi Sk. No:5, Kadıköy/İstanbul',
        popularItems: ['Çıtır Simit', 'Kıymalı Börek', 'Ispanaklı Poğaça', 'Sıcak Çay'],
        tags: ['fırın', 'kahvaltı', 'çay', 'simit', 'börek', 'ıspanaklı'],
      );

      final matchingQueries = [
        'ÇITIR',
        'çıtır',
        'Çıtır',
        'FIRIN',
        'fırın',
        'Fırın',
        'İSTANBUL',
        'istanbul',
        'İstanbul',
        'ISPANAKLI',
        'ıspanaklı',
        'Ispanaklı',
        'ŞAİR',
        'şair',
        'ŞAİR NEFİ',
        'KIYMALI',
        'kıymalı',
        'ÇAY',
        'çay',
        'SICAK ÇAY',
        'BÖREK',
        'börek',
        'CAFERAĞA',
        'caferağa',
      ];

      for (final query in matchingQueries) {
        final results = PlacesController.filterPlaces(
          places: [targetVenue],
          selectedCategoryId: 'all',
          radiusMeters: 500,
          minRating: 4.0,
          minReviewCount: 0,
          searchQuery: query,
          showFavoritesOnly: false,
          favoriteIds: {},
        );

        expect(
          results,
          hasLength(1),
          reason: 'Search query "$query" must match venue "${targetVenue.name}" without false rejection',
        );
      }

      // Negative queries must NOT match
      final nonMatchingQueries = [
        'ISPARTA',
        'KAHVE',
        'DÖNER',
        'PİZZA',
        'ÇITIRR',
      ];

      for (final query in nonMatchingQueries) {
        final results = PlacesController.filterPlaces(
          places: [targetVenue],
          selectedCategoryId: 'all',
          radiusMeters: 500,
          minRating: 4.0,
          minReviewCount: 0,
          searchQuery: query,
          showFavoritesOnly: false,
          favoriteIds: {},
        );

        expect(
          results,
          isEmpty,
          reason: 'Search query "$query" must NOT match venue "${targetVenue.name}"',
        );
      }
    });

    test('Special inputs and regex punctuation in search query do not crash', () {
      final targetVenue = _createPlace(
        id: 'spec-1',
        name: 'C++ & Dart Kafe (Moda)',
        category: 'Kahve & Kafe',
        subCategory: 'Kafe',
        address: 'Moda Cd. No:10 [Kadıköy]',
        tags: ['kahve', 'kod'],
        popularItems: ['Filtre Kahve + Kurabiye*'],
      );

      final trickyQueries = [
        '',
        '   ',
        'C++',
        '(Moda)',
        '[Kadıköy]',
        'Kurabiye*',
        'a+b',
        '\\',
        r'$',
        '^.*',
        '???',
      ];

      for (final q in trickyQueries) {
        expect(
          () => PlacesController.filterPlaces(
            places: [targetVenue],
            selectedCategoryId: 'all',
            radiusMeters: 500,
            minRating: 4.0,
            minReviewCount: 0,
            searchQuery: q,
            showFavoritesOnly: false,
            favoriteIds: {},
          ),
          returnsNormally,
          reason: 'Query "$q" must not crash filterPlaces',
        );
      }
    });
  });

  group('Empirical Challenge 2: Word-Boundary Category Keyword Matching', () {
    test('Keyword "et" does NOT match subwords (Lezzeti, Süpermarket, Paket, Ahmet, Buket, Net)', () {
      final falseMatchVenues = [
        _createPlace(
          id: 'v1',
          name: 'Burgerci',
          category: 'Burger & Sokak Lezzeti',
          subCategory: 'Fast Food',
          popularItems: ['Burger'],
        ),
        _createPlace(
          id: 'v2',
          name: 'Süpermarket Kafe',
          category: 'Diğer',
          subCategory: 'Market',
          popularItems: ['Bisküvi'],
        ),
        _createPlace(
          id: 'v3',
          name: 'Paket Servis Burger',
          category: 'Diğer',
          subCategory: 'Hızlı Servis',
          popularItems: ['Sandviç'],
        ),
        _createPlace(
          id: 'v4',
          name: 'Ahmet Usta Döner',
          category: 'Diğer',
          subCategory: 'Döner',
          popularItems: ['Döner'],
        ),
        _createPlace(
          id: 'v5',
          name: 'Buket Çiçek & Kafe',
          category: 'Diğer',
          subCategory: 'Çiçek',
          popularItems: ['Çay'],
        ),
        _createPlace(
          id: 'v6',
          name: 'Net Kafe İnternet',
          category: 'Diğer',
          subCategory: 'İnternet',
          popularItems: ['Meşrubat'],
        ),
        _createPlace(
          id: 'v7',
          name: 'Lezzet Diyarı Pide',
          category: 'Diğer',
          subCategory: 'Hamur İşi',
          popularItems: ['Pide'],
        ),
        _createPlace(
          id: 'v8',
          name: 'Kısmet Sandviç',
          category: 'Diğer',
          subCategory: 'Büfe',
          popularItems: ['Tost'],
        ),
      ];

      final restaurantCategory =
          PlaceCategoryFilter.allCategories.firstWhere((c) => c.id == 'restaurant');

      // None of the venues with "et" as a substring should match the restaurant category
      // (Note: v7 has 'pide', which is in restaurant keywords, so we exclude 'pide' in test setup)
      final nonRestaurantVenues = falseMatchVenues.where((v) => v.id != 'v7').toList();

      for (final venue in nonRestaurantVenues) {
        final matches = PlacesController.matchesCategory(venue, restaurantCategory);
        expect(
          matches,
          isFalse,
          reason: 'Venue "${venue.name}" (${venue.category}) must NOT match restaurant category via substring "et"',
        );
      }
    });

    test('Keyword "et" DOES match genuine occurrences with various delimiters', () {
      final validEtTexts = [
        'Taze Köfte ve Et Evi',
        'Et Lokantası',
        'Sadece Kırmızı Et',
        'Nusr-Et Burger',
        'Et & Balık Kurumu',
        'Köfte / Et Evi',
        '(Et) Cenneti',
        'Et, Tavuk, Balık',
        'Et! Mangal',
        '"Et" Restoranı',
        "'Et' Mangal",
        'Et: Lokantası',
        'Et; Mangal',
        'Et*Lezzet',
        'Et|Tavuk',
        'Et_Mangal',
        'Et+Balık',
      ];

      for (final text in validEtTexts) {
        expect(
          PlacesController.matchesCategoryKeywords(text, ['et']),
          isTrue,
          reason: 'Text "$text" must match keyword "et"',
        );
      }
    });

    test('Genuine Turkish keywords and compound phrases match properly', () {
      // çay
      expect(
        PlacesController.matchesCategoryKeywords('Rize Çay Evi', ['çay']),
        isTrue,
      );
      expect(
        PlacesController.matchesCategoryKeywords('Demlikte Çay', ['çay']),
        isTrue,
      );
      expect(
        PlacesController.matchesCategoryKeywords('Taze Sıcak ÇAY', ['çay']),
        isTrue,
      );

      // tatlı
      expect(
        PlacesController.matchesCategoryKeywords('Geleneksel Tatlı Dünyası', ['tatlı']),
        isTrue,
      );
      expect(
        PlacesController.matchesCategoryKeywords('Meşhur TATLI Salonu', ['tatlı']),
        isTrue,
      );

      // künefe
      expect(
        PlacesController.matchesCategoryKeywords('Antakya Künefe Evi', ['künefe']),
        isTrue,
      );
      expect(
        PlacesController.matchesCategoryKeywords('Sıcak KÜNEFE', ['künefe']),
        isTrue,
      );

      // compound: ev yemekleri
      expect(
        PlacesController.matchesCategoryKeywords('Anne Eli Ev Yemekleri Lokantası', ['ev yemekleri']),
        isTrue,
      );
      expect(
        PlacesController.matchesCategoryKeywords('Ev-Yemekleri Mutfağı', ['ev yemekleri']),
        isTrue,
      );

      // compound: fast_food
      expect(
        PlacesController.matchesCategoryKeywords('Cadde Fast Food Büfesi', ['fast_food']),
        isTrue,
      );
      expect(
        PlacesController.matchesCategoryKeywords('Fast-Food Express', ['fast_food']),
        isTrue,
      );
    });

    test('Subword protection on other keywords: balık vs Balıkesir, pasta vs Isparta', () {
      // balık in Balıkesir Mantıcısı
      expect(
        PlacesController.matchesCategoryKeywords('Balıkesir Mantıcısı', ['balık']),
        isFalse,
        reason: '"balık" should not match "Balıkesir"',
      );

      // pasta in Isparta Sofrası
      expect(
        PlacesController.matchesCategoryKeywords('Isparta Sofrası', ['pasta']),
        isFalse,
        reason: '"pasta" should not match "Isparta"',
      );

      // kafe in Diskafe
      expect(
        PlacesController.matchesCategoryKeywords('Diskafeterya', ['kafe']),
        isFalse,
        reason: '"kafe" should not match "Diskafeterya"',
      );
    });
  });

  group('Empirical Challenge 3: Adaptive Radius Search Query Integration', () {
    late FakePlacesRepository fakePlaces;
    late FakeStorageRepository fakeStorage;
    late PlacesController controller;

    final placeInside = _createPlace(
      id: 'p_inside',
      name: 'Kadıköy Waffle',
      category: 'Tatlı & Pastane',
      subCategory: 'Waffle',
      rating: 4.8,
      latitude: 40.9861,
      distanceMeters: 300.0,
      popularItems: ['Çikolatalı Waffle'],
    );

    final placeOutsideBaklava = _createPlace(
      id: 'p_outside_baklava',
      name: 'Moda Baklavacısı',
      category: 'Tatlı & Pastane',
      subCategory: 'Baklava',
      rating: 4.7,
      latitude: 40.9862,
      distanceMeters: 700.0,
      popularItems: ['Fıstıklı Baklava'],
    );

    final placeOutsideKunefe = _createPlace(
      id: 'p_outside_kunefe',
      name: 'Çıtır Künefe Evi',
      category: 'Tatlı & Pastane',
      subCategory: 'Künefe',
      rating: 4.9,
      latitude: 40.9863,
      distanceMeters: 1100.0,
      popularItems: ['Hatay Künefesi'],
    );

    final placeOutsideCoffee = _createPlace(
      id: 'p_outside_coffee',
      name: 'Çıtır Kahve Kavurucusu',
      category: 'Kahve & Kafe',
      subCategory: 'Kahve',
      rating: 4.9,
      latitude: 40.9864,
      distanceMeters: 900.0,
      popularItems: ['Espresso'],
    );

    final placeOutsideLowRating = _createPlace(
      id: 'p_outside_low_rating',
      name: 'Çıtır Dondurma',
      category: 'Tatlı & Pastane',
      subCategory: 'Dondurma',
      rating: 3.5,
      latitude: 40.9865,
      distanceMeters: 600.0,
      popularItems: ['Dondurma'],
    );

    setUp(() async {
      fakePlaces = FakePlacesRepository();
      fakeStorage = FakeStorageRepository();

      final allTestPlaces = [
        placeInside,
        placeOutsideLowRating,
        placeOutsideBaklava,
        placeOutsideCoffee,
        placeOutsideKunefe,
      ];

      fakePlaces.placesToReturn = allTestPlaces;
      fakePlaces.distanceCalculator = (lat1, lon1, lat2, lon2) {
        for (final p in allTestPlaces) {
          if (p.latitude == lat2 && p.longitude == lon2) {
            return p.distanceMeters;
          }
        }
        return 200.0;
      };

      controller = PlacesController(
        placesRepository: fakePlaces,
        storageRepository: fakeStorage,
        initialRadiusMeters: 500.0,
        initialCategoryId: 'dessert',
        initialMinRating: 4.5,
      );

      await controller.loadPlaces();
    });

    test('closestPlaceOutsideRadius returns null when filteredPlaces is not empty', () {
      // At radius 500m, placeInside (300m, 4.8, dessert) is within radius
      expect(controller.filteredPlaces, hasLength(1));
      expect(controller.closestPlaceOutsideRadius, isNull);
    });

    test('closestPlaceOutsideRadius respects active search query and skips closer non-matching venues', () {
      // Search for 'KÜNEFE' - placeInside does not match, so filteredPlaces is empty
      controller.setSearchQuery('KÜNEFE');
      expect(controller.filteredPlaces, isEmpty);

      // Outside radius candidates:
      // - 600m: Çıtır Dondurma (rating 3.5 < 4.5) -> skipped
      // - 700m: Moda Baklavacısı (doesn't match 'KÜNEFE') -> skipped
      // - 900m: Çıtır Kahve (category is coffee, not dessert) -> skipped
      // - 1100m: Çıtır Künefe Evi (rating 4.9, dessert, matches 'KÜNEFE') -> MATCH!
      final closest = controller.closestPlaceOutsideRadius;
      expect(closest, isNotNull);
      expect(closest!.id, equals('p_outside_kunefe'));
      expect(closest.distanceMeters, equals(1100.0));
      expect(closest.name, equals('Çıtır Künefe Evi'));
    });

    test('closestPlaceOutsideRadius applies Turkish case folding on search query', () {
      controller.setSearchQuery('ÇITIR');
      expect(controller.filteredPlaces, isEmpty);

      // Outside radius candidates matching 'ÇITIR':
      // - 600m: Çıtır Dondurma (excluded by rating 3.5 < 4.5)
      // - 900m: Çıtır Kahve (excluded by category 'dessert')
      // - 1100m: Çıtır Künefe Evi (matches category 'dessert', rating 4.9 >= 4.5, matches 'ÇITIR')
      final closest = controller.closestPlaceOutsideRadius;
      expect(closest, isNotNull);
      expect(closest!.id, equals('p_outside_kunefe'));
    });

    test('closestPlaceOutsideRadius returns null when no venue outside radius matches search query', () {
      controller.setSearchQuery('Astronot Dondurması');
      expect(controller.filteredPlaces, isEmpty);
      expect(controller.closestPlaceOutsideRadius, isNull);
    });

    test('expandRadiusToClosestPlace expands to encompass closest search result', () {
      controller.setSearchQuery('KÜNEFE');
      expect(controller.closestPlaceOutsideRadius!.id, equals('p_outside_kunefe'));

      // Closest is at 1100m. Expansion should set radius to 1100 + 50 = 1150m
      controller.expandRadiusToClosestPlace();
      expect(controller.radiusMeters, equals(1150.0));

      // Now placeOutsideKunefe is within radius (1100m <= 1150m)
      expect(controller.filteredPlaces, hasLength(1));
      expect(controller.filteredPlaces.first.id, equals('p_outside_kunefe'));

      // And closestPlaceOutsideRadius becomes null because filteredPlaces is no longer empty
      expect(controller.closestPlaceOutsideRadius, isNull);
    });

    test('findClosestPlaceOutsideRadius static method unit verification', () {
      final places = [
        placeInside,
        placeOutsideLowRating,
        placeOutsideBaklava,
        placeOutsideCoffee,
        placeOutsideKunefe,
      ];

      // Query: 'Baklava'
      final baklavaClosest = PlacesController.findClosestPlaceOutsideRadius(
        places: places,
        selectedCategoryId: 'dessert',
        radiusMeters: 500.0,
        minRating: 4.5,
        searchQuery: 'BAKLAVA',
      );
      expect(baklavaClosest, isNotNull);
      expect(baklavaClosest!.id, equals('p_outside_baklava'));
      expect(baklavaClosest.distanceMeters, equals(700.0));

      // Query: 'Kahve' when category is coffee
      final coffeeClosest = PlacesController.findClosestPlaceOutsideRadius(
        places: places,
        selectedCategoryId: 'coffee',
        radiusMeters: 500.0,
        minRating: 4.5,
        searchQuery: 'kahve',
      );
      expect(coffeeClosest, isNotNull);
      expect(coffeeClosest!.id, equals('p_outside_coffee'));
      expect(coffeeClosest.distanceMeters, equals(900.0));
    });
  });

  group('Empirical Challenge 4: Deep Adversarial & Boundary Stress', () {
    test('Boundary precision: candidate at exactly radiusMeters is within, radiusMeters + 0.01 is outside', () {
      final pExactRadius = _createPlace(
        id: 'p_exact',
        name: 'Sınır Pastanesi',
        distanceMeters: 500.0,
        rating: 4.8,
        latitude: 40.9801,
      );
      final pJustOutside = _createPlace(
        id: 'p_just_outside',
        name: 'Sınırın Ötesi Pastanesi',
        distanceMeters: 500.01,
        rating: 4.8,
        latitude: 40.9802,
      );

      // findClosestPlaceOutsideRadius requires strictly > radiusMeters
      final closest = PlacesController.findClosestPlaceOutsideRadius(
        places: [pExactRadius, pJustOutside],
        selectedCategoryId: 'dessert',
        radiusMeters: 500.0,
        minRating: 4.5,
      );

      expect(closest, isNotNull);
      expect(closest!.id, equals('p_just_outside'),
          reason: 'Venue at 500.0m is not outside 500.0m radius; venue at 500.01m is outside');
    });

    test('Rating boundary: candidate at exactly minRating qualifies, minRating - 0.01 rejected', () {
      final pExactRating = _createPlace(
        id: 'p_exact_rating',
        name: 'Tam Puan Pastane',
        distanceMeters: 600.0,
        rating: 4.5,
        latitude: 40.9803,
      );
      final pBelowRating = _createPlace(
        id: 'p_below_rating',
        name: 'Kıl Payı Pastane',
        distanceMeters: 550.0,
        rating: 4.49,
        latitude: 40.9804,
      );

      final closest = PlacesController.findClosestPlaceOutsideRadius(
        places: [pBelowRating, pExactRating],
        selectedCategoryId: 'dessert',
        radiusMeters: 500.0,
        minRating: 4.5,
      );

      expect(closest, isNotNull);
      expect(closest!.id, equals('p_exact_rating'),
          reason: '4.49 rating must be rejected even though closer (550m vs 600m)');
    });

    test('Turkish distinctions: ILIK vs İLİK do not falsely collide', () {
      expect(PlacesController.turkishToLower('ILIK SÜT'), equals('ılık süt'));
      expect(PlacesController.turkishToLower('İLİK ÇORBASI'), equals('ilik çorbası'));
      expect(
        PlacesController.turkishToLower('ILIK').contains(PlacesController.turkishToLower('İLİK')),
        isFalse,
      );
    });

    test('Delimiters: complex punctuation combinations around keywords', () {
      expect(
        PlacesController.matchesCategoryKeywords('...---Et___///', ['et']),
        isTrue,
      );
      expect(
        PlacesController.matchesCategoryKeywords('Restoran: (Nusr-Et) #1', ['et']),
        isTrue,
      );
      expect(
        PlacesController.matchesCategoryKeywords('Tavuk & Et; Kebap?', ['et']),
        isTrue,
      );
      expect(
        PlacesController.matchesCategoryKeywords('Lezzeti...Paketi...Marketi...', ['et']),
        isFalse,
      );
    });
  });
}

