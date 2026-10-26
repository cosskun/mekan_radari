import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/place_model.dart';

class StorageService {
  static const String _favoritesKey = 'favorite_place_ids_v1';
  static const String _userReviewsKey = 'user_place_reviews_v1';
  static const String _googleApiKeyPref = 'google_places_api_key_v1';

  static Future<Set<String>> loadFavoriteIds() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_favoritesKey) ?? [];
    return list.toSet();
  }

  static Future<void> saveFavoriteIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, ids.toList());
  }

  static Future<Map<String, List<PlaceReview>>> loadUserReviews() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userReviewsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final Map<String, dynamic> decoded = jsonDecode(raw);
      final Map<String, List<PlaceReview>> result = {};
      decoded.forEach((placeId, listDynamic) {
        if (listDynamic is List) {
          result[placeId] = listDynamic
              .map((e) => PlaceReview.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  static Future<void> addUserReview(String placeId, PlaceReview review) async {
    final current = await loadUserReviews();
    final list = current[placeId] ?? [];
    current[placeId] = [review, ...list];

    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      current.map(
        (key, value) => MapEntry(key, value.map((r) => r.toJson()).toList()),
      ),
    );
    await prefs.setString(_userReviewsKey, encoded);
  }

  static Future<String?> loadGoogleApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_googleApiKeyPref);
  }

  static Future<void> saveGoogleApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    if (apiKey.trim().isEmpty) {
      await prefs.remove(_googleApiKeyPref);
    } else {
      await prefs.setString(_googleApiKeyPref, apiKey.trim());
    }
  }
}
