import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mekan_radari/repositories/places_repository_impl.dart';

void main() {
  group('PlacesRepositoryImpl - calculateDistance', () {
    final repo = PlacesRepositoryImpl(
      client: MockClient((_) async => http.Response('{}', 200)),
    );

    test('returns 0.0 for identical coordinates', () {
      final dist = repo.calculateDistance(40.9862, 29.0264, 40.9862, 29.0264);
      expect(dist, 0.0);
    });

    test('returns accurate Haversine distance between Kadikoy and Besiktas', () {
      final dist = repo.calculateDistance(40.9862, 29.0264, 41.0430, 29.0053);
      // Expected geodesic distance is ~6500 - 6600 meters
      expect(dist, greaterThan(6400));
      expect(dist, lessThan(6700));
    });

    test('is symmetric regardless of coordinate order', () {
      final d1 = repo.calculateDistance(40.9862, 29.0264, 41.0430, 29.0053);
      final d2 = repo.calculateDistance(41.0430, 29.0053, 40.9862, 29.0264);
      expect((d1 - d2).abs(), lessThan(0.001));
    });
  });

  group('PlacesRepositoryImpl - searchAddress (Nominatim)', () {
    test('returns empty list immediately if query is empty or whitespace', () async {
      var called = false;
      final repo = PlacesRepositoryImpl(
        client: MockClient((request) async {
          called = true;
          return http.Response('[]', 200);
        }),
      );

      final r1 = await repo.searchAddress('');
      final r2 = await repo.searchAddress('   ');
      expect(r1, isEmpty);
      expect(r2, isEmpty);
      expect(called, isFalse);
    });

    test('sends correctly formatted Nominatim request and parses results', () async {
      late http.Request capturedRequest;
      final mockData = [
        {
          'display_name': 'Karaköy, Beyoğlu, İstanbul, Marmara Bölgesi, Türkiye',
          'lat': '41.0245',
          'lon': '28.9768',
        },
        {
          'display_name': 'Karaköy İskelesi, Kemankeş, Beyoğlu, İstanbul',
          'lat': '41.0230',
          'lon': '28.9775',
        }
      ];

      final repo = PlacesRepositoryImpl(
        client: MockClient((request) async {
          capturedRequest = request;
          return http.Response(jsonEncode(mockData), 200, headers: {
            'content-type': 'application/json; charset=utf-8',
          });
        }),
      );

      final results = await repo.searchAddress('Karaköy');

      expect(capturedRequest.url.host, 'nominatim.openstreetmap.org');
      expect(capturedRequest.url.queryParameters['q'], 'Karaköy');
      expect(capturedRequest.url.queryParameters['accept-language'], 'tr');
      expect(capturedRequest.headers['User-Agent'], contains('MekanRadariFlutterApp'));

      expect(results.length, 2);
      expect(results[0].name, 'Karaköy');
      expect(results[0].subtitle, 'Beyoğlu, İstanbul, Marmara Bölgesi');
      expect(results[0].latitude, 41.0245);
      expect(results[0].longitude, 28.9768);
      expect(results[1].name, 'Karaköy İskelesi');
    });

    test('returns empty list gracefully on HTTP error or exception', () async {
      final repo = PlacesRepositoryImpl(
        client: MockClient((_) async => http.Response('Internal Error', 500)),
      );
      final results = await repo.searchAddress('Kadıköy');
      expect(results, isEmpty);
    });
  });

  group('PlacesRepositoryImpl - fetchNearbyPlaces (Overpass OSM)', () {
    final sampleOverpassJson = jsonEncode({
      'elements': [
        {
          'type': 'node',
          'id': 101,
          'lat': 40.9870,
          'lon': 29.0270,
          'tags': {
            'name': 'Moda Çikolatacısı',
            'amenity': 'cafe',
            'shop': 'confectionery',
            'addr:street': 'Moda Caddesi',
            'addr:housenumber': '24',
            'addr:neighbourhood': 'Caferağa',
            'addr:district': 'Kadıköy',
            'outdoor_seating': 'yes',
            'internet_access': 'wlan',
            'takeaway': 'yes',
          }
        },
        {
          'type': 'way',
          'id': 202,
          'center': {'lat': 40.9880, 'lon': 29.0280},
          'tags': {
            'name': 'Kadıköy Kahve Evi',
            'amenity': 'cafe',
            'cuisine': 'coffee_shop',
          }
        }
      ]
    });

    test('successfully fetches and parses Overpass venues from first mirror', () async {
      final requestedUrls = <String>[];
      final repo = PlacesRepositoryImpl(
        client: MockClient((request) async {
          requestedUrls.add(request.url.toString());
          return http.Response.bytes(
            utf8.encode(sampleOverpassJson),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final places = await repo.fetchNearbyPlaces(
        lat: 40.9862,
        lon: 29.0264,
        radiusMeters: 500,
      );

      expect(requestedUrls.length, 1);
      expect(requestedUrls.first, 'https://overpass-api.de/api/interpreter');
      expect(places.length, 2);

      // Verify first place
      final p1 = places.firstWhere((p) => p.name == 'Moda Çikolatacısı');
      expect(p1.category, 'Tatlı & Pastane');
      expect(p1.address, contains('Moda Caddesi No:24'));
      expect(
        p1.tags,
        containsAll(['Taze Günlük Tatlı', 'Dış Mekan Oturma']),
      );
      expect(p1.dataSource, 'Canlı Harita Verisi (OSM)');
      expect(p1.rating, greaterThanOrEqualTo(3.8));
      expect(p1.rating, lessThanOrEqualTo(4.9));
      expect(p1.reviews, isNotEmpty);
      expect(p1.starDistribution.containsKey(5), isTrue);

      // Verify second place from way center
      final p2 = places.firstWhere((p) => p.name == 'Kadıköy Kahve Evi');
      expect(p2.category, 'Kahve & Kafe');
      expect(p2.latitude, 40.9880);
      expect(p2.longitude, 29.0280);

      // Verify distance sort
      expect(
        places[0].distanceMeters,
        lessThanOrEqualTo(places[1].distanceMeters),
      );
    });

    test('fails over to second mirror when first mirror fails with 504', () async {
      final requestedUrls = <String>[];
      final repo = PlacesRepositoryImpl(
        client: MockClient((request) async {
          requestedUrls.add(request.url.toString());
          if (request.url.host == 'overpass-api.de') {
            return http.Response('Gateway Timeout', 504);
          }
          if (request.url.host == 'lz4.overpass-api.de') {
            return http.Response.bytes(utf8.encode(sampleOverpassJson), 200);
          }
          return http.Response('Error', 500);
        }),
      );

      final places = await repo.fetchNearbyPlaces(
        lat: 40.9862,
        lon: 29.0264,
        radiusMeters: 500,
      );

      expect(requestedUrls.length, 2);
      expect(requestedUrls[0], contains('overpass-api.de'));
      expect(requestedUrls[1], contains('lz4.overpass-api.de'));
      expect(places.length, 2);
      expect(places.first.dataSource, 'Canlı Harita Verisi (OSM)');
    });

    test('returns 8 offline fallback venues when all Overpass mirrors fail', () async {
      final requestedUrls = <String>[];
      final repo = PlacesRepositoryImpl(
        client: MockClient((request) async {
          requestedUrls.add(request.url.toString());
          return http.Response('Service Unavailable', 503);
        }),
      );

      final places = await repo.fetchNearbyPlaces(
        lat: 40.9862,
        lon: 29.0264,
        radiusMeters: 500,
      );

      expect(requestedUrls.length, 3); // All 3 mirrors attempted
      expect(places.length, 8); // 8 offline fallbacks returned
      for (final p in places) {
        expect(p.dataSource, 'Çevrimdışı Yedek Veri');
        expect(p.distanceMeters, greaterThan(0));
      }
      expect(
        places[0].distanceMeters,
        lessThanOrEqualTo(places[1].distanceMeters),
      );
    });

    test('deduplicates venues with identical name within 30m', () async {
      final duplicateJson = jsonEncode({
        'elements': [
          {
            'type': 'node',
            'id': 1,
            'lat': 40.98620,
            'lon': 29.02640,
            'tags': {'name': 'Starbucks', 'amenity': 'cafe'}
          },
          {
            'type': 'node',
            'id': 2,
            'lat': 40.98621,
            'lon': 29.02641,
            'tags': {'name': 'Starbucks', 'amenity': 'cafe'}
          }
        ]
      });

      final repo = PlacesRepositoryImpl(
        client: MockClient(
          (_) async => http.Response.bytes(utf8.encode(duplicateJson), 200),
        ),
      );

      final places = await repo.fetchNearbyPlaces(
        lat: 40.9862,
        lon: 29.0264,
        radiusMeters: 500,
      );

      expect(places.length, 1);
    });
  });

  group('PlacesRepositoryImpl - fetchNearbyPlaces (Google Places API v1)', () {
    final sampleGoogleJson = jsonEncode({
      'places': [
        {
          'id': 'ChIJ_12345',
          'displayName': {'text': 'Güllüoğlu Karaköy'},
          'types': ['bakery', 'cafe'],
          'rating': 4.7,
          'userRatingCount': 1420,
          'formattedAddress': 'Kemankeş Karamustafa Paşa Mah., Beyoğlu',
          'location': {'latitude': 41.0225, 'longitude': 28.9780},
          'regularOpeningHours': {'openNow': true},
          'googleMapsUri': 'https://maps.google.com/?cid=999',
          'reviews': [
            {
              'authorAttribution': {'displayName': 'Mehmet T.'},
              'rating': 5.0,
              'relativePublishTimeDescription': '3 gün önce',
              'text': {'text': 'Nadir Güllü baklavaları harika!'}
            }
          ]
        }
      ]
    });

    test('uses Google Places API when googleApiKey is provided', () async {
      late http.Request capturedGoogleRequest;
      final repo = PlacesRepositoryImpl(
        client: MockClient((request) async {
          capturedGoogleRequest = request;
          return http.Response.bytes(utf8.encode(sampleGoogleJson), 200);
        }),
      );

      final places = await repo.fetchNearbyPlaces(
        lat: 41.0245,
        lon: 28.9768,
        radiusMeters: 800,
        googleApiKey: 'AIzaSyTestApiKey',
      );

      expect(capturedGoogleRequest.url.host, 'places.googleapis.com');
      expect(capturedGoogleRequest.url.path, '/v1/places:searchNearby');
      expect(capturedGoogleRequest.headers['X-Goog-Api-Key'], 'AIzaSyTestApiKey');
      expect(
        capturedGoogleRequest.headers['X-Goog-FieldMask'],
        contains('places.displayName'),
      );

      expect(places.length, 1);
      expect(places.first.name, 'Güllüoğlu Karaköy');
      expect(places.first.dataSource, 'Google Places API (Canlı)');
      expect(places.first.reviews.first.comment, contains('Nadir Güllü'));
      expect(
        places.first.customGoogleMapsUri,
        'https://maps.google.com/?cid=999',
      );
    });

    test('uses places:searchText endpoint when searchQuery is provided with googleApiKey', () async {
      late http.Request capturedRequest;
      final repo = PlacesRepositoryImpl(
        client: MockClient((request) async {
          capturedRequest = request;
          return http.Response.bytes(utf8.encode(sampleGoogleJson), 200);
        }),
      );

      await repo.fetchNearbyPlaces(
        lat: 41.0245,
        lon: 28.9768,
        radiusMeters: 800,
        googleApiKey: 'AIzaSyTestApiKey',
        searchQuery: 'Baklava',
      );

      expect(capturedRequest.url.path, '/v1/places:searchText');
      final body = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      expect(body['textQuery'], 'Baklava');
    });

    test('falls back seamlessly to Overpass when Google Places returns 403', () async {
      final sampleOverpassJson = jsonEncode({
        'elements': [
          {
            'type': 'node',
            'id': 999,
            'lat': 41.0240,
            'lon': 28.9760,
            'tags': {'name': 'Galata Kahvecisi', 'amenity': 'cafe'}
          }
        ]
      });

      final requestedHosts = <String>[];
      final repo = PlacesRepositoryImpl(
        client: MockClient((request) async {
          requestedHosts.add(request.url.host);
          if (request.url.host == 'places.googleapis.com') {
            return http.Response(
              '{"error": {"code": 403, "message": "API key invalid"}}',
              403,
            );
          }
          return http.Response.bytes(utf8.encode(sampleOverpassJson), 200);
        }),
      );

      final places = await repo.fetchNearbyPlaces(
        lat: 41.0245,
        lon: 28.9768,
        radiusMeters: 800,
        googleApiKey: 'invalid_key',
      );

      expect(requestedHosts, contains('places.googleapis.com'));
      expect(requestedHosts, contains('overpass-api.de'));
      expect(places.length, 1);
      expect(places.first.name, 'Galata Kahvecisi');
      expect(places.first.dataSource, 'Canlı Harita Verisi (OSM)');
    });
  });
}
