import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekan_radari/controllers/places_controller.dart';
import 'package:mekan_radari/models/location_preset.dart';
import 'package:mekan_radari/models/place_model.dart';
import 'package:mekan_radari/screens/place_detail_sheet.dart';

import '../fakes/fake_places_repository.dart';
import '../fakes/fake_storage_repository.dart';

Place _createE2EPlace({
  required String id,
  required String name,
  String category = 'Tatlı & Pastane',
  String subCategory = 'Pastane',
  double rating = 4.8,
  int reviewCount = 120,
  double latitude = 40.9862,
  double longitude = 29.0264,
  double distanceMeters = 200.0,
  String address = 'Moda Caddesi No:42, Kadıköy/İstanbul',
  List<String> tags = const ['tatlı'],
  List<String> popularItems = const ['Profiterol'],
  List<PlaceReview> reviews = const [],
  Map<int, double> starDistribution = const {5: 0.8, 4: 0.15, 3: 0.05, 2: 0.0, 1: 0.0},
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
    phone: '+90 216 123 4567',
    website: 'https://mekan.example.com',
    openingHours: '09:00 - 23:00',
    isOpenNow: true,
    priceLevel: 2,
    tags: tags,
    popularItems: popularItems,
    reviews: reviews,
    starDistribution: starDistribution,
    dataSource: 'overpass',
  );
}

