import 'package:mekan_radari/models/place_model.dart';
import 'package:mekan_radari/repositories/storage_repository.dart';

class FakeStorageRepository implements StorageRepository {
  final Set<String> _favorites = {};
  final Map<String, List<PlaceReview>> _reviews = {};
  String? _googleApiKey;

  FakeStorageRepository({
    Set<String>? initialFavorites,
    Map<String, List<PlaceReview>>? initialReviews,
    String? initialGoogleApiKey,
  }) {
    if (initialFavorites != null) _favorites.addAll(initialFavorites);
    if (initialReviews != null) {
      initialReviews.forEach((k, v) => _reviews[k] = List.of(v));
    }
    _googleApiKey = initialGoogleApiKey;
  }

  @override
  Future<Set<String>> loadFavoriteIds() async => Set.of(_favorites);

  @override
  Future<void> saveFavoriteIds(Set<String> ids) async {
    _favorites.clear();
    _favorites.addAll(ids);
  }

  @override
  Future<void> toggleFavorite(String placeId) async {
    if (_favorites.contains(placeId)) {
      _favorites.remove(placeId);
    } else {
      _favorites.add(placeId);
    }
  }

  @override
  Future<bool> isFavorite(String placeId) async => _favorites.contains(placeId);

  @override
  Future<Map<String, List<PlaceReview>>> loadUserReviews() async {
    return _reviews.map((k, v) => MapEntry(k, List.of(v)));
  }

  @override
  Future<List<PlaceReview>> getReviewsForPlace(String placeId) async {
    return List.of(_reviews[placeId] ?? const []);
  }

  @override
  Future<void> addUserReview(String placeId, PlaceReview review) async {
    final list = _reviews[placeId] ?? [];
    _reviews[placeId] = [review, ...list];
  }

  @override
  Future<String?> loadGoogleApiKey() async => _googleApiKey;

  @override
  Future<void> saveGoogleApiKey(String apiKey) async {
    if (apiKey.trim().isEmpty) {
      _googleApiKey = null;
    } else {
      _googleApiKey = apiKey.trim();
    }
  }
}
