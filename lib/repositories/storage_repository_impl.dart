import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/place_model.dart';
import 'storage_repository.dart';

class StorageRepositoryImpl implements StorageRepository {
  static const String favoritesKey = 'favorite_place_ids_v1';
  static const String userReviewsKey = 'user_place_reviews_v1';
  static const String googleApiKeyPref = 'google_places_api_key_v1';

  SharedPreferences? prefs;

  StorageRepositoryImpl({this.prefs});

  Future<SharedPreferences> _getPrefs() async {
    return prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<Set<String>> loadFavoriteIds() async {
    try {
      final prefs = await _getPrefs();
      final list = prefs.getStringList(favoritesKey);
      return list?.toSet() ?? <String>{};
    } catch (_) {
      return <String>{};
    }
  }

  @override
  Future<void> saveFavoriteIds(Set<String> ids) async {
    final prefs = await _getPrefs();
    await prefs.setStringList(favoritesKey, ids.toList());
  }

  @override
  Future<void> toggleFavorite(String placeId) async {
    final favorites = await loadFavoriteIds();
    if (favorites.contains(placeId)) {
      favorites.remove(placeId);
    } else {
      favorites.add(placeId);
    }
    await saveFavoriteIds(favorites);
  }

  @override
  Future<bool> isFavorite(String placeId) async {
    final favorites = await loadFavoriteIds();
    return favorites.contains(placeId);
  }

  @override
  Future<Map<String, List<PlaceReview>>> loadUserReviews() async {
    try {
      final prefs = await _getPrefs();
      final raw = prefs.getString(userReviewsKey);
      if (raw == null || raw.trim().isEmpty) return {};

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};

      final Map<String, List<PlaceReview>> result = {};
      decoded.forEach((placeId, listDynamic) {
        if (listDynamic is List) {
          final reviews = <PlaceReview>[];
          for (final item in listDynamic) {
            try {
              if (item is Map) {
                reviews.add(PlaceReview.fromJson(Map<String, dynamic>.from(item)));
              }
            } catch (_) {
              // Gracefully skip individual malformed review entry
            }
          }
          if (reviews.isNotEmpty) {
            result[placeId.toString()] = reviews;
          }
        }
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  @override
  Future<List<PlaceReview>> getReviewsForPlace(String placeId) async {
    final allReviews = await loadUserReviews();
    return allReviews[placeId] ?? const <PlaceReview>[];
  }

  @override
  Future<void> addUserReview(String placeId, PlaceReview review) async {
    final current = await loadUserReviews();
    final list = current[placeId] ?? <PlaceReview>[];
    current[placeId] = [review, ...list];

    final prefs = await _getPrefs();
    final encoded = jsonEncode(
      current.map(
        (key, value) => MapEntry(key, value.map((r) => r.toJson()).toList()),
      ),
    );
    await prefs.setString(userReviewsKey, encoded);
  }

  @override
  Future<String?> loadGoogleApiKey() async {
    final prefs = await _getPrefs();
    final key = prefs.getString(googleApiKeyPref);
    if (key == null || key.trim().isEmpty) return null;
    return key.trim();
  }

  @override
  Future<void> saveGoogleApiKey(String apiKey) async {
    final prefs = await _getPrefs();
    if (apiKey.trim().isEmpty) {
      await prefs.remove(googleApiKeyPref);
    } else {
      await prefs.setString(googleApiKeyPref, apiKey.trim());
    }
  }
}