void main() {
  group('Tier 1: Feature Coverage E2E Suite', () {
    late FakePlacesRepository fakePlacesRepo;
    late FakeStorageRepository fakeStorageRepo;

    setUp(() {
      fakePlacesRepo = FakePlacesRepository();
      fakeStorageRepo = FakeStorageRepository();
    });

    test('F1 & F5: Initial Application State & Default Controller Setup', () {
      final controller = PlacesController(
        placesRepository: fakePlacesRepo,
        storageRepository: fakeStorageRepo,
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
    });

    test('F2 & F13: Storage Repository Initialization & Persisted Keys', () async {
      final initialFavs = {'place_101', 'place_202'};
      final initialReviews = {
        'place_101': [
          const PlaceReview(
            id: 'rev_1',
            authorName: 'Ahmet Yılmaz',
            authorBadge: 'Yerel Rehber',
            rating: 5.0,
            relativeTime: 'Dün',
            comment: 'Efsane lezzet!',
            isUserReview: true,
          ),
        ],
      };

      final storage = FakeStorageRepository(
        initialFavorites: initialFavs,
        initialReviews: initialReviews,
        initialGoogleApiKey: 'AIzaSyFakeKey123',
      );

      final controller = PlacesController(
        placesRepository: fakePlacesRepo,
        storageRepository: storage,
      );

      await controller.init();

      expect(controller.favoriteIds, containsAll(['place_101', 'place_202']));
      expect(controller.userReviewsMap.containsKey('place_101'), isTrue);
      expect(controller.userReviewsMap['place_101']!.first.comment, equals('Efsane lezzet!'));
      expect(controller.googleApiKey, equals('AIzaSyFakeKey123'));
    });

    test('F3: Location Preset Model & Standard Preset Locations', () {
      final presets = LocationPreset.popularLocations;
      expect(presets.length, greaterThanOrEqualTo(6));

      final kadikoy = presets.firstWhere((p) => p.name.contains('Kadıköy'));
      expect(kadikoy.latitude, closeTo(40.9862, 0.001));
      expect(kadikoy.longitude, closeTo(29.0264, 0.001));

      final besiktas = presets.firstWhere((p) => p.name.contains('Beşiktaş'));
      expect(besiktas.latitude, closeTo(41.0430, 0.001));
      expect(besiktas.longitude, closeTo(29.0053, 0.001));

      final ankara = presets.firstWhere((p) => p.name.contains('Ankara') || p.name.contains('Kızılay'));
      expect(ankara.latitude, closeTo(39.9082, 0.001));
    });

    test('F9: Radius Slider & Discrete Presets Clamping', () {
      final controller = PlacesController(
        placesRepository: fakePlacesRepo,
        storageRepository: fakeStorageRepo,
      );

      controller.setRadiusMeters(50.0);
      expect(controller.radiusMeters, equals(50.0));

      controller.setRadiusMeters(100.0);
      expect(controller.radiusMeters, equals(100.0));

      controller.setRadiusMeters(250.0);
      expect(controller.radiusMeters, equals(250.0));

      controller.setRadiusMeters(1000.0);
      expect(controller.radiusMeters, equals(1000.0));

      controller.setRadiusMeters(2500.0);
      expect(controller.radiusMeters, equals(2500.0));

      controller.setRadiusMeters(3000.0);
      expect(controller.radiusMeters, equals(3000.0));
    });

    test('F5 & F14: Category Filtering Across Standard Categories', () async {
      final venues = [
        _createE2EPlace(
          id: 'v1',
          name: 'Moda Çikolatacısı',
          category: 'Tatlı & Pastane',
          subCategory: 'Çikolata',
          popularItems: ['Sıcak Çikolata'],
          tags: ['tatlı'],
        ),
        _createE2EPlace(
          id: 'v2',
          name: 'Kahve Dünyası Roastery',
          category: 'Kahve & Kafe',
          subCategory: 'Kafe',
          popularItems: ['Espresso', 'Filtre Kahve'],
          tags: ['kahve'],
        ),
        _createE2EPlace(
          id: 'v3',
          name: 'Çiya Sofrası',
          category: 'Restoran & Yemek',
          subCategory: 'Kebap',
          popularItems: ['Adana Kebap', 'Lahmacun'],
          tags: ['restoran', 'kebap'],
        ),
        _createE2EPlace(
          id: 'v4',
          name: 'Basta Street Food',
          category: 'Burger & Sokak Lezzeti',
          subCategory: 'Dürüm',
          popularItems: ['Kuzu Dürüm', 'Burger'],
          tags: ['fast_food'],
        ),
        _createE2EPlace(
          id: 'v5',
          name: 'Tarihi Moda Fırını',
          category: 'Fırın & Kahvaltı',
          subCategory: 'Fırın',
          popularItems: ['Sıcak Simit', 'Kuru Poğaça'],
          tags: ['fırın'],
        ),
      ];

      fakePlacesRepo.placesToReturn = venues;
      final controller = PlacesController(
        placesRepository: fakePlacesRepo,
        storageRepository: fakeStorageRepo,
      );
      await controller.loadPlaces();

      // Default category: dessert
      expect(controller.filteredPlaces.map((p) => p.id), contains('v1'));
      expect(controller.filteredPlaces.map((p) => p.id), isNot(contains('v2')));

      // Switch to coffee
      controller.setCategoryId('coffee');
      expect(controller.filteredPlaces.map((p) => p.id), contains('v2'));
      expect(controller.filteredPlaces.map((p) => p.id), isNot(contains('v1')));

      // Switch to restaurant
      controller.setCategoryId('restaurant');
      expect(controller.filteredPlaces.map((p) => p.id), contains('v3'));

      // Switch to fast food
      controller.setCategoryId('fast_food');
      expect(controller.filteredPlaces.map((p) => p.id), contains('v4'));

      // Switch to bakery
      controller.setCategoryId('bakery');
      expect(controller.filteredPlaces.map((p) => p.id), contains('v5'));

      // Switch to all
      controller.setCategoryId('all');
      expect(controller.filteredPlaces.length, equals(5));
    });

    test('F5 & F14: Search Query Filtering with Turkish Case-Folding', () async {
      final venues = [
        _createE2EPlace(
          id: 'v1',
          name: 'İNCİ PASTANESİ',
          popularItems: ['Profiterol'],
        ),
        _createE2EPlace(
          id: 'v2',
          name: 'IŞIK FIRINI',
          popularItems: ['Ispanaklı Börek'],
        ),
      ];

      fakePlacesRepo.placesToReturn = venues;
      final controller = PlacesController(
        placesRepository: fakePlacesRepo,
        storageRepository: fakeStorageRepo,
        initialCategoryId: 'all',
      );
      await controller.loadPlaces();

      // Lowercase search for dotted 'i' -> 'inci'
      controller.setSearchQuery('inci');
      expect(controller.filteredPlaces.map((p) => p.id), contains('v1'));
      expect(controller.filteredPlaces.map((p) => p.id), isNot(contains('v2')));

      // Search with dotless 'ı' -> 'ışık'
      controller.setSearchQuery('ışık');
      expect(controller.filteredPlaces.map((p) => p.id), contains('v2'));
      expect(controller.filteredPlaces.map((p) => p.id), isNot(contains('v1')));

      // Uppercase search with 'I' -> should match 'IŞIK' / 'ispanaklı'
      controller.setSearchQuery('ISPANAKLI');
      expect(controller.filteredPlaces.map((p) => p.id), contains('v2'));
    });

    test('F5 & F14: Minimum Rating Filtering', () async {
      final venues = [
        _createE2EPlace(id: 'v1', name: 'Place 4.8', rating: 4.8),
        _createE2EPlace(id: 'v2', name: 'Place 4.5', rating: 4.5),
        _createE2EPlace(id: 'v3', name: 'Place 4.2', rating: 4.2),
        _createE2EPlace(id: 'v4', name: 'Place 3.9', rating: 3.9),
      ];

      fakePlacesRepo.placesToReturn = venues;
      final controller = PlacesController(
        placesRepository: fakePlacesRepo,
        storageRepository: fakeStorageRepo,
        initialCategoryId: 'all',
        initialMinRating: 4.5,
      );
      await controller.loadPlaces();

      // Rating >= 4.5
      expect(controller.filteredPlaces.map((p) => p.id), containsAll(['v1', 'v2']));
      expect(controller.filteredPlaces.map((p) => p.id), isNot(contains('v3')));

      // Increase threshold to 4.7
      controller.setMinRating(4.7);
      expect(controller.filteredPlaces.map((p) => p.id), contains('v1'));
      expect(controller.filteredPlaces.map((p) => p.id), isNot(contains('v2')));

      // Decrease threshold to 4.0
      controller.setMinRating(4.0);
      expect(controller.filteredPlaces.map((p) => p.id), containsAll(['v1', 'v2', 'v3']));
      expect(controller.filteredPlaces.map((p) => p.id), isNot(contains('v4')));
    });

    test('F5 & F14: Minimum Review Count Filtering', () async {
      final venues = [
        _createE2EPlace(id: 'v1', name: 'Popular', reviewCount: 500),
        _createE2EPlace(id: 'v2', name: 'Moderate', reviewCount: 80),
        _createE2EPlace(id: 'v3', name: 'New', reviewCount: 5),
      ];

      fakePlacesRepo.placesToReturn = venues;
      final controller = PlacesController(
        placesRepository: fakePlacesRepo,
        storageRepository: fakeStorageRepo,
        initialCategoryId: 'all',
        initialMinReviewCount: 0,
      );
      await controller.loadPlaces();

      expect(controller.filteredPlaces.length, equals(3));

      controller.setMinReviewCount(50);
      expect(controller.filteredPlaces.map((p) => p.id), containsAll(['v1', 'v2']));
      expect(controller.filteredPlaces.map((p) => p.id), isNot(contains('v3')));

      controller.setMinReviewCount(200);
      expect(controller.filteredPlaces.map((p) => p.id), contains('v1'));
      expect(controller.filteredPlaces.length, equals(1));
    });

    test('F5 & F14: Multi-Option Sorting (Distance, Rating, Reviews)', () async {
      final venues = [
        _createE2EPlace(id: 'v1', name: 'Near Low', latitude: 40.9870, rating: 4.5, reviewCount: 10),
        _createE2EPlace(id: 'v2', name: 'Mid High', latitude: 40.9880, rating: 4.9, reviewCount: 50),
        _createE2EPlace(id: 'v3', name: 'Far Most', latitude: 40.9890, rating: 4.9, reviewCount: 200),
      ];

      fakePlacesRepo.placesToReturn = venues;
      fakePlacesRepo.distanceCalculator = (lat1, lon1, lat2, lon2) {
        if (lat2 == 40.9870) return 100.0;
        if (lat2 == 40.9880) return 250.0;
        if (lat2 == 40.9890) return 450.0;
        return 0.0;
      };

      final controller = PlacesController(
        placesRepository: fakePlacesRepo,
        storageRepository: fakeStorageRepo,
        initialCategoryId: 'all',
        initialSortOption: SortOption.distance,
      );
      await controller.loadPlaces();

      // 1. Sort by Distance (asc)
      expect(controller.filteredPlaces.map((p) => p.id).toList(), equals(['v1', 'v2', 'v3']));

      // 2. Sort by Rating (desc, tie-breaker: reviewCount desc)
      controller.setSortOption(SortOption.rating);
      // v3 and v2 both 4.9, but v3 has 200 reviews > v2 (50 reviews)
      expect(controller.filteredPlaces.map((p) => p.id).toList(), equals(['v3', 'v2', 'v1']));

      // 3. Sort by Reviews (desc)
      controller.setSortOption(SortOption.reviews);
      expect(controller.filteredPlaces.map((p) => p.id).toList(), equals(['v3', 'v2', 'v1']));
    });

    test('F10: View Mode Toggle (Map vs List View)', () {
      final controller = PlacesController(
        placesRepository: fakePlacesRepo,
        storageRepository: fakeStorageRepo,
      );

      expect(controller.isMapView, isFalse);
      controller.toggleViewMode();
      expect(controller.isMapView, isTrue);
      controller.toggleViewMode();
      expect(controller.isMapView, isFalse);
    });

    test('F11 & F13: User Review Addition & Instant Weighted Average Rating', () async {
      final initialVenue = _createE2EPlace(
        id: 'place_star',
        name: 'Tatlıcı Ali',
        rating: 4.0,
        reviewCount: 4, // total points = 16.0
      );

      fakePlacesRepo.placesToReturn = [initialVenue];
      final controller = PlacesController(
        placesRepository: fakePlacesRepo,
        storageRepository: fakeStorageRepo,
        initialCategoryId: 'all',
        initialMinRating: 0.0,
      );
      await controller.loadPlaces();

      expect(controller.filteredPlaces.first.rating, equals(4.0));
      expect(controller.filteredPlaces.first.reviewCount, equals(4));

      // User adds a 5.0 star review
      // Expected new rating: (4.0 * 4 + 5.0) / 5 = 21.0 / 5 = 4.2
      const review = PlaceReview(
        id: 'user_rev_1',
        authorName: 'Can',
        authorBadge: 'Gezgin',
        rating: 5.0,
        relativeTime: 'Az önce',
        comment: 'Harika fıstıklı tatlılar!',
        isUserReview: true,
      );

      await controller.addUserReview('place_star', review);

      expect(controller.filteredPlaces.first.reviewCount, equals(5));
      expect(controller.filteredPlaces.first.rating, equals(4.2));

      // Verify persistence in fake storage
      final storedReviews = await fakeStorageRepo.getReviewsForPlace('place_star');
      expect(storedReviews.length, equals(1));
      expect(storedReviews.first.id, equals('user_rev_1'));
    });

    test('F12: Adaptive Radius Recommendation on Empty In-Radius Results', () async {
      final venues = [
        // Venue inside 500m radius but low rating 3.5 (filtered out)
        _createE2EPlace(id: 'v_low', name: 'Low', latitude: 40.9870, rating: 3.5),
        // Venue outside 500m radius matching rating 4.8 at 750m
        _createE2EPlace(id: 'v_far', name: 'Far Top', latitude: 40.9930, rating: 4.8),
        // Another venue outside at 900m
        _createE2EPlace(id: 'v_farther', name: 'Farther', latitude: 40.9950, rating: 4.9),
      ];

      fakePlacesRepo.placesToReturn = venues;
      fakePlacesRepo.distanceCalculator = (lat1, lon1, lat2, lon2) {
        if (lat2 == 40.9870) return 200.0;
        if (lat2 == 40.9930) return 750.0;
        if (lat2 == 40.9950) return 900.0;
        return 0.0;
      };

      final controller = PlacesController(
        placesRepository: fakePlacesRepo,
        storageRepository: fakeStorageRepo,
        initialRadiusMeters: 500.0,
        initialMinRating: 4.5,
        initialCategoryId: 'all',
      );
      await controller.loadPlaces();

      // In-radius matches are empty because v_low is 3.5 < 4.5
      expect(controller.filteredPlaces, isEmpty);

      // Adaptive recommendation detects v_far (closest matching venue outside radius)
      expect(controller.closestPlaceOutsideRadius, isNotNull);
      expect(controller.closestPlaceOutsideRadius!.id, equals('v_far'));

      // Trigger automatic expansion: (750 + 50) = 800m
      controller.expandRadiusToClosestPlace();

      expect(controller.radiusMeters, equals(800.0));
      // Now v_far is inside the active radius
      expect(controller.filteredPlaces.map((p) => p.id), contains('v_far'));
    });

    test('F1 & F14: Haversine Distance & Walking Duration Calculation', () {
      final repo = fakePlacesRepo;

      // Geodesic distance Kadıköy Moda (40.9862, 29.0264) to Beşiktaş (41.0430, 29.0053)
      final distance = repo.calculateDistance(40.9862, 29.0264, 41.0430, 29.0053);
      expect(distance, greaterThan(6400));
      expect(distance, lessThan(6700));

      final placeClose = _createE2EPlace(id: 'p1', name: 'Close', distanceMeters: 150);
      expect(placeClose.formattedDistance, equals('150 m'));
      // 150 / 75 = 2 minutes
      expect(placeClose.walkingMinutes, equals(2));

      final placeFar = _createE2EPlace(id: 'p2', name: 'Far', distanceMeters: 1850);
      expect(placeFar.formattedDistance, equals('1.85 km'));
      // 1850 / 75 = 24.66 -> ceil is 25 minutes
      expect(placeFar.walkingMinutes, equals(25));
    });

    testWidgets('F7, F8 & F11: PlaceDetailSheet Rendering & User Review Interaction', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final place = _createE2EPlace(
        id: 'place_sheet',
        name: 'Güllüoğlu Baklava',
        rating: 4.7,
        reviewCount: 350,
        reviews: [
          const PlaceReview(
            id: 'r_existing',
            authorName: 'Mert',
            authorBadge: 'Gurme',
            rating: 5.0,
            relativeTime: '2 gün önce',
            comment: 'Fıstığı çok bol!',
          ),
        ],
      );

      var favoriteToggled = false;
      PlaceReview? submittedReview;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaceDetailSheet(
              place: place,
              isFavorite: false,
              onToggleFavorite: () {
                favoriteToggled = true;
              },
              onAddReview: (review) {
                submittedReview = review;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify header and place metadata are rendered
      expect(find.text('Güllüoğlu Baklava'), findsOneWidget);
      expect(find.text('4.7'), findsOneWidget);
      expect(find.textContaining('350 değerlendirme'), findsOneWidget);
      expect(find.text('Fıstığı çok bol!'), findsOneWidget);

      // Tap favorite button
      final favButton = find.byIcon(Icons.favorite_border_rounded);
      expect(favButton, findsOneWidget);
      await tester.tap(favButton);
      await tester.pump();
      expect(favoriteToggled, isTrue);

      // Verify "Yorum Yaz" button exists
      final addReviewButton = find.text('Yorum Yaz');
      expect(addReviewButton, findsOneWidget);

      // Tap "Yorum Yaz" to open modal dialog
      await tester.tap(addReviewButton);
      await tester.pumpAndSettle();

      // Check modal inputs
      expect(find.textContaining('İçin Yorum Yaz'), findsOneWidget);
      final nameField = find.widgetWithText(TextField, 'Adınız (İsteğe bağlı)');
      final commentField = find.widgetWithText(TextField, 'Deneyiminizi ve önerdiğiniz lezzetleri paylaşın...');

      await tester.enterText(nameField, 'Ayşe Kaya');
      await tester.enterText(commentField, 'Kaymaklı baklavası harika!');
      await tester.pump();

      // Submit review
      final sendButton = find.text('Yorumu Yayınla');
      expect(sendButton, findsOneWidget);
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      // Verify callback received review
      expect(submittedReview, isNotNull);
      expect(submittedReview!.authorName, equals('Ayşe Kaya'));
      expect(submittedReview!.comment, equals('Kaymaklı baklavası harika!'));
      expect(submittedReview!.rating, equals(5.0));
    });
  });
}
