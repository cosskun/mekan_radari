import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
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

  group('Favorites Persistence', () {
    test('loadFavoriteIds returns empty set when storage is empty', () async {
      final favorites = await repository.loadFavoriteIds();
      expect(favorites, isEmpty);
    });

    test('loadFavoriteIds loads stored favorite IDs correctly', () async {
      SharedPreferences.setMockInitialValues({
        StorageRepositoryImpl.favoritesKey: ['place_1', 'place_2'],
      });
      repository = StorageRepositoryImpl();

      final favorites = await repository.loadFavoriteIds();
      expect(favorites, {'place_1', 'place_2'});
    });

    test('saveFavoriteIds persists IDs to SharedPreferences', () async {
      await repository.saveFavoriteIds({'fav_a', 'fav_b'});

      final loaded = await repository.loadFavoriteIds();
      expect(loaded, {'fav_a', 'fav_b'});

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList(StorageRepositoryImpl.favoritesKey),
        unorderedEquals(['fav_a', 'fav_b']),
      );
    });

    test('toggleFavorite adds ID when not already in favorites', () async {
      await repository.toggleFavorite('place_new');

      expect(await repository.isFavorite('place_new'), isTrue);
      expect(await repository.loadFavoriteIds(), contains('place_new'));
    });

    test('toggleFavorite removes ID when already present in favorites', () async {
      SharedPreferences.setMockInitialValues({
        StorageRepositoryImpl.favoritesKey: ['place_existing'],
      });
      repository = StorageRepositoryImpl();

      expect(await repository.isFavorite('place_existing'), isTrue);

      await repository.toggleFavorite('place_existing');

      expect(await repository.isFavorite('place_existing'), isFalse);
      expect(await repository.loadFavoriteIds(), isEmpty);
    });

    test('isFavorite returns false for unknown place ID', () async {
      expect(await repository.isFavorite('unknown_id'), isFalse);
    });
  });

  group('User Reviews Persistence & Serialization', () {
    const sampleReview1 = PlaceReview(
      id: 'rev_1',
      authorName: 'Canan Kaya',
      authorBadge: 'Tatlı Gurmesi',
      rating: 5.0,
      relativeTime: '1 gün önce',
      comment: 'San Sebastian enfesti!',
      likesCount: 3,
      orderedItems: ['San Sebastian Cheesecake', 'Filtre Kahve'],
      isUserReview: true,
    );

    const sampleReview2 = PlaceReview(
      id: 'rev_2',
      authorName: 'Mehmet Demir',
      authorBadge: 'Yerel Rehber',
      rating: 4.0,
      relativeTime: '2 gün önce',
      comment: 'Kahvesi çok iyi, mekan biraz kalabalıktı.',
      likesCount: 1,
      orderedItems: ['Latte'],
      isUserReview: true,
    );

    test('loadUserReviews returns empty map when storage is empty', () async {
      final reviews = await repository.loadUserReviews();
      expect(reviews, isEmpty);
    });

    test('addUserReview saves review and persists JSON', () async {
      await repository.addUserReview('place_101', sampleReview1);

      final reviews = await repository.getReviewsForPlace('place_101');
      expect(reviews.length, 1);
      expect(reviews.first.toJson(), equals(sampleReview1.toJson()));

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(StorageRepositoryImpl.userReviewsKey);
      expect(raw, isNotNull);
      final decoded = jsonDecode(raw!) as Map<String, dynamic>;
      expect(decoded.containsKey('place_101'), isTrue);
    });

    test('addUserReview prepends newer review for same venue', () async {
      await repository.addUserReview('place_101', sampleReview1);
      await repository.addUserReview('place_101', sampleReview2);

      final reviews = await repository.getReviewsForPlace('place_101');
      expect(reviews.length, 2);
      expect(reviews[0].id, equals('rev_2'));
      expect(reviews[1].id, equals('rev_1'));
    });

    test('addUserReview keeps independent lists for different venues', () async {
      await repository.addUserReview('place_a', sampleReview1);
      await repository.addUserReview('place_b', sampleReview2);

      final reviewsA = await repository.getReviewsForPlace('place_a');
      final reviewsB = await repository.getReviewsForPlace('place_b');

      expect(reviewsA.length, 1);
      expect(reviewsA.first.id, 'rev_1');

      expect(reviewsB.length, 1);
      expect(reviewsB.first.id, 'rev_2');
    });

    test('getReviewsForPlace returns empty list for unknown venue', () async {
      final reviews = await repository.getReviewsForPlace('non_existent');
      expect(reviews, isEmpty);
    });
  });

  group('Error Resilience & Corrupt Data Handling', () {
    test('loadUserReviews returns empty map on malformed JSON syntax', () async {
      SharedPreferences.setMockInitialValues({
        StorageRepositoryImpl.userReviewsKey: '{corrupt json @@#!',
      });
      repository = StorageRepositoryImpl();

      final reviews = await repository.loadUserReviews();
      expect(reviews, isEmpty);
    });

    test('loadUserReviews returns empty map on non-map JSON root', () async {
      SharedPreferences.setMockInitialValues({
        StorageRepositoryImpl.userReviewsKey: jsonEncode(['not', 'a', 'map']),
      });
      repository = StorageRepositoryImpl();

      final reviews = await repository.loadUserReviews();
      expect(reviews, isEmpty);
    });

    test('loadUserReviews skips individual malformed review without dropping valid ones', () async {
      final mixedData = {
        'place_1': [
          {
            'id': 'valid_rev',
            'authorName': 'Ahmet',
            'authorBadge': 'Yerel Rehber',
            'rating': 5.0,
            'relativeTime': 'Yeni',
            'comment': 'Harika',
            'isUserReview': true,
          },
          'invalid_non_map_string',
        ],
      };

      SharedPreferences.setMockInitialValues({
        StorageRepositoryImpl.userReviewsKey: jsonEncode(mixedData),
      });
      repository = StorageRepositoryImpl();

      final reviews = await repository.getReviewsForPlace('place_1');
      expect(reviews.length, 1);
      expect(reviews.first.id, 'valid_rev');
    });

    test('addUserReview safely overwrites corrupt storage and repairs state', () async {
      SharedPreferences.setMockInitialValues({
        StorageRepositoryImpl.userReviewsKey: '###malformed###',
      });
      repository = StorageRepositoryImpl();

      const freshReview = PlaceReview(
        id: 'rev_repaired',
        authorName: 'Selin',
        authorBadge: 'Rehber',
        rating: 5.0,
        relativeTime: 'Yeni',
        comment: 'Kurtarıldı',
        isUserReview: true,
      );

      await repository.addUserReview('place_recovered', freshReview);

      final reviews = await repository.getReviewsForPlace('place_recovered');
      expect(reviews.length, 1);
      expect(reviews.first.id, 'rev_repaired');
    });
  });

  group('Google Places API Key Persistence', () {
    test('loadGoogleApiKey returns null when no key stored', () async {
      final key = await repository.loadGoogleApiKey();
      expect(key, isNull);
    });

    test('saveGoogleApiKey trims and stores key', () async {
      await repository.saveGoogleApiKey('   AIzaSyD_ValidSecretKey   ');

      final key = await repository.loadGoogleApiKey();
      expect(key, 'AIzaSyD_ValidSecretKey');

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(StorageRepositoryImpl.googleApiKeyPref),
        'AIzaSyD_ValidSecretKey',
      );
    });

    test('saveGoogleApiKey removes key when empty or whitespace provided', () async {
      SharedPreferences.setMockInitialValues({
        StorageRepositoryImpl.googleApiKeyPref: 'existing_key',
      });
      repository = StorageRepositoryImpl();

      await repository.saveGoogleApiKey('   ');

      final key = await repository.loadGoogleApiKey();
      expect(key, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.containsKey(StorageRepositoryImpl.googleApiKeyPref),
        isFalse,
      );
    });
  });

  group('Dependency Injection', () {
    test('works with pre-injected SharedPreferences instance', () async {
      SharedPreferences.setMockInitialValues({
        StorageRepositoryImpl.favoritesKey: ['injected_fav'],
      });
      final customPrefs = await SharedPreferences.getInstance();
      final customRepo = StorageRepositoryImpl(prefs: customPrefs);

      expect(await customRepo.isFavorite('injected_fav'), isTrue);
    });
  });
}
