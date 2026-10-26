import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mekan_radari/repositories/places_repository_impl.dart';

void main() {
  group('Adversarial Challenge 1: Extreme Coordinates & Radii', () {
    test('calculateDistance with Equator (0,0) and Prime Meridian', () {
      final repo = PlacesRepositoryImpl(
        client: MockClient((_) async => http.Response('{}', 200)),
      );

      final dEquator = repo.calculateDistance(0.0, 0.0, 0.0, 1.0);
      expect(dEquator, greaterThan(111000));
      expect(dEquator, lessThan(112000));

      final dMeridian = repo.calculateDistance(0.0, 0.0, 1.0, 0.0);
      expect(dMeridian, greaterThan(110000));
      expect(dMeridian, lessThan(112000));
    });

    test('calculateDistance across International Date Line (180 to -180)', () {
      final repo = PlacesRepositoryImpl(
        client: MockClient((_) async => http.Response('{}', 200)),
      );

      final dist = repo.calculateDistance(0.0, 179.9, 0.0, -179.9);
      // Shortest geodesic distance across antimeridian is ~0.2 degrees (~22.2 km)
      expect(dist, lessThan(25000));
    });

    test('calculateDistance with Poles (North Pole 90, South Pole -90)', () {
      final repo = PlacesRepositoryImpl(
        client: MockClient((_) async => http.Response('{}', 200)),
      );

      final dPoleToEquator = repo.calculateDistance(90.0, 0.0, 0.0, 0.0);
      expect(dPoleToEquator, greaterThan(9900000));
      expect(dPoleToEquator, lessThan(10100000));

      final dPoleToPole = repo.calculateDistance(90.0, 0.0, -90.0, 0.0);
      expect(dPoleToPole, greaterThan(19900000));
      expect(dPoleToPole, lessThan(20200000));
    });

    test('calculateDistance with boundary latitude values (+-90)', () {
      final repo = PlacesRepositoryImpl(
        client: MockClient((_) async => http.Response('{}', 200)),
      );

      expect(() => repo.calculateDistance(90.0, 0.0, 90.0, 0.0), returnsNormally);
      expect(() => repo.calculateDistance(-90.0, 0.0, -90.0, 0.0), returnsNormally);
    });

    test('calculateDistance with out-of-bounds coordinates (>90, <-90, >180)', () {
      final repo = PlacesRepositoryImpl(
        client: MockClient((_) async => http.Response('{}', 200)),
      );

      // LatLng in latlong2 normalizes longitude and clamps/handles coordinates
      final d1 = repo.calculateDistance(95.0, 0.0, 0.0, 0.0);
      expect(d1, isNotNull);

      final d2 = repo.calculateDistance(0.0, 200.0, 0.0, 0.0);
      expect(d2, isNotNull);
    });

    test('calculateDistance with NaN or Infinity coordinates', () {
      final repo = PlacesRepositoryImpl(
        client: MockClient((_) async => http.Response('{}', 200)),
      );

      final dNaN = repo.calculateDistance(double.nan, 0.0, 0.0, 0.0);
      expect(dNaN, 0.0);

      final dInf = repo.calculateDistance(double.infinity, 0.0, 0.0, 0.0);
      expect(dInf, 0.0);
    });

    test('fetchNearbyPlaces with 0m radius clamps and succeeds without crash', () async {
      final sampleJson = jsonEncode({
        'elements': [
          {
            'type': 'node',
            'id': 101,
            'lat': 40.9862,
            'lon': 29.0264,
            'tags': {'name': 'Sıfır Metre Cafe', 'amenity': 'cafe'}
          }
        ]
      });

      late http.Request captured;
      final repo = PlacesRepositoryImpl(
        client: MockClient((req) async {
          captured = req;
          return http.Response.bytes(utf8.encode(sampleJson), 200);
        }),
      );

      final places = await repo.fetchNearbyPlaces(
        lat: 40.9862,
        lon: 29.0264,
        radiusMeters: 0,
      );

      expect(places.length, 1);
      // Confirms query uses clamped minimum buffer (1200m)
      expect(Uri.decodeQueryComponent(captured.body), contains('around:1200'));
    });

    test('fetchNearbyPlaces with 50,000m radius clamps to 5000m Overpass buffer', () async {
      final sampleJson = jsonEncode({
        'elements': [
          {
            'type': 'node',
            'id': 101,
            'lat': 40.9862,
            'lon': 29.0264,
            'tags': {'name': 'Uzak Cafe', 'amenity': 'cafe'}
          }
        ]
      });

      late http.Request captured;
      final repo = PlacesRepositoryImpl(
        client: MockClient((req) async {
          captured = req;
          return http.Response.bytes(utf8.encode(sampleJson), 200);
        }),
      );

      final places = await repo.fetchNearbyPlaces(
        lat: 40.9862,
        lon: 29.0264,
        radiusMeters: 50000,
      );

      expect(places.length, 1);
      expect(Uri.decodeQueryComponent(captured.body), contains('around:5000'));
    });

    test('fetchNearbyPlaces with negative radius (-500m) clamps safely', () async {
      final sampleJson = jsonEncode({
        'elements': [
          {
            'type': 'node',
            'id': 101,
            'lat': 40.9862,
            'lon': 29.0264,
            'tags': {'name': 'Negatif Cafe', 'amenity': 'cafe'}
          }
        ]
      });

      late http.Request captured;
      final repo = PlacesRepositoryImpl(
        client: MockClient((req) async {
          captured = req;
          return http.Response.bytes(utf8.encode(sampleJson), 200);
        }),
      );

      final places = await repo.fetchNearbyPlaces(
        lat: 40.9862,
        lon: 29.0264,
        radiusMeters: -500,
      );

      expect(places.length, 1);
      expect(Uri.decodeQueryComponent(captured.body), contains('around:1200'));
    });

    test('fetchNearbyPlaces with North Pole (lat=90.0) and South Pole (lat=-90.0) fallback generation', () async {
      final repo = PlacesRepositoryImpl(
        client: MockClient((_) async => http.Response('503 Service Unavailable', 503)),
      );

      // Testing North Pole
      // Warning: 90.0 + offset (0.00018) > 90.0, will LatLng allow latitude > 90?
      expect(
        () async => await repo.fetchNearbyPlaces(lat: 90.0, lon: 0.0, radiusMeters: 1000),
        returnsNormally,
      );

      // Testing South Pole (-90.0 - offset < -90.0)
      expect(
        () async => await repo.fetchNearbyPlaces(lat: -90.0, lon: 0.0, radiusMeters: 1000),
        returnsNormally,
      );
    });

    test('fetchNearbyPlaces with NaN or Infinity radius', () async {
      final repo = PlacesRepositoryImpl(
        client: MockClient((_) async => http.Response('{}', 200)),
      );

      // Calling round() on non-finite radius throws UnsupportedError in Dart
      expect(
        () async => await repo.fetchNearbyPlaces(
          lat: 40.9862,
          lon: 29.0264,
          radiusMeters: double.nan,
        ),
        throwsA(isA<UnsupportedError>()),
      );

      expect(
        () async => await repo.fetchNearbyPlaces(
          lat: 40.9862,
          lon: 29.0264,
          radiusMeters: double.infinity,
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('Adversarial Challenge 2: Network & HTTP Edge Cases', () {
    test('HTTP 429 Too Many Requests triggers mirror failover', () async {
      final requestedUrls = <String>[];
      final validJson = jsonEncode({
        'elements': [
          {
            'type': 'node',
            'id': 101,
            'lat': 40.9862,
            'lon': 29.0264,
            'tags': {'name': 'Failover Cafe', 'amenity': 'cafe'}
          }
        ]
      });

      final repo = PlacesRepositoryImpl(
        client: MockClient((req) async {
          requestedUrls.add(req.url.host);
          if (req.url.host == 'overpass-api.de') {
            return http.Response('Rate limit exceeded', 429);
          }
          return http.Response.bytes(utf8.encode(validJson), 200);
        }),
      );

      final places = await repo.fetchNearbyPlaces(
        lat: 40.9862,
        lon: 29.0264,
        radiusMeters: 500,
      );

      expect(requestedUrls.length, 2);
      expect(requestedUrls[0], 'overpass-api.de');
      expect(requestedUrls[1], 'lz4.overpass-api.de');
      expect(places.first.name, 'Failover Cafe');
    });

    test('HTTP 429 on ALL mirrors falls back to 8 offline venues', () async {
      final requestedUrls = <String>[];
      final repo = PlacesRepositoryImpl(
        client: MockClient((req) async {
          requestedUrls.add(req.url.host);
          return http.Response('Rate limit exceeded (429)', 429);
        }),
      );

      final places = await repo.fetchNearbyPlaces(
        lat: 40.9862,
        lon: 29.0264,
        radiusMeters: 500,
      );

      expect(requestedUrls.length, 3);
      expect(places.length, 8);
      expect(places.every((p) => p.dataSource == 'Çevrimdışı Yedek Veri'), isTrue);
    });

    test('HTTP 500 on all mirrors falls back to 8 offline venues', () async {
      final repo = PlacesRepositoryImpl(
        client: MockClient((_) async => http.Response('Internal Server Error', 500)),
      );

      final places = await repo.fetchNearbyPlaces(
        lat: 40.9862,
        lon: 29.0264,
        radiusMeters: 500,
      );

      expect(places.length, 8);
      expect(places.first.dataSource, 'Çevrimdışı Yedek Veri');
    });

    test('Overpass returns 200 with HTML error page (e.g. Cloudflare or Nginx error)', () async {
      const htmlBody = '''
<!DOCTYPE html>
<html>
<head><title>502 Bad Gateway</title></head>
<body>
<center><h1>502 Bad Gateway</h1></center>
<hr><center>nginx</center>
</body>
</html>
''';

      final repo = PlacesRepositoryImpl(
        client: MockClient((_) async => http.Response(htmlBody, 200, headers: {'content-type': 'text/html'})),
      );

      final places = await repo.fetchNearbyPlaces(
        lat: 40.9862,
        lon: 29.0264,
        radiusMeters: 500,
      );

      // Should gracefully catch FormatException and return offline fallbacks
      expect(places.length, 8);
      expect(places.first.dataSource, 'Çevrimdışı Yedek Veri');
    });

    test('Overpass returns 200 with malformed XML instead of JSON', () async {
      const xmlBody = '''
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="Overpass API 0.7.62">
<note>The data included in this document is from www.openstreetmap.org</note>
<meta osm_base="2026-10-26T08:00:00Z"/>
</osm>
''';

      final repo = PlacesRepositoryImpl(
        client: MockClient((_) async => http.Response(xmlBody, 200)),
      );

      final places = await repo.fetchNearbyPlaces(
        lat: 40.9862,
        lon: 29.0264,
        radiusMeters: 500,
      );

      expect(places.length, 8);
      expect(places.first.dataSource, 'Çevrimdışı Yedek Veri');
    });

    test('Overpass returns 200 with empty elements array `{"elements": []}`', () async {
      final repo = PlacesRepositoryImpl(
        client: MockClient((_) async => http.Response(jsonEncode({'elements': []}), 200)),
      );

      final places = await repo.fetchNearbyPlaces(
        lat: 40.9862,
        lon: 29.0264,
        radiusMeters: 500,
      );

      // When all mirrors return empty elements, fallback places are provided
      expect(places.length, 8);
      expect(places.first.dataSource, 'Çevrimdışı Yedek Veri');
    });

    test('Overpass returns 200 with empty JSON object `{}`', () async {
      final repo = PlacesRepositoryImpl(
        client: MockClient((_) async => http.Response('{}', 200)),
      );

      final places = await repo.fetchNearbyPlaces(
        lat: 40.9862,
        lon: 29.0264,
        radiusMeters: 500,
      );

      expect(places.length, 8);
      expect(places.first.dataSource, 'Çevrimdışı Yedek Veri');
    });

    test('Overpass returns 200 with unexpected types in elements', () async {
      final corruptedJson = jsonEncode({
        'elements': [
          'just a string',
          12345,
          null,
          {'type': 'node'}, // missing id, tags, lat, lon
          {
            'type': 'node',
            'id': 'string_id', // non-integer id
            'lat': 40.9862,
            'lon': 29.0264,
            'tags': {'name': 'Valid Name Cafe', 'amenity': 'cafe'}
          },
          {
            'type': 'node',
            'id': 999,
            'lat': 'invalid_lat', // string lat instead of num
            'lon': 29.0264,
            'tags': {'name': 'Bad Lat Cafe'}
          },
          {
            'type': 'node',
            'id': 888,
            'lat': 40.9862,
            'lon': 29.0264,
            'tags': 'string_tags_not_map' // string tags instead of map
          }
        ]
      });

      final repo = PlacesRepositoryImpl(
        client: MockClient((_) async => http.Response.bytes(utf8.encode(corruptedJson), 200)),
      );

      // Must not throw unhandled exception
      final places = await repo.fetchNearbyPlaces(
        lat: 40.9862,
        lon: 29.0264,
        radiusMeters: 500,
      );

      expect(places, isNotEmpty);
    });

    test('Network client throws ClientException and TimeoutException', () async {
      final repo = PlacesRepositoryImpl(
        client: MockClient((_) async => throw http.ClientException('Connection reset by peer')),
      );

      final places = await repo.fetchNearbyPlaces(
        lat: 40.9862,
        lon: 29.0264,
        radiusMeters: 500,
      );

      expect(places.length, 8);
      expect(places.first.dataSource, 'Çevrimdışı Yedek Veri');
    });
  });

  group('Adversarial Challenge 3: Nominatim Geocoding Edge Cases', () {
    test('Nominatim search with special characters and symbols', () async {
      late http.Request captured;
      final repo = PlacesRepositoryImpl(
        client: MockClient((req) async {
          captured = req;
          return http.Response('[]', 200);
        }),
      );

      const query = '!@#\$%^&*()_+-=[]{}|;\':",./<>?';
      final results = await repo.searchAddress(query);

      expect(results, isEmpty);
      expect(captured.url.toString(), contains('nominatim.openstreetmap.org'));
    });

    test('Nominatim search with emojis and Unicode astral symbols', () async {
      late http.Request captured;
      final repo = PlacesRepositoryImpl(
        client: MockClient((req) async {
          captured = req;
          return http.Response('[]', 200);
        }),
      );

      const query = '🍕 Baklava & Çikolata 🍰 📍';
      final results = await repo.searchAddress(query);

      expect(results, isEmpty);
      expect(captured.url.queryParameters['q'], query);
    });

    test('Nominatim search with SQL injection patterns', () async {
      late http.Request captured;
      final repo = PlacesRepositoryImpl(
        client: MockClient((req) async {
          captured = req;
          return http.Response('[]', 200);
        }),
      );

      const query = "Kadıköy' OR '1'='1'; DROP TABLE places; --";
      final results = await repo.searchAddress(query);

      expect(results, isEmpty);
      expect(captured.url.queryParameters['q'], query);
    });

    test('Nominatim search with null byte character', () async {
      final repo = PlacesRepositoryImpl(
        client: MockClient((_) async => http.Response('[]', 200)),
      );

      const query = 'Kadıköy\x00Moda';
      expect(() async => await repo.searchAddress(query), returnsNormally);
    });

    test('Nominatim search with huge string (10,000 characters)', () async {
      final repo = PlacesRepositoryImpl(
        client: MockClient((_) async => http.Response('[]', 200)),
      );

      final hugeQuery = 'Kadıköy ' * 1250;
      final results = await repo.searchAddress(hugeQuery);
      expect(results, isEmpty);
    });

    test('Nominatim HTTP 429 Too Many Requests returns empty list safely', () async {
      final repo = PlacesRepositoryImpl(
        client: MockClient((_) async => http.Response('Bandwidth limit exceeded', 429)),
      );

      final results = await repo.searchAddress('Beşiktaş');
      expect(results, isEmpty);
    });

    test('Nominatim HTTP 500 Internal Server Error returns empty list safely', () async {
      final repo = PlacesRepositoryImpl(
        client: MockClient((_) async => http.Response('Internal Error', 500)),
      );

      final results = await repo.searchAddress('Beşiktaş');
      expect(results, isEmpty);
    });

    test('Nominatim 200 with HTML error page returns empty list safely', () async {
      final repo = PlacesRepositoryImpl(
        client: MockClient((_) async => http.Response('<html><body>502 Bad Gateway</body></html>', 200)),
      );

      final results = await repo.searchAddress('Beşiktaş');
      expect(results, isEmpty);
    });

    test('Nominatim 200 with JSON error map returns empty list safely', () async {
      final repo = PlacesRepositoryImpl(
        client: MockClient((_) async => http.Response('{"error": "Unable to geocode"}', 200)),
      );

      final results = await repo.searchAddress('Bilinmeyen Yer');
      expect(results, isEmpty);
    });

    test('Nominatim with missing lat/lon defaults to Kadikoy coordinates', () async {
      final mockData = [
        {
          'display_name': 'Eksik Konum Noktasi, Istanbul',
        },
        {
          'display_name': 'Bozuk Konum Noktasi, Istanbul',
          'lat': 'not_a_double',
          'lon': 'null',
        }
      ];

      final repo = PlacesRepositoryImpl(
        client: MockClient((_) async => http.Response(
          jsonEncode(mockData),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        )),
      );

      final results = await repo.searchAddress('Eksik');
      expect(results.length, 2);
      expect(results[0].latitude, 40.9862);
      expect(results[0].longitude, 29.0264);
      expect(results[1].latitude, 40.9862);
      expect(results[1].longitude, 29.0264);
    });

    test('Nominatim response without explicit charset parameter produces mojibake in searchAddress', () async {
      final mockData = [
        {
          'display_name': 'Kadıköy, İstanbul, Türkiye',
          'lat': '40.9862',
          'lon': '29.0264',
        }
      ];

      // Many servers or reverse proxies return 'application/json' without 'charset=utf-8'
      final repo = PlacesRepositoryImpl(
        client: MockClient((_) async => http.Response.bytes(
          utf8.encode(jsonEncode(mockData)),
          200,
          headers: {'content-type': 'application/json'},
        )),
      );

      final results = await repo.searchAddress('Kadıköy');
      final isMojibake = results.first.name.contains('KadÃ') || results.first.name.contains('KadÄ');
      expect(isMojibake, isFalse);
    });
  });

  group('Adversarial Challenge 4: Google Places API v1 Robustness', () {
    test('Google Places API with malformed response body falls back to Overpass', () async {
      final sampleOverpassJson = jsonEncode({
        'elements': [
          {
            'type': 'node',
            'id': 101,
            'lat': 40.9862,
            'lon': 29.0264,
            'tags': {'name': 'Overpass Fallback Cafe', 'amenity': 'cafe'}
          }
        ]
      });

      final repo = PlacesRepositoryImpl(
        client: MockClient((req) async {
          if (req.url.host == 'places.googleapis.com') {
            return http.Response('<html>Malformed Google Error</html>', 200);
          }
          return http.Response.bytes(utf8.encode(sampleOverpassJson), 200);
        }),
      );

      final places = await repo.fetchNearbyPlaces(
        lat: 40.9862,
        lon: 29.0264,
        radiusMeters: 500,
        googleApiKey: 'TEST_KEY',
      );

      expect(places.length, 1);
      expect(places.first.name, 'Overpass Fallback Cafe');
      expect(places.first.dataSource, 'Canlı Harita Verisi (OSM)');
    });

    test('Google Places API with missing places array returns empty then falls back to Overpass', () async {
      final sampleOverpassJson = jsonEncode({
        'elements': [
          {
            'type': 'node',
            'id': 101,
            'lat': 40.9862,
            'lon': 29.0264,
            'tags': {'name': 'Overpass Fallback Cafe', 'amenity': 'cafe'}
          }
        ]
      });

      final repo = PlacesRepositoryImpl(
        client: MockClient((req) async {
          if (req.url.host == 'places.googleapis.com') {
            return http.Response('{}', 200); // No places key
          }
          return http.Response.bytes(utf8.encode(sampleOverpassJson), 200);
        }),
      );

      final places = await repo.fetchNearbyPlaces(
        lat: 40.9862,
        lon: 29.0264,
        radiusMeters: 500,
        googleApiKey: 'TEST_KEY',
      );

      expect(places.length, 1);
      expect(places.first.name, 'Overpass Fallback Cafe');
    });

    test('Google Places API with venues missing coordinates, displayName, and reviews', () async {
      final incompleteGoogleJson = jsonEncode({
        'places': [
          {
            'id': 'empty_venue',
            // displayName is null
          },
          {
            'id': 'venue_no_location',
            'displayName': {'text': 'Konumsuz Cafe'},
            // location is null
            'types': ['cafe'],
          },
          {
            'id': 'venue_complete',
            'displayName': {'text': 'Tam Cafe'},
            'location': {'latitude': 40.9870, 'longitude': 29.0270},
            'rating': 4.9,
            'userRatingCount': 100,
          }
        ]
      });

      final repo = PlacesRepositoryImpl(
        client: MockClient((req) async {
          return http.Response.bytes(utf8.encode(incompleteGoogleJson), 200);
        }),
      );

      final places = await repo.fetchNearbyPlaces(
        lat: 40.9862,
        lon: 29.0264,
        radiusMeters: 500,
        googleApiKey: 'TEST_KEY',
      );

      // empty_venue skipped (name null)
      // venue_no_location defaults to user lat/lon
      // venue_complete parses fully
      expect(places.length, 2);
      expect(places.any((p) => p.name == 'Konumsuz Cafe'), isTrue);
      expect(places.any((p) => p.name == 'Tam Cafe'), isTrue);
    });
  });
}
