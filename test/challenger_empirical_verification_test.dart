import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mekan_radari/controllers/places_controller.dart';
import 'package:mekan_radari/models/place_model.dart';
import 'package:mekan_radari/repositories/places_repository_impl.dart';
import 'package:mekan_radari/repositories/storage_repository_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';

Place _createMockPlace({
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
    reviews: const [],
    starDistribution: const {5: 0.8, 4: 0.2},
    dataSource: 'overpass',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Challenger Verification 1: Overpass Mirror Fallback & Data Failovers', () {
    test('sequential mirror failover: mirror 1 fails (500) -> mirror 2 succeeds (200)', () async {
      final visitedEndpoints = <String>[];
      final validOverpassJson = jsonEncode({
        'elements': [
          {
            'type': 'node',
            'id': 1001,
            'lat': 40.9870,
            'lon': 29.0270,
            'tags': {
              'name': 'Mirror 2 Lezzet Durağı',
              'amenity': 'cafe',
            },
          }
        ]
      });

      final client = MockClient((request) async {
        visitedEndpoints.add(request.url.toString());
        if (request.url.toString() == PlacesRepositoryImpl.defaultOverpassEndpoints[0]) {
          return http.Response('Server error on mirror 1', 500);
        }
        if (request.url.toString() == PlacesRepositoryImpl.defaultOverpassEndpoints[1]) {
          return http.Response.bytes(utf8.encode(validOverpassJson), 200);
        }
        return http.Response('Not reached', 404);
      });

      final repo = PlacesRepositoryImpl(client: client);
      final places = await repo.fetchNearbyPlaces(
        lat: 40.9862,
        lon: 29.0264,
        radiusMeters: 500,
      );

      expect(visitedEndpoints.length, 2);
      expect(visitedEndpoints[0], PlacesRepositoryImpl.defaultOverpassEndpoints[0]);
      expect(visitedEndpoints[1], PlacesRepositoryImpl.defaultOverpassEndpoints[1]);
      expect(places.length, 1);
      expect(places.first.name, 'Mirror 2 Lezzet Durağı');
      expect(places.first.dataSource, 'Canlı Harita Verisi (OSM)');
    });

    test('sequential mirror failover: mirror 1 (429) & mirror 2 (504) fail -> mirror 3 succeeds (200)', () async {
      final visitedEndpoints = <String>[];
      final validOverpassJson = jsonEncode({
        'elements': [
          {
            'type': 'node',
            'id': 1002,
            'lat': 40.9875,
            'lon': 29.0280,
            'tags': {
              'name': 'Mirror 3 Kumi Mekanı',
              'amenity': 'restaurant',
            },
          }
        ]
      });

      final client = MockClient((request) async {
        visitedEndpoints.add(request.url.toString());
        if (request.url.toString() == PlacesRepositoryImpl.defaultOverpassEndpoints[0]) {
          return http.Response('Rate limit exceeded', 429);
        }
        if (request.url.toString() == PlacesRepositoryImpl.defaultOverpassEndpoints[1]) {
          return http.Response('Gateway timeout', 504);
        }
        if (request.url.toString() == PlacesRepositoryImpl.defaultOverpassEndpoints[2]) {
          return http.Response.bytes(utf8.encode(validOverpassJson), 200);
        }
        return http.Response('Not reached', 404);
      });

      final repo = PlacesRepositoryImpl(client: client);
      final places = await repo.fetchNearbyPlaces(
        lat: 40.9862,
        lon: 29.0264,
        radiusMeters: 500,
      );

      expect(visitedEndpoints.length, 3);
      expect(visitedEndpoints[2], PlacesRepositoryImpl.defaultOverpassEndpoints[2]);
      expect(places.length, 1);
      expect(places.first.name, 'Mirror 3 Kumi Mekanı');
    });

    test('all 3 mirrors fail -> falls back to 8 offline backup venues', () async {
      final visitedEndpoints = <String>[];
      final client = MockClient((request) async {
        visitedEndpoints.add(request.url.toString());
        return http.Response('Total network failure', 503);
      });

      final repo = PlacesRepositoryImpl(client: client);
      final places = await repo.fetchNearbyPlaces(
        lat: 40.9862,
        lon: 29.0264,
        radiusMeters: 500,
      );

      expect(visitedEndpoints.length, 3);
      expect(places.length, 8);
      expect(places.every((p) => p.dataSource == 'Çevrimdışı Yedek Veri'), isTrue);
      expect(places.first.name, 'Moda Çikolata & Tatlı Atölyesi');
    });

    test('Google Places API failure gracefully falls back to live Overpass API', () async {
      final requestedHosts = <String>[];
      final validOverpassJson = jsonEncode({
        'elements': [
          {
            'type': 'node',
            'id': 2001,
            'lat': 40.9870,
            'lon': 29.0270,
            'tags': {
              'name': 'Overpass Fallback Kahve',
              'amenity': 'cafe',
            },
          }
        ]
      });

      final client = MockClient((request) async {
        requestedHosts.add(request.url.host);
        if (request.url.host == 'places.googleapis.com') {
          return http.Response('{"error": {"code": 403, "message": "API key invalid"}}', 403);
        }
        return http.Response.bytes(utf8.encode(validOverpassJson), 200);
      });

      final repo = PlacesRepositoryImpl(client: client);
      final places = await repo.fetchNearbyPlaces(
        lat: 40.9862,
        lon: 29.0264,
        radiusMeters: 500,
        googleApiKey: 'INVALID_GOOGLE_KEY',
      );

      expect(requestedHosts, contains('places.googleapis.com'));
      expect(requestedHosts, contains('overpass-api.de'));
      expect(places.length, 1);
      expect(places.first.name, 'Overpass Fallback Kahve');
      expect(places.first.dataSource, 'Canlı Harita Verisi (OSM)');
    });

    test('Nominatim network error returns empty list without exception', () async {
      final client = MockClient((request) async {
        throw http.ClientException('DNS lookup failure');
      });

      final repo = PlacesRepositoryImpl(client: client);
      final results = await repo.searchAddress('Kadıköy Rıhtım');
      expect(results, isEmpty);
    });
  });

  group('Challenger Verification 2: Geodesic Distance Calculations', () {
    final repo = PlacesRepositoryImpl(
      client: MockClient((_) async => http.Response('{}', 200)),
    );

    test('distance between identical points is exactly 0.0 meters', () {
      expect(repo.calculateDistance(40.9862, 29.0264, 40.9862, 29.0264), equals(0.0));
      expect(repo.calculateDistance(0.0, 0.0, 0.0, 0.0), equals(0.0));
    });

    test('distance benchmark matches real-world Kadikoy Rihtim to Moda Pier (~1.3 km)', () {
      // Kadıköy Rıhtım: 40.9912, 29.0225
      // Moda İskelesi: 40.9790, 29.0245
      final distance = repo.calculateDistance(40.9912, 29.0225, 40.9790, 29.0245);
      expect(distance, greaterThan(1250.0));
      expect(distance, lessThan(1450.0));
    });

    test('distance handles extreme coordinates and returns 0.0 for non-finite inputs', () {
      expect(repo.calculateDistance(double.nan, 29.0, 40.0, 29.0), equals(0.0));
      expect(repo.calculateDistance(40.0, double.infinity, 40.0, 29.0), equals(0.0));
    });
  });

  group('Challenger Verification 3: Turkish Character Normalization in Search', () {
    test('turkishToLower correctly handles dotted and dotless I according to Turkish rules', () {
      expect(PlacesController.turkishToLower('I'), equals('ı'));
      expect(PlacesController.turkishToLower('İ'), equals('i'));
      expect(PlacesController.turkishToLower('ISLAK KEK'), equals('ıslak kek'));
      expect(PlacesController.turkishToLower('İSTANBUL BOĞAZI'), equals('istanbul boğazı'));
      expect(PlacesController.turkishToLower('ÇITIR ŞEKER'), equals('çıtır şeker'));
      expect(PlacesController.turkishToLower('GÖZLEME & BÖREK'), equals('gözleme & börek'));
      expect(PlacesController.turkishToLower('ÜZÜM & DUT'), equals('üzüm & dut'));
    });

    test('filterPlaces accurately matches Turkish search queries regardless of casing', () {
      final places = [
        _createMockPlace(id: '1', name: 'Kadıköy Çıtır Fırın'),
        _createMockPlace(id: '2', name: 'İncir Ağacı Tatlıcısı'),
        _createMockPlace(id: '3', name: 'Şekerpare & Baklava'),
        _createMockPlace(id: '4', name: 'Gözleme ve Su Böreği Dünyası'),
      ];

      // 1. Search 'ÇITIR' matches 'Kadıköy Çıtır Fırın'
      final match1 = PlacesController.filterPlaces(
        places: places,
        selectedCategoryId: 'all',
        radiusMeters: 500,
        minRating: 4.0,
        minReviewCount: 0,
        searchQuery: 'ÇITIR',
        showFavoritesOnly: false,
        favoriteIds: {},
      );
      expect(match1.length, 1);
      expect(match1.first.id, '1');

      // 2. Search 'İNCİR' matches 'İncir Ağacı Tatlıcısı'
      final match2 = PlacesController.filterPlaces(
        places: places,
        selectedCategoryId: 'all',
        radiusMeters: 500,
        minRating: 4.0,
        minReviewCount: 0,
        searchQuery: 'İNCİR',
        showFavoritesOnly: false,
        favoriteIds: {},
      );
      expect(match2.length, 1);
      expect(match2.first.id, '2');

      // 3. Search 'incir' matches 'İncir Ağacı Tatlıcısı'
      final match2Lower = PlacesController.filterPlaces(
        places: places,
        selectedCategoryId: 'all',
        radiusMeters: 500,
        minRating: 4.0,
        minReviewCount: 0,
        searchQuery: 'incir',
        showFavoritesOnly: false,
        favoriteIds: {},
      );
      expect(match2Lower.length, 1);
      expect(match2Lower.first.id, '2');

      // 4. Search 'ŞEKERPARE' matches 'Şekerpare & Baklava'
      final match3 = PlacesController.filterPlaces(
        places: places,
        selectedCategoryId: 'all',
        radiusMeters: 500,
        minRating: 4.0,
        minReviewCount: 0,
        searchQuery: 'ŞEKERPARE',
        showFavoritesOnly: false,
        favoriteIds: {},
      );
      expect(match3.length, 1);
      expect(match3.first.id, '3');

      // 5. Search with regex symbols and whitespace
      final matchRegex = PlacesController.filterPlaces(
        places: places,
        selectedCategoryId: 'all',
        radiusMeters: 500,
        minRating: 4.0,
        minReviewCount: 0,
        searchQuery: '  [Böreği]  ',
        showFavoritesOnly: false,
        favoriteIds: {},
      );
      expect(matchRegex, isEmpty); // Regex symbols treated as literal characters without crashing
    });
  });

  group('Challenger Verification 4: Persistence Key Consistency', () {
    test('exact SharedPreferences keys match specification', () {
      expect(StorageRepositoryImpl.favoritesKey, equals('favorite_place_ids_v1'));
      expect(StorageRepositoryImpl.userReviewsKey, equals('user_place_reviews_v1'));
      expect(StorageRepositoryImpl.googleApiKeyPref, equals('google_places_api_key_v1'));
    });

    test('pre-existing data stored under v1 keys is accurately loaded', () async {
      SharedPreferences.setMockInitialValues({
        'favorite_place_ids_v1': ['place_fav_101', 'place_fav_102'],
        'google_places_api_key_v1': 'AIzaSyExistingKey123',
        'user_place_reviews_v1': jsonEncode({
          'place_fav_101': [
            {
              'id': 'rev_101',
              'authorName': 'Ahmet Yılmaz',
              'authorBadge': 'Yerel Rehber',
              'rating': 5.0,
              'relativeTime': 'Dün',
              'comment': 'Mükemmel lezzet!',
              'isUserReview': true,
            }
          ]
        }),
      });

      final storage = StorageRepositoryImpl();

      // Verify favorites
      final favorites = await storage.loadFavoriteIds();
      expect(favorites, containsAll(['place_fav_101', 'place_fav_102']));
      expect(await storage.isFavorite('place_fav_101'), isTrue);

      // Verify API key
      final apiKey = await storage.loadGoogleApiKey();
      expect(apiKey, 'AIzaSyExistingKey123');

      // Verify user reviews
      final reviews = await storage.getReviewsForPlace('place_fav_101');
      expect(reviews.length, 1);
      expect(reviews.first.id, 'rev_101');
      expect(reviews.first.comment, 'Mükemmel lezzet!');
    });

    test('mutations persist directly into exact specified SharedPreferences keys', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageRepositoryImpl();

      await storage.saveFavoriteIds({'venue_alpha', 'venue_beta'});
      await storage.saveGoogleApiKey('AIzaSyNewKey');
      await storage.addUserReview(
        'venue_alpha',
        const PlaceReview(
          id: 'rev_new',
          authorName: 'Fatma Demir',
          authorBadge: 'Gezgin',
          rating: 4.8,
          relativeTime: 'Şimdi',
          comment: 'Harika bir ortam',
        ),
      );

      final prefs = await SharedPreferences.getInstance();

      // Check raw keys
      final rawFavs = prefs.getStringList('favorite_place_ids_v1');
      expect(rawFavs, containsAll(['venue_alpha', 'venue_beta']));

      final rawKey = prefs.getString('google_places_api_key_v1');
      expect(rawKey, 'AIzaSyNewKey');

      final rawReviews = prefs.getString('user_place_reviews_v1');
      expect(rawReviews, isNotNull);
      final decodedReviews = jsonDecode(rawReviews!) as Map<String, dynamic>;
      expect(decodedReviews.containsKey('venue_alpha'), isTrue);
    });

    test('corrupted JSON in user_place_reviews_v1 recovers cleanly without crash', () async {
      SharedPreferences.setMockInitialValues({
        'user_place_reviews_v1': '{{{corrupted_garbage_json:::null',
      });
      final storage = StorageRepositoryImpl();

      final reviews = await storage.loadUserReviews();
      expect(reviews, isEmpty);

      // Subsequent add auto-repairs
      await storage.addUserReview(
        'venue_repair',
        const PlaceReview(
          id: 'rev_repaired',
          authorName: 'Repairer',
          authorBadge: 'Admin',
          rating: 5.0,
          relativeTime: 'Şimdi',
          comment: 'Auto repaired!',
        ),
      );

      final repaired = await storage.getReviewsForPlace('venue_repair');
      expect(repaired.length, 1);
      expect(repaired.first.id, 'rev_repaired');
    });
  });

  group('Challenger Verification 5: Boundary Values and Clamping', () {
    test('PlacesController boundary clamps for radius, rating, review count', () {
      final controller = PlacesController();

      // Radius clamping: [50.0, 3000.0]
      controller.setRadiusMeters(10.0);
      expect(controller.radiusMeters, equals(50.0));

      controller.setRadiusMeters(5000.0);
      expect(controller.radiusMeters, equals(3000.0));

      controller.setRadiusMeters(double.nan);
      expect(controller.radiusMeters, equals(3000.0)); // keeps valid value

      // Rating clamping: [0.0, 5.0]
      controller.setMinRating(-2.0);
      expect(controller.minRating, equals(0.0));

      controller.setMinRating(8.5);
      expect(controller.minRating, equals(5.0));

      controller.setMinRating(double.nan);
      expect(controller.minRating, equals(5.0));

      // Review count clamping: >= 0
      controller.setMinReviewCount(-100);
      expect(controller.minReviewCount, equals(0));

      controller.setMinReviewCount(250);
      expect(controller.minReviewCount, equals(250));
    });

    test('calculateExpandedRadius clamps buffer between 100m and 3000m', () {
      expect(PlacesController.calculateExpandedRadius(20.0), equals(100.0));
      expect(PlacesController.calculateExpandedRadius(500.0), equals(550.0));
      expect(PlacesController.calculateExpandedRadius(2980.0), equals(3000.0));
      expect(PlacesController.calculateExpandedRadius(10000.0), equals(3000.0));
    });

    test('Place model formatting boundaries', () {
      final pShort = _createMockPlace(id: '1', name: 'Short', distanceMeters: 450.0);
      expect(pShort.formattedDistance, equals('450 m'));

      final pLong = _createMockPlace(id: '2', name: 'Long', distanceMeters: 1450.0);
      expect(pLong.formattedDistance, equals('1.45 km'));

      final pZero = _createMockPlace(id: '3', name: 'Zero', distanceMeters: 0.0);
      expect(pZero.walkingMinutes, equals(1)); // minimum 1 min
    });
  });
}
