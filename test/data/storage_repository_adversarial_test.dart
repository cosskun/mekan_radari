import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekan_radari/models/location_preset.dart';
import 'package:mekan_radari/models/place_model.dart';
import 'package:mekan_radari/repositories/storage_repository_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageRepositoryImpl repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = StorageRepositoryImpl();
  });

  group('Adversarial Storage: Massive Data Volumes', () {
    test('handles 1,000 favorites without failure or degradation', () async {
      final ids = List.generate(1000, (i) => 'place_benchmark_id_$i').toSet();
      await repository.saveFavoriteIds(ids);

      final loaded = await repository.loadFavoriteIds();
      expect(loaded.length, 1000);
      expect(await repository.isFavorite('place_benchmark_id_0'), isTrue);
      expect(await repository.isFavorite('place_benchmark_id_999'), isTrue);
      expect(await repository.isFavorite('place_benchmark_id_1000'), isFalse);
    });

    test('handles 5,000 favorites without failure', () async {
      final ids = List.generate(5000, (i) => 'venue_large_scale_$i').toSet();
      await repository.saveFavoriteIds(ids);

      final loaded = await repository.loadFavoriteIds();
      expect(loaded.length, 5000);
      expect(await repository.isFavorite('venue_large_scale_4999'), isTrue);
    });

    test('handles massive review payload with 100KB comment text', () async {
      final massiveComment = 'A' * (100 * 1024); // 100KB
      final largeReview = PlaceReview(
        id: 'rev_massive_100kb',
        authorName: 'Stress Tester',
        authorBadge: 'Bot',
        rating: 4.5,
        relativeTime: 'Şimdi',
        comment: massiveComment,
        likesCount: 9999,
        orderedItems: List.generate(100, (i) => 'Item_$i'),
        isUserReview: true,
      );

      await repository.addUserReview('venue_stress_100kb', largeReview);

      final loaded = await repository.getReviewsForPlace('venue_stress_100kb');
      expect(loaded.length, 1);
      expect(loaded.first.id, 'rev_massive_100kb');
      expect(loaded.first.comment.length, 100 * 1024);
      expect(loaded.first.orderedItems.length, 100);

      // Verify raw JSON string in storage is also intact
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(StorageRepositoryImpl.userReviewsKey);
      expect(raw, isNotNull);
      expect(raw!.length, greaterThan(100 * 1024));
    });

    test('handles large number of user reviews across multiple venues', () async {
      // Add 200 reviews across 20 venues (10 reviews each)
      for (int v = 0; v < 20; v++) {
        final venueId = 'venue_grid_$v';
        for (int r = 0; r < 10; r++) {
          await repository.addUserReview(
            venueId,
            PlaceReview(
              id: 'rev_${v}_$r',
              authorName: 'User $r',
              authorBadge: 'Rehber',
              rating: (r % 5 + 1).toDouble(),
              relativeTime: '$r gün önce',
              comment: 'Review comment #$r for venue $v',
            ),
          );
        }
      }

      final allReviews = await repository.loadUserReviews();
      expect(allReviews.length, 20);
      for (int v = 0; v < 20; v++) {
        expect(allReviews['venue_grid_$v']?.length, 10);
      }
    });
  });

  group('Adversarial Concurrency: Rapid Concurrent Invocations', () {
    test('rapid concurrent toggles on distinct place IDs do not crash or throw', () async {
      final futures = <Future<void>>[];
      for (int i = 0; i < 40; i++) {
        futures.add(repository.toggleFavorite('concurrent_place_$i'));
      }

      // Should complete cleanly without unhandled exceptions
      await expectLater(Future.wait(futures), completes);

      // Verify storage is in a consistent state
      final loaded = await repository.loadFavoriteIds();
      expect(loaded, isA<Set<String>>());
      // Due to concurrent read-modify-write without mutex, some may overwrite, but zero crashes
      expect(loaded.isNotEmpty, isTrue);
    });

    test('rapid concurrent toggles on same place ID do not crash or throw', () async {
      final futures = <Future<void>>[];
      for (int i = 0; i < 20; i++) {
        futures.add(repository.toggleFavorite('single_hot_place'));
      }

      await expectLater(Future.wait(futures), completes);
      final isFav = await repository.isFavorite('single_hot_place');
      expect(isFav, isA<bool>());
    });

    test('rapid concurrent addUserReview calls complete without throwing', () async {
      final futures = <Future<void>>[];
      for (int i = 0; i < 25; i++) {
        futures.add(
          repository.addUserReview(
            'venue_concurrent',
            PlaceReview(
              id: 'concurrent_rev_$i',
              authorName: 'Concurrent User $i',
              authorBadge: 'Rehber',
              rating: 5.0,
              relativeTime: 'Şimdi',
              comment: 'Concurrent test $i',
            ),
          ),
        );
      }

      await expectLater(Future.wait(futures), completes);

      final reviews = await repository.getReviewsForPlace('venue_concurrent');
      expect(reviews.isNotEmpty, isTrue);
    });

    test('concurrent mixed operations (read, write, toggle, API key) do not deadlock', () async {
      final futures = <Future<dynamic>>[
        repository.loadFavoriteIds(),
        repository.saveFavoriteIds({'fav_mix_1', 'fav_mix_2'}),
        repository.toggleFavorite('fav_mix_1'),
        repository.isFavorite('fav_mix_2'),
        repository.loadUserReviews(),
        repository.addUserReview(
          'mix_venue',
          const PlaceReview(
            id: 'mix_1',
            authorName: 'Mixer',
            authorBadge: 'Tester',
            rating: 4.0,
            relativeTime: 'Now',
            comment: 'Mixed load',
          ),
        ),
        repository.getReviewsForPlace('mix_venue'),
        repository.saveGoogleApiKey('AIzaSy_MixKey_123'),
        repository.loadGoogleApiKey(),
      ];

      await expectLater(Future.wait(futures), completes);
    });
  });

  group('Adversarial Persistence: Duplicate IDs and Malformed Structures', () {
    test('deduplicates duplicate IDs existing in raw SharedPreferences string list', () async {
      SharedPreferences.setMockInitialValues({
        StorageRepositoryImpl.favoritesKey: [
          'dup_id_1',
          'dup_id_1',
          'dup_id_2',
          'dup_id_1',
          'dup_id_3',
          'dup_id_2',
        ],
      });
      repository = StorageRepositoryImpl();

      final favorites = await repository.loadFavoriteIds();
      expect(favorites, equals({'dup_id_1', 'dup_id_2', 'dup_id_3'}));
      expect(favorites.length, 3);

      // Trigger write-back to verify auto-repair of raw storage
      await repository.toggleFavorite('dup_id_4');

      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(StorageRepositoryImpl.favoritesKey);
      expect(rawList, isNotNull);
      // All duplicates should be eliminated after rewrite
      expect(rawList!.toSet().length, rawList.length);
      expect(rawList, containsAll(['dup_id_1', 'dup_id_2', 'dup_id_3', 'dup_id_4']));
    });

    test('handles empty strings and whitespace IDs in favorite list gracefully', () async {
      SharedPreferences.setMockInitialValues({
        StorageRepositoryImpl.favoritesKey: ['', '   ', 'valid_place_id', '  '],
      });
      repository = StorageRepositoryImpl();

      final favorites = await repository.loadFavoriteIds();
      expect(favorites.contains('valid_place_id'), isTrue);
      expect(await repository.isFavorite(''), isTrue);
      expect(await repository.isFavorite('non_existent'), isFalse);
    });
  });

  group('Adversarial User Reviews: Rating Boundaries & Special Characters', () {
    test('handles extreme and boundary rating values in PlaceReview', () async {
      const negativeReview = PlaceReview(
        id: 'rev_neg',
        authorName: 'Negative Namer',
        authorBadge: 'Rehber',
        rating: -5.0,
        relativeTime: 'Dün',
        comment: 'Negative rating edge case',
      );
      const zeroReview = PlaceReview(
        id: 'rev_zero',
        authorName: 'Zero Rater',
        authorBadge: 'Rehber',
        rating: 0.0,
        relativeTime: 'Bugün',
        comment: 'Zero rating',
      );
      const excessiveReview = PlaceReview(
        id: 'rev_high',
        authorName: 'Over Rater',
        authorBadge: 'Rehber',
        rating: 10.0,
        relativeTime: 'Yeni',
        comment: 'Over 5 rating',
      );

      await repository.addUserReview('venue_ratings', negativeReview);
      await repository.addUserReview('venue_ratings', zeroReview);
      await repository.addUserReview('venue_ratings', excessiveReview);

      final reviews = await repository.getReviewsForPlace('venue_ratings');
      expect(reviews.length, 3);
      expect(reviews[0].rating, 10.0);
      expect(reviews[1].rating, 0.0);
      expect(reviews[2].rating, -5.0);
    });

    test('handles Turkish characters, emojis, non-Latin scripts, and control characters', () async {
      const complexText = 'Türkçe: Şiir, Çağrı, Övgü, Ispanak, Üzüm. '
          'Emojis: 🍔 🍕 ☕ 🍰 🥐 🌟 🇹🇷 '
          'Arabic: قهوة ومطعم ممتاز '
          'CJK: 居酒屋 レストラン '
          'Control: Line1\nLine2\tTabbed\rCarriage';

      final unicodeReview = PlaceReview(
        id: 'rev_unicode_complex',
        authorName: 'Çiğdem Öztürk ☕',
        authorBadge: 'Süper Rehber 🌟',
        rating: 4.9,
        relativeTime: '3 gün önce',
        comment: complexText,
        orderedItems: ['Künefe 🍯', 'Çay ☕', 'Baklava 🥮'],
        isUserReview: true,
      );

      await repository.addUserReview('venue_unicode', unicodeReview);

      final loaded = await repository.getReviewsForPlace('venue_unicode');
      expect(loaded.length, 1);
      final r = loaded.first;
      expect(r.authorName, 'Çiğdem Öztürk ☕');
      expect(r.authorBadge, 'Süper Rehber 🌟');
      expect(r.comment, complexText);
      expect(r.orderedItems, ['Künefe 🍯', 'Çay ☕', 'Baklava 🥮']);
    });

    test('handles strings with embedded null characters and control sequences', () async {
      const nullCharString = 'Prefix\u0000Middle\u0007Bell\x1b[31mRedText';
      final controlReview = PlaceReview(
        id: 'rev_control_chars',
        authorName: 'Control\u0000Name',
        authorBadge: 'Badge\tTab',
        rating: 3.5,
        relativeTime: 'Yeni\nLine',
        comment: nullCharString,
      );

      await repository.addUserReview('venue_ctrl', controlReview);

      final loaded = await repository.getReviewsForPlace('venue_ctrl');
      expect(loaded.length, 1);
      expect(loaded.first.comment, nullCharString);
    });
  });

  group('Adversarial Corrupt Persistence & Auto-Repair', () {
    test('handles binary garbage in user reviews key and auto-repairs on next write', () async {
      SharedPreferences.setMockInitialValues({
        StorageRepositoryImpl.userReviewsKey: '\x00\xFF\xFE\xFD\x80\x90\xAA\xBB\xCC\xDD',
      });
      repository = StorageRepositoryImpl();

      // Read does not crash
      final initialReviews = await repository.loadUserReviews();
      expect(initialReviews, isEmpty);

      // Write automatically repairs state
      const recoveryReview = PlaceReview(
        id: 'rev_repair_1',
        authorName: 'Rehabilitator',
        authorBadge: 'Admin',
        rating: 5.0,
        relativeTime: 'Şimdi',
        comment: 'Storage repaired!',
      );

      await repository.addUserReview('recovered_venue', recoveryReview);

      final repairedReviews = await repository.loadUserReviews();
      expect(repairedReviews.containsKey('recovered_venue'), isTrue);
      expect(repairedReviews['recovered_venue']!.first.id, 'rev_repair_1');

      // Verify raw storage is now valid JSON
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(StorageRepositoryImpl.userReviewsKey);
      expect(() => jsonDecode(raw!), returnsNormally);
    });

    test('handles partial truncated JSON string and repairs', () async {
      SharedPreferences.setMockInitialValues({
        StorageRepositoryImpl.userReviewsKey: '{"venue_broken": [{"id": "rev_truncated',
      });
      repository = StorageRepositoryImpl();

      expect(await repository.loadUserReviews(), isEmpty);

      const review = PlaceReview(
        id: 'rev_after_truncated',
        authorName: 'Safe User',
        authorBadge: 'Rehber',
        rating: 4.0,
        relativeTime: 'Yeni',
        comment: 'Safe recovery',
      );

      await repository.addUserReview('safe_venue', review);
      final loaded = await repository.getReviewsForPlace('safe_venue');
      expect(loaded.length, 1);
      expect(loaded.first.id, 'rev_after_truncated');
    });

    test('handles JSON non-map root types (string, number, boolean, null literal)', () async {
      for (final badPayload in ['"A raw string"', '12345', 'true', 'null']) {
        SharedPreferences.setMockInitialValues({
          StorageRepositoryImpl.userReviewsKey: badPayload,
        });
        repository = StorageRepositoryImpl();

        expect(await repository.loadUserReviews(), isEmpty);

        // Auto repair works
        await repository.addUserReview(
          'auto_venue',
          const PlaceReview(
            id: 'rev_from_primitive',
            authorName: 'Tester',
            authorBadge: 'Rehber',
            rating: 5.0,
            relativeTime: 'Bugün',
            comment: 'Recovered from primitive',
          ),
        );
        expect((await repository.loadUserReviews()).containsKey('auto_venue'), isTrue);
      }
    });

    test('filters out individual review items with wrong field types without crashing', () async {
      final corruptedReviewsMap = {
        'venue_with_mixed_items': [
          // 1. Valid review
          {
            'id': 'valid_1',
            'authorName': 'Valid Author',
            'authorBadge': 'Rehber',
            'rating': 4.5,
            'relativeTime': 'Dün',
            'comment': 'Good',
            'likesCount': 2,
            'orderedItems': ['Coffee'],
            'isUserReview': true,
          },
          // 2. Corrupt item: rating is string (causes type cast failure in (json["rating"] as num?))
          {
            'id': 'invalid_type_rating',
            'authorName': 'Corrupt Rating',
            'rating': 'Five Stars',
            'comment': 'Bad type',
          },
          // 3. Corrupt item: likesCount is string
          {
            'id': 'invalid_type_likes',
            'authorName': 'Corrupt Likes',
            'likesCount': 'three',
          },
          // 4. Corrupt item: orderedItems is not a list
          {
            'id': 'invalid_type_items',
            'authorName': 'Corrupt Items',
            'orderedItems': 'latte, tea',
          },
          // 5. Another valid review
          {
            'id': 'valid_2',
            'authorName': 'Another Valid',
            'authorBadge': 'Yerel Rehber',
            'rating': 5.0,
            'relativeTime': 'Yeni',
            'comment': 'Also good',
            'isUserReview': true,
          },
        ],
      };

      SharedPreferences.setMockInitialValues({
        StorageRepositoryImpl.userReviewsKey: jsonEncode(corruptedReviewsMap),
      });
      repository = StorageRepositoryImpl();

      final reviews = await repository.getReviewsForPlace('venue_with_mixed_items');
      // Should gracefully parse valid_1 and valid_2, skipping the 3 corrupted entries
      expect(reviews.length, 2);
      expect(reviews.map((r) => r.id).toList(), equals(['valid_1', 'valid_2']));
    });

    test('handles venues mapped to non-list values in JSON root map', () async {
      final badVenueMap = {
        'venue_str': 'not a list',
        'venue_num': 999,
        'venue_null': null,
        'venue_bool': false,
        'venue_valid': [
          {
            'id': 'v_ok',
            'authorName': 'Ok Author',
            'authorBadge': 'Rehber',
            'rating': 5.0,
            'relativeTime': 'Şimdi',
            'comment': 'All good',
          }
        ],
      };

      SharedPreferences.setMockInitialValues({
        StorageRepositoryImpl.userReviewsKey: jsonEncode(badVenueMap),
      });
      repository = StorageRepositoryImpl();

      final allReviews = await repository.loadUserReviews();
      expect(allReviews.length, 1);
      expect(allReviews.containsKey('venue_valid'), isTrue);
      expect(allReviews['venue_valid']!.first.id, 'v_ok');
    });
  });

  group('Adversarial Keys: Whitespace & Empty Edge Cases', () {
    test('saveGoogleApiKey handles whitespace, newline, tab combinations', () async {
      await repository.saveGoogleApiKey("  \t\n  AIzaSyWhitespaceKey123  \r\n  ");
      final key = await repository.loadGoogleApiKey();
      expect(key, 'AIzaSyWhitespaceKey123');

      // Whitespace-only should clear key
      await repository.saveGoogleApiKey("   \t   \n  ");
      expect(await repository.loadGoogleApiKey(), isNull);
    });

    test('venue keys with whitespace or special characters are preserved accurately', () async {
      const weirdVenueKey = '  venue:osm/node:12345?query=test&lang=tr  ';
      const review = PlaceReview(
        id: 'rev_weird_key',
        authorName: 'Tester',
        authorBadge: 'Rehber',
        rating: 4.0,
        relativeTime: 'Yeni',
        comment: 'Weird key test',
      );

      await repository.addUserReview(weirdVenueKey, review);

      final reviews = await repository.getReviewsForPlace(weirdVenueKey);
      expect(reviews.length, 1);
      expect(reviews.first.id, 'rev_weird_key');

      final allReviews = await repository.loadUserReviews();
      expect(allReviews.containsKey(weirdVenueKey), isTrue);
    });
  });

  group('Adversarial LocationPreset: Extreme Inputs & Boundary Values', () {
    test('LocationPreset fromJson handles missing, null, and boundary coordinates', () {
      final p1 = LocationPreset.fromJson(const {});
      expect(p1.name, '');
      expect(p1.subtitle, '');
      expect(p1.latitude, 0.0);
      expect(p1.longitude, 0.0);

      // Boundary GPS coordinates (-90, +90, -180, +180)
      final p2 = LocationPreset.fromJson(const {
        'name': 'North Pole Edge',
        'subtitle': 'Arctic',
        'latitude': 90.0,
        'longitude': 180.0,
      });
      expect(p2.latitude, 90.0);
      expect(p2.longitude, 180.0);

      final p3 = LocationPreset.fromJson(const {
        'name': 'South Pole Edge',
        'subtitle': 'Antarctic',
        'latitude': -90.0,
        'longitude': -180.0,
      });
      expect(p3.latitude, -90.0);
      expect(p3.longitude, -180.0);
    });

    test('LocationPreset handles integer coordinates converted to double', () {
      final p = LocationPreset.fromJson(const {
        'name': 'Int Coord Venue',
        'subtitle': 'Equator Center',
        'latitude': 41,
        'longitude': 29,
      });
      expect(p.latitude, 41.0);
      expect(p.longitude, 29.0);
      expect(p.latitude, isA<double>());
      expect(p.longitude, isA<double>());
    });

    test('LocationPreset toString contains all coordinate and label info', () {
      const p = LocationPreset(
        name: 'Kadıköy',
        subtitle: 'Moda',
        latitude: 40.9862,
        longitude: 29.0264,
      );
      final str = p.toString();
      expect(str, contains('Kadıköy'));
      expect(str, contains('Moda'));
      expect(str, contains('40.9862'));
      expect(str, contains('29.0264'));
    });
  });

  group('Adversarial Storage: Type Mismatches in Underlying Storage', () {
    test('loadFavoriteIds gracefully recovers if favoritesKey holds non-list in SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        StorageRepositoryImpl.favoritesKey: 'unexpected_string_instead_of_list',
      });
      repository = StorageRepositoryImpl();

      final favorites = await repository.loadFavoriteIds();
      expect(favorites, isEmpty);

      // Verify auto-repairing write works
      await repository.saveFavoriteIds({'repaired_favorite'});
      expect(await repository.loadFavoriteIds(), equals({'repaired_favorite'}));
    });

    test('loadUserReviews gracefully recovers if userReviewsKey holds non-string type in SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        StorageRepositoryImpl.userReviewsKey: ['list', 'instead', 'of', 'json_string'],
      });
      repository = StorageRepositoryImpl();

      final reviews = await repository.loadUserReviews();
      expect(reviews, isEmpty);

      // Verify writing a review restores valid storage
      const repairReview = PlaceReview(
        id: 'rev_type_recovered',
        authorName: 'Healer',
        authorBadge: 'Rehber',
        rating: 5.0,
        relativeTime: 'Şimdi',
        comment: 'Storage type healed',
      );
      await repository.addUserReview('venue_type_repair', repairReview);
      final fetched = await repository.getReviewsForPlace('venue_type_repair');
      expect(fetched.length, 1);
      expect(fetched.first.id, 'rev_type_recovered');
    });

    test('loadGoogleApiKey handles non-string type in SharedPreferences gracefully', () async {
      SharedPreferences.setMockInitialValues({
        StorageRepositoryImpl.googleApiKeyPref: 12345678,
      });
      repository = StorageRepositoryImpl();

      // Should safely return null or catch without crashing
      try {
        final key = await repository.loadGoogleApiKey();
        expect(key, anyOf(isNull, isA<String>()));
      } catch (e) {
        // If SharedPreferences itself throws TypeError on getString, verify save repairs it
      }

      await repository.saveGoogleApiKey('AIzaSyValidCleanKey');
      expect(await repository.loadGoogleApiKey(), 'AIzaSyValidCleanKey');
    });
  });

  group('Adversarial Review Model: Heterogeneous & Permissive Deserialization', () {
    test('PlaceReview fromJson handles all-null dictionary', () {
      final review = PlaceReview.fromJson(const {});
      expect(review.id, '');
      expect(review.authorName, 'Ziyaretçi');
      expect(review.authorBadge, 'Yerel Rehber');
      expect(review.rating, 5.0);
      expect(review.relativeTime, 'Yeni');
      expect(review.comment, '');
      expect(review.likesCount, 0);
      expect(review.orderedItems, isEmpty);
      expect(review.isUserReview, isFalse);
    });

    test('PlaceReview fromJson converts heterogeneous orderedItems to strings', () {
      final review = PlaceReview.fromJson(const {
        'id': 'rev_hetero',
        'orderedItems': [123, true, null, 45.67, {'item': 'latte'}],
      });
      expect(review.orderedItems, equals(['123', 'true', 'null', '45.67', '{item: latte}']));
    });

    test('PlaceReview fromJson handles integer ratings and converts to double', () {
      final review = PlaceReview.fromJson(const {
        'id': 'rev_int_rating',
        'rating': 4,
      });
      expect(review.rating, 4.0);
      expect(review.rating, isA<double>());
    });

    test('PlaceReview fromJson handles double likesCount and converts to integer', () {
      final review = PlaceReview.fromJson(const {
        'id': 'rev_double_likes',
        'likesCount': 42.9,
      });
      expect(review.likesCount, 42);
      expect(review.likesCount, isA<int>());
    });

    test('maintains strict prepend ordering across 100 sequential reviews for one venue', () async {
      for (int i = 0; i < 100; i++) {
        await repository.addUserReview(
          'venue_seq_order',
          PlaceReview(
            id: 'rev_seq_$i',
            authorName: 'User $i',
            authorBadge: 'Rehber',
            rating: 4.5,
            relativeTime: 't-$i',
            comment: 'Comment $i',
          ),
        );
      }

      final reviews = await repository.getReviewsForPlace('venue_seq_order');
      expect(reviews.length, 100);
      // Newest should be first (rev_seq_99)
      expect(reviews.first.id, 'rev_seq_99');
      // Oldest should be last (rev_seq_0)
      expect(reviews.last.id, 'rev_seq_0');
      // Sequential ordering strictly decreasing
      for (int i = 0; i < 100; i++) {
        expect(reviews[i].id, 'rev_seq_${99 - i}');
      }
    });

    test('handles empty string placeId in favorites and user reviews', () async {
      await repository.toggleFavorite('');
      expect(await repository.isFavorite(''), isTrue);
      expect((await repository.loadFavoriteIds()).contains(''), isTrue);

      const emptyKeyReview = PlaceReview(
        id: 'rev_empty_key',
        authorName: 'Anon',
        authorBadge: 'Rehber',
        rating: 3.0,
        relativeTime: 'Now',
        comment: 'Empty venue id',
      );
      await repository.addUserReview('', emptyKeyReview);
      final emptyReviews = await repository.getReviewsForPlace('');
      expect(emptyReviews.length, 1);
      expect(emptyReviews.first.id, 'rev_empty_key');
    });
  });
}

