import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekan_radari/controllers/places_controller.dart';
import 'package:mekan_radari/models/location_preset.dart';
import 'package:mekan_radari/models/place_model.dart';
import 'package:mekan_radari/screens/place_detail_sheet.dart';

import '../fakes/fake_places_repository.dart';
import '../fakes/fake_storage_repository.dart';

Place _createJourneyPlace({
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
  List<PlaceReview> reviews = const [],
  String address = 'Moda, Kadıköy/İstanbul',
  String? customGoogleMapsUri,
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
    phone: '+90 216 555 1234',
    website: 'https://mekan.example.com',
    openingHours: '09:00 - 23:00',
    isOpenNow: true,
    priceLevel: 2,
    tags: tags,
    popularItems: popularItems,
    reviews: reviews,
    starDistribution: const {5: 0.8, 4: 0.2},
    dataSource: 'overpass',
    customGoogleMapsUri: customGoogleMapsUri,
  );
}

void main() {
  group('Tier 4: Real-World Workloads & User Journeys E2E Suite', () {
    late FakePlacesRepository fakePlacesRepo;
    late FakeStorageRepository fakeStorageRepo;

    setUp(() {
      fakePlacesRepo = FakePlacesRepository();
      fakeStorageRepo = FakeStorageRepository();
    });

    testWidgets('Journey 1: The Kadıköy Dessert Connoisseur & Foodie Tour', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // 1. Initial venue catalog in Kadıköy Moda
      final venues = [
        _createJourneyPlace(
          id: 'kad_baklava',
          name: 'Gaziantep Hacı Baba Baklavacısı',
          category: 'Tatlı & Pastane',
          subCategory: 'Baklava',
          rating: 4.7,
          reviewCount: 300,
          latitude: 40.9870,
          longitude: 29.0264,
          distanceMeters: 220.0,
          popularItems: ['Fıstıklı Baklava', 'Şöbiyet'],
          tags: ['tatlı', 'baklava'],
          reviews: [
            const PlaceReview(
              id: 'rev_exist',
              authorName: 'Murat',
              authorBadge: 'Yerel Rehber',
              rating: 5.0,
              relativeTime: 'Geçen hafta',
              comment: 'Çıtır çıtır taze baklava.',
            ),
          ],
        ),
        _createJourneyPlace(
          id: 'kad_dondurma',
          name: 'Moda Dondurmacısı',
          category: 'Tatlı & Pastane',
          subCategory: 'Dondurma',
          rating: 4.8,
          reviewCount: 450,
          latitude: 40.9875,
          longitude: 29.0264,
          distanceMeters: 180.0,
          popularItems: ['Kaymaklı Dondurma'],
          tags: ['tatlı'],
        ),
        _createJourneyPlace(
          id: 'kad_kahve',
          name: 'Moda Kahvesi',
          category: 'Kahve & Kafe',
          subCategory: 'Kafe',
          rating: 4.6,
          reviewCount: 200,
          latitude: 40.9880,
          longitude: 29.0264,
          distanceMeters: 250.0,
          popularItems: ['Türk Kahvesi'],
          tags: ['kahve'],
        ),
      ];

      fakePlacesRepo.placesToReturn = venues;
      fakePlacesRepo.distanceCalculator = (lat1, lon1, lat2, lon2) {
        if (lat2 == 40.9870) return 220.0;
        if (lat2 == 40.9875) return 180.0;
        if (lat2 == 40.9880) return 250.0;
        return 0.0;
      };

      final controller = PlacesController(
        placesRepository: fakePlacesRepo,
        storageRepository: fakeStorageRepo,
      );

      // Initialize controller
      await controller.init();

      // Step 1: Verify Kadıköy initial state (Moda, 500m radius, dessert category)
      expect(controller.locationLabel, equals('Kadıköy - Moda & Çarşı'));
      expect(controller.selectedCategoryId, equals('dessert'));
      expect(controller.radiusMeters, equals(500.0));
      expect(controller.filteredPlaces.length, equals(2)); // baklava and dondurma (coffee excluded)

      // Step 2: Search for "Baklava"
      controller.setSearchQuery('Baklava');
      expect(controller.filteredPlaces.length, equals(1));
      final selectedPlace = controller.filteredPlaces.first;
      expect(selectedPlace.id, equals('kad_baklava'));

      // Step 3: Open PlaceDetailSheet widget for this venue
      var favoriteToggled = false;
      PlaceReview? addedReview;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaceDetailSheet(
              place: selectedPlace,
              isFavorite: controller.isFavorite(selectedPlace.id),
              onToggleFavorite: () async {
                favoriteToggled = true;
                await controller.toggleFavorite(selectedPlace.id);
              },
              onAddReview: (review) async {
                addedReview = review;
                await controller.addUserReview(selectedPlace.id, review);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify sheet shows place details
      expect(find.text('Gaziantep Hacı Baba Baklavacısı'), findsOneWidget);
      expect(find.text('4.7'), findsOneWidget);
      expect(find.text('Çıtır çıtır taze baklava.'), findsOneWidget);

      // Step 4: Toggle favorite heart
      final favButton = find.byIcon(Icons.favorite_border_rounded);
      expect(favButton, findsOneWidget);
      await tester.tap(favButton);
      await tester.pump();

      expect(favoriteToggled, isTrue);
      expect(controller.isFavorite('kad_baklava'), isTrue);

      // Step 5: Submit a 5-star review via "Yorum Yaz" modal
      final addReviewButton = find.text('Yorum Yaz');
      await tester.tap(addReviewButton);
      await tester.pumpAndSettle();

      final nameField = find.widgetWithText(TextField, 'Adınız (İsteğe bağlı)');
      final commentField = find.widgetWithText(TextField, 'Deneyiminizi ve önerdiğiniz lezzetleri paylaşın...');
      await tester.enterText(nameField, 'Selin Yılmaz');
      await tester.enterText(commentField, 'Harika çıtır fıstıklı baklava!');
      await tester.pump();

      final sendButton = find.text('Yorumu Yayınla');
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      expect(addedReview, isNotNull);
      expect(addedReview!.comment, equals('Harika çıtır fıstıklı baklava!'));

      // Step 6: Verify updated rating in controller
      // Formula: (4.7 * 300 + 5.0) / 301 = 1415.0 / 301 = 4.7009 -> 4.7
      expect(controller.filteredPlaces.first.reviewCount, equals(301));
      expect(controller.filteredPlaces.first.rating, equals(4.7));

      // Clear search query and sort by rating
      controller.setSearchQuery('');
      controller.setSortOption(SortOption.rating);
      // Moda Dondurmacısı: 4.8, Hacı Baba: 4.7
      expect(controller.filteredPlaces.map((p) => p.id).toList(), equals(['kad_dondurma', 'kad_baklava']));
    });

    test('Journey 2: The Beşiktaş Remote Worker Coffee Hunt', () async {
      final besiktasVenues = [
        _createJourneyPlace(
          id: 'bes_c1',
          name: 'Voi Coffee Roastery',
          category: 'Kahve & Kafe',
          subCategory: 'Kafe',
          rating: 4.9,
          reviewCount: 320,
          latitude: 41.0435,
          longitude: 29.0055,
          distanceMeters: 80.0,
          popularItems: ['Cortado', 'Cheesecake'],
          tags: ['kahve', 'roastery'],
        ),
        _createJourneyPlace(
          id: 'bes_c2',
          name: 'Petra Roasting Co.',
          category: 'Kahve & Kafe',
          subCategory: 'Kafe',
          rating: 4.8,
          reviewCount: 180,
          latitude: 41.0440,
          longitude: 29.0060,
          distanceMeters: 190.0,
          popularItems: ['Cold Drip', 'Espresso'],
          tags: ['kahve'],
        ),
        _createJourneyPlace(
          id: 'bes_c3',
          name: 'Yeni Mahalle Kahvecisi',
          category: 'Kahve & Kafe',
          subCategory: 'Kafe',
          rating: 4.9,
          reviewCount: 15, // Low review count (< 50)
          latitude: 41.0432,
          longitude: 29.0052,
          distanceMeters: 50.0,
          popularItems: ['Filtre Kahve'],
          tags: ['kahve'],
        ),
        _createJourneyPlace(
          id: 'bes_c4',
          name: 'Uzak Kahveci',
          category: 'Kahve & Kafe',
          subCategory: 'Kafe',
          rating: 4.9,
          reviewCount: 500,
          latitude: 41.0470,
          longitude: 29.0090,
          distanceMeters: 850.0, // Outside 250m radius
          popularItems: ['Latte'],
          tags: ['kahve'],
        ),
      ];

      fakePlacesRepo.placesToReturn = besiktasVenues;
      fakePlacesRepo.distanceCalculator = (lat1, lon1, lat2, lon2) {
        if (lat2 == 41.0435) return 80.0;
        if (lat2 == 41.0440) return 190.0;
        if (lat2 == 41.0432) return 50.0;
        if (lat2 == 41.0470) return 850.0;
        return 0.0;
      };

      final controller = PlacesController(
        placesRepository: fakePlacesRepo,
        storageRepository: fakeStorageRepo,
      );

      // Step 1: User switches location to Beşiktaş via preset coordinates
      final besiktasPreset = LocationPreset.popularLocations.firstWhere(
        (p) => p.name.contains('Beşiktaş'),
      );
      await controller.setLocation(
        lat: besiktasPreset.latitude,
        lon: besiktasPreset.longitude,
        label: besiktasPreset.name,
      );

      expect(controller.centerLat, equals(41.0430));
      expect(controller.centerLon, equals(29.0053));
      expect(controller.locationLabel, contains('Beşiktaş'));

      // Step 2: Changes category to "Kahve & Kafe" and sets tight radius to 250m
      controller.setCategoryId('coffee');
      controller.setRadiusMeters(250.0);

      // Step 3: Filters for established venues with minimum 50 reviews
      controller.setMinReviewCount(50);

      // Step 4: Toggles view mode to Map View and back to List View
      expect(controller.isMapView, isFalse);
      controller.toggleViewMode();
      expect(controller.isMapView, isTrue);
      controller.toggleViewMode();
      expect(controller.isMapView, isFalse);

      // Step 5: Distance sort finds the closest high-reputation workspace
      controller.setSortOption(SortOption.distance);

      final results = controller.filteredPlaces;
      expect(results.length, equals(2));
      expect(results[0].id, equals('bes_c1')); // 80m distance
      expect(results[0].formattedDistance, equals('80 m'));
      expect(results[0].walkingMinutes, equals(2)); // ceil(80/75) = 2
      expect(results[1].id, equals('bes_c2')); // 190m distance
    });

    test('Journey 3: The Late-Night Street Food Search & Adaptive Radius Expansion', () async {
      final streetFoodVenues = [
        // Street food outside 50m radius (at 220m)
        _createJourneyPlace(
          id: 'street_burger',
          name: 'Akaretler Gourmet Burger',
          category: 'Burger & Sokak Lezzeti',
          subCategory: 'Burger',
          rating: 4.8,
          reviewCount: 220,
          latitude: 41.0438,
          longitude: 29.0058,
          distanceMeters: 220.0,
          popularItems: ['Truffle Burger', 'Patates'],
          tags: ['burger', 'fast_food'],
        ),
        // Dessert venue within 50m (wrong category)
        _createJourneyPlace(
          id: 'street_sweet',
          name: 'Gece Tatlıcısı',
          category: 'Tatlı & Pastane',
          subCategory: 'Tatlı',
          rating: 4.9,
          reviewCount: 150,
          latitude: 41.0431,
          longitude: 29.0053,
          distanceMeters: 30.0,
          popularItems: ['Sütlaç'],
          tags: ['tatlı'],
        ),
      ];

      fakePlacesRepo.placesToReturn = streetFoodVenues;
      fakePlacesRepo.distanceCalculator = (lat1, lon1, lat2, lon2) {
        if (lat2 == 41.0438) return 220.0;
        if (lat2 == 41.0431) return 30.0;
        return 0.0;
      };

      final controller = PlacesController(
        placesRepository: fakePlacesRepo,
        storageRepository: fakeStorageRepo,
        initialRadiusMeters: 50.0,
        initialCategoryId: 'fast_food',
      );

      await controller.loadPlaces();

      // Step 1: Verify filtered list is empty at 50m radius
      expect(controller.filteredPlaces, isEmpty);

      // Step 2: System detects closest matching venue outside radius
      final closest = controller.closestPlaceOutsideRadius;
      expect(closest, isNotNull);
      expect(closest!.id, equals('street_burger'));
      expect(closest.distanceMeters, equals(220.0));

      // Step 3: Trigger one-tap adaptive radius expansion
      // Formula: (220.0 + 50.0).clamp(100.0, 3000.0) = 270.0
      controller.expandRadiusToClosestPlace();

      expect(controller.radiusMeters, equals(270.0));

      // Step 4: Verify the burger joint appears in filtered results immediately
      expect(controller.filteredPlaces.length, equals(1));
      expect(controller.filteredPlaces.first.id, equals('street_burger'));
      expect(controller.closestPlaceOutsideRadius, isNull);
    });

    test('Journey 4: The Tourist Custom Search, Google API Key & Multi-Favorite Trip Planning', () async {
      final touristVenues = [
        _createJourneyPlace(
          id: 'tourist_1',
          name: 'Karaköy Tarihi Balıkçısı',
          category: 'Restoran & Yemek',
          subCategory: 'Balık',
          rating: 4.8,
          reviewCount: 400,
          latitude: 41.0248,
          longitude: 28.9770,
          distanceMeters: 120.0,
          popularItems: ['Balık Ekmek', 'Lüfer'],
          tags: ['balık', 'restoran'],
          address: 'Kemankeş Karamustafa Paşa, Beyoğlu/İstanbul',
        ),
        _createJourneyPlace(
          id: 'tourist_2',
          name: 'Galata Coffee Roasters',
          category: 'Kahve & Kafe',
          subCategory: 'Kafe',
          rating: 4.9,
          reviewCount: 250,
          latitude: 41.0255,
          longitude: 28.9775,
          distanceMeters: 200.0,
          popularItems: ['Chemex', 'Croissant'],
          tags: ['kahve'],
          address: 'Bereketzade, Beyoğlu/İstanbul',
        ),
        _createJourneyPlace(
          id: 'tourist_3',
          name: 'Kemankeş Büfe',
          category: 'Burger & Sokak Lezzeti',
          subCategory: 'Büfe',
          rating: 4.1,
          reviewCount: 30,
          latitude: 41.0242,
          longitude: 28.9765,
          distanceMeters: 90.0,
          popularItems: ['Tost'],
          tags: ['fast_food'],
          address: 'Kemankeş, Beyoğlu/İstanbul',
        ),
      ];

      fakePlacesRepo.presetsToReturn = [
        const LocationPreset(
          name: 'Karaköy İskelesi',
          subtitle: 'Beyoğlu, İstanbul',
          latitude: 41.0245,
          longitude: 28.9768,
        ),
      ];
      fakePlacesRepo.placesToReturn = touristVenues;
      fakePlacesRepo.distanceCalculator = (lat1, lon1, lat2, lon2) {
        if (lat2 == 41.0248) return 120.0;
        if (lat2 == 41.0255) return 200.0;
        if (lat2 == 41.0242) return 90.0;
        return 0.0;
      };

      final controller = PlacesController(
        placesRepository: fakePlacesRepo,
        storageRepository: fakeStorageRepo,
      );

      await controller.init();

      // Step 1: Search address via Nominatim
      final searchResults = await controller.searchAddress('Karaköy İskelesi');
      expect(searchResults.length, equals(1));
      final picked = searchResults.first;
      expect(picked.name, equals('Karaköy İskelesi'));

      // Step 2: Relocate center to picked address
      await controller.setLocation(
        lat: picked.latitude,
        lon: picked.longitude,
        label: picked.name,
      );
      expect(controller.centerLat, equals(41.0245));
      expect(controller.centerLon, equals(28.9768));

      // Step 3: Enter Google Places API Key
      await controller.setGoogleApiKey('AIzaSyTouristApiKey_2026');
      expect(controller.googleApiKey, equals('AIzaSyTouristApiKey_2026'));
      expect(await fakeStorageRepo.loadGoogleApiKey(), equals('AIzaSyTouristApiKey_2026'));

      // Step 4: Verify deep links and directions URL
      controller.setCategoryId('all');
      controller.setMinRating(4.0);

      final fishPlace = controller.filteredPlaces.firstWhere((p) => p.id == 'tourist_1');
      expect(fishPlace.googleDirectionsUrl, contains('destination=41.0248,28.977'));
      expect(fishPlace.googleMapsSearchUrl, contains('query=Karak%C3%B6y%20Tarihi%20Bal%C4%B1k%C3%A7%C4%B1s%C4%B1'));

      // Step 5: Save 2 favorites across different categories (Balıkçı and Galata Coffee)
      await controller.toggleFavorite('tourist_1');
      await controller.toggleFavorite('tourist_2');

      expect(controller.favoriteIds, containsAll(['tourist_1', 'tourist_2']));
      expect(await fakeStorageRepo.loadFavoriteIds(), containsAll(['tourist_1', 'tourist_2']));

      // Step 6: Filter by favorites only
      controller.toggleFavoritesOnly();
      expect(controller.showFavoritesOnly, isTrue);

      final favPlaces = controller.filteredPlaces;
      expect(favPlaces.length, equals(2));
      expect(favPlaces.map((p) => p.id).toSet(), equals({'tourist_1', 'tourist_2'}));
      expect(favPlaces.map((p) => p.id), isNot(contains('tourist_3')));
    });
  });
}
