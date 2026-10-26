import '../models/place_model.dart';

abstract class StorageRepository {
  /// Loads the set of favorite place IDs.
  Future<Set<String>> loadFavoriteIds();

  /// Saves the set of favorite place IDs.
  Future<void> saveFavoriteIds(Set<String> ids);

  /// Toggles favorite status for a place ID (adds if absent, removes if present).
  Future<void> toggleFavorite(String placeId);

  /// Checks if a place ID is marked as favorite.
  Future<bool> isFavorite(String placeId);

  /// Loads all user reviews grouped by place ID.
  Future<Map<String, List<PlaceReview>>> loadUserReviews();

  /// Gets all user reviews for a specific place ID.
  Future<List<PlaceReview>> getReviewsForPlace(String placeId);

  /// Adds a user review for a specific place and persists it.
  Future<void> addUserReview(String placeId, PlaceReview review);

  /// Loads the saved Google Places API key, or null if not set.
  Future<String?> loadGoogleApiKey();

  /// Saves the Google Places API key. If empty or whitespace, removes it.
  Future<void> saveGoogleApiKey(String apiKey);
}
