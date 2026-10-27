import 'package:flutter/foundation.dart';

import '../models/location_preset.dart';
import '../models/place_model.dart';
import '../repositories/places_repository.dart';
import '../repositories/places_repository_impl.dart';
import '../repositories/storage_repository.dart';
import '../repositories/storage_repository_impl.dart';

/// Sorting options for filtered venues.
enum SortOption { distance, rating, reviews }

/// State controller for venue discovery, filtering, search, and user interactions.
class PlacesController extends ChangeNotifier {
  final PlacesRepository _placesRepository;
  final StorageRepository _storageRepository;

  // Lifecycle & Race condition guards
  bool _isDisposed = false;
  int _loadRequestId = 0;

  // Center Coordinates & Location Label
  double _centerLat;
  double _centerLon;
  String _locationLabel;

  // Filter & Search State
  String _searchQuery = '';
  String _selectedCategoryId;
  double _radiusMeters;
  double _minRating;
  int _minReviewCount;
  SortOption _sortOption;

  // UI View Modes
  bool _isMapView = false;
  bool _showFavoritesOnly = false;
  bool _isLoading = false;
  String? _statusMessage;

  // Venue & Persistence Data
  List<Place> _rawPlaces = const [];
  List<Place> _allPlaces = const [];
  Set<String> _favoriteIds = <String>{};
  Map<String, List<PlaceReview>> _userReviewsMap = <String, List<PlaceReview>>{};
  String? _googleApiKey;

  /// Creates a [PlacesController] with optional dependency injection.
  PlacesController({
    PlacesRepository? placesRepository,
    StorageRepository? storageRepository,
    double initialLat = 40.9862,
    double initialLon = 29.0264,
    String initialLocationLabel = 'Kadıköy - Moda & Çarşı',
    double initialRadiusMeters = 500.0,
    String initialCategoryId = 'dessert',
    double initialMinRating = 4.5,
    int initialMinReviewCount = 0,
    SortOption initialSortOption = SortOption.distance,
  })  : _placesRepository = placesRepository ?? PlacesRepositoryImpl(),
        _storageRepository = storageRepository ?? StorageRepositoryImpl(),
        _centerLat = initialLat,
        _centerLon = initialLon,
        _locationLabel = initialLocationLabel,
        _radiusMeters = initialRadiusMeters.isNaN
            ? 500.0
            : initialRadiusMeters.clamp(50.0, 3000.0),
        _selectedCategoryId = initialCategoryId,
        _minRating = initialMinRating.isNaN
            ? 4.5
            : initialMinRating.clamp(0.0, 5.0),
        _minReviewCount = initialMinReviewCount < 0 ? 0 : initialMinReviewCount,
        _sortOption = initialSortOption;

  // --- Getters ---

  double get centerLat => _centerLat;
  double get centerLon => _centerLon;
  String get locationLabel => _locationLabel;
  String get searchQuery => _searchQuery;
  String get selectedCategoryId => _selectedCategoryId;
  double get radiusMeters => _radiusMeters;
  double get minRating => _minRating;
  int get minReviewCount => _minReviewCount;
  SortOption get sortOption => _sortOption;
  bool get isMapView => _isMapView;
  bool get showFavoritesOnly => _showFavoritesOnly;
  bool get isLoading => _isLoading;
  String? get statusMessage => _statusMessage;
  String? get googleApiKey => _googleApiKey;
  bool get isDisposed => _isDisposed;

  List<Place> get allPlaces => List.unmodifiable(_allPlaces);

  List<Place> get filteredPlaces {
    final filtered = filterPlaces(
      places: _allPlaces,
      selectedCategoryId: _selectedCategoryId,
      radiusMeters: _radiusMeters,
      minRating: _minRating,
      minReviewCount: _minReviewCount,
      searchQuery: _searchQuery,
      showFavoritesOnly: _showFavoritesOnly,
      favoriteIds: _favoriteIds,
    );
    return List<Place>.unmodifiable(
      sortPlaces(places: filtered, sortOption: _sortOption),
    );
  }

  Place? get closestPlaceOutsideRadius {
    if (filteredPlaces.isNotEmpty) return null;
    return findClosestPlaceOutsideRadius(
      places: _allPlaces,
      selectedCategoryId: _selectedCategoryId,
      radiusMeters: _radiusMeters,
      minRating: _minRating,
      searchQuery: _searchQuery,
    );
  }

  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);
  Map<String, List<PlaceReview>> get userReviewsMap => Map.unmodifiable(
        _userReviewsMap.map(
          (k, v) => MapEntry(k, List<PlaceReview>.unmodifiable(v)),
        ),
      );

  bool isFavorite(String placeId) => _favoriteIds.contains(placeId);

  // --- Pure Static Business Logic Methods ---

  static final RegExp _wordDelimiterRegex =
      RegExp(r'''[\s,\./\-_&+()!?:;"'’*|]+''');

  /// Converts [text] to lowercase applying Turkish case-folding rules:
  /// Uppercase 'I' (U+0049) -> Lowercase 'ı' (U+0131)
  /// Uppercase 'İ' (U+0130) -> Lowercase 'i' (U+0069)
  /// All other characters are lowercased via standard Unicode toLowerCase().
  static String turkishToLower(String text) {
    if (text.isEmpty) return text;
    return text.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();
  }

  /// Normalizes [text] by applying Turkish lowercase, replacing delimiters with
  /// a single space, and wrapping with leading/trailing spaces for boundary matching.
  static String _normalizeForWordMatching(String text) {
    final cleaned =
        turkishToLower(text).replaceAll(_wordDelimiterRegex, ' ').trim();
    return cleaned.isEmpty ? ' ' : ' $cleaned ';
  }

  /// Checks if [place] matches the category by exact label or word-boundary keywords.
  static bool matchesCategory(Place place, PlaceCategoryFilter category) {
    if (category.id == 'all') return true;
    if (place.category == category.label) return true;

    final combinedText =
        '${place.name} ${place.category} ${place.subCategory} ${place.popularItems.join(' ')}';
    return matchesCategoryKeywords(combinedText, category.keywords);
  }

  /// Checks whether [text] contains any of the [keywords] as whole words or compound tokens.
  static bool matchesCategoryKeywords(String text, List<String> keywords) {
    if (keywords.isEmpty) return false;
    final normalizedText = _normalizeForWordMatching(text);
    for (final kw in keywords) {
      final normalizedKw = _normalizeForWordMatching(kw);
      if (normalizedKw.trim().isNotEmpty &&
          normalizedText.contains(normalizedKw)) {
        return true;
      }
    }
    return false;
  }

  /// Calculates weighted rating: (existingRating * existingReviewCount + sum(userRatings)) / newCount
  /// Clamped between 1.0 and 5.0, formatted to 1 decimal place.
  static double calculateWeightedRating({
    required double existingRating,
    required int existingReviewCount,
    required List<double> userRatings,
  }) {
    if (userRatings.isEmpty) return existingRating;
    final userSum = userRatings.fold<double>(0.0, (sum, r) => sum + r);
    final totalScore = (existingRating * existingReviewCount) + userSum;
    final newCount = existingReviewCount + userRatings.length;
    if (newCount == 0) return 0.0;
    return double.parse(
        (totalScore / newCount).clamp(1.0, 5.0).toStringAsFixed(1));
  }

  /// Merges a Place with local user reviews and updates geodesic distance.
  static Place mergePlaceWithUserReviews({
    required Place place,
    required List<PlaceReview> userReviews,
    required double distanceMeters,
  }) {
    if (userReviews.isEmpty) {
      return place.copyWith(distanceMeters: distanceMeters);
    }
    final combinedReviews = [...userReviews, ...place.reviews];
    final userRatings = userReviews.map((r) => r.rating).toList();
    final newRating = calculateWeightedRating(
      existingRating: place.rating,
      existingReviewCount: place.reviewCount,
      userRatings: userRatings,
    );
    final newCount = place.reviewCount + userReviews.length;
    return place.copyWith(
      distanceMeters: distanceMeters,
      reviews: combinedReviews,
      reviewCount: newCount,
      rating: newRating,
    );
  }

  /// Filters a list of places based on favorites, radius, rating, review count,
  /// category match (label and keywords with word boundaries), and search query (Turkish-aware).
  static List<Place> filterPlaces({
    required List<Place> places,
    required String selectedCategoryId,
    required double radiusMeters,
    required double minRating,
    required int minReviewCount,
    required String searchQuery,
    required bool showFavoritesOnly,
    required Set<String> favoriteIds,
  }) {
    final selectedCategory = PlaceCategoryFilter.allCategories.firstWhere(
      (c) => c.id == selectedCategoryId,
      orElse: () => PlaceCategoryFilter.allCategories.first,
    );
    final queryLower = turkishToLower(searchQuery.trim());

    return places.where((place) {
      // 1. Favorites filter
      if (showFavoritesOnly && !favoriteIds.contains(place.id)) {
        return false;
      }

      // 2. Distance filter (strictly within radius)
      if (place.distanceMeters > radiusMeters) {
        return false;
      }

      // 3. Minimum rating filter
      if (place.rating < minRating) {
        return false;
      }

      // 4. Minimum review count filter
      if (place.reviewCount < minReviewCount) {
        return false;
      }

      // 5. Category filter (word-boundary keyword matching)
      if (!matchesCategory(place, selectedCategory)) {
        return false;
      }

      // 6. Search query filter (Turkish-aware case-folding)
      if (queryLower.isNotEmpty) {
        final searchable = turkishToLower(
            '${place.name} ${place.category} ${place.subCategory} ${place.address} ${place.popularItems.join(' ')} ${place.tags.join(' ')}');
        if (!searchable.contains(queryLower)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  /// Sorts places according to distance (ascending), rating (descending with
  /// reviewCount tie-breaker), or reviews (descending).
  static List<Place> sortPlaces({
    required List<Place> places,
    required SortOption sortOption,
  }) {
    final list = List<Place>.of(places);
    switch (sortOption) {
      case SortOption.distance:
        list.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
        break;
      case SortOption.rating:
        list.sort((a, b) {
          final cmp = b.rating.compareTo(a.rating);
          if (cmp != 0) return cmp;
          return b.reviewCount.compareTo(a.reviewCount);
        });
        break;
      case SortOption.reviews:
        list.sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
        break;
    }
    return list;
  }

  /// Finds the closest venue strictly outside current radius matching category, minRating,
  /// and active search query.
  static Place? findClosestPlaceOutsideRadius({
    required List<Place> places,
    required String selectedCategoryId,
    required double radiusMeters,
    required double minRating,
    String searchQuery = '',
  }) {
    final selectedCategory = PlaceCategoryFilter.allCategories.firstWhere(
      (c) => c.id == selectedCategoryId,
      orElse: () => PlaceCategoryFilter.allCategories.first,
    );
    final queryLower = turkishToLower(searchQuery.trim());

    final candidates = places.where((place) {
      if (place.distanceMeters <= radiusMeters) return false;
      if (place.rating < minRating) return false;
      if (!matchesCategory(place, selectedCategory)) return false;

      if (queryLower.isNotEmpty) {
        final searchable = turkishToLower(
            '${place.name} ${place.category} ${place.subCategory} ${place.address} ${place.popularItems.join(' ')} ${place.tags.join(' ')}');
        if (!searchable.contains(queryLower)) {
          return false;
        }
      }

      return true;
    }).toList();

    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return candidates.first;
  }

  /// Calculates the recommended expanded radius to encompass the closest place outside radius.
  static double calculateExpandedRadius(double distanceMeters) {
    return (distanceMeters + 50.0).clamp(100.0, 3000.0);
  }

  // --- Lifecycle & Action Methods ---

  /// Initializes persisted state (favorites, user reviews, API key) from storage.
  /// If [autoLoadPlaces] is true, also triggers [loadPlaces] for the current location.
  Future<void> init({bool autoLoadPlaces = true}) async {
    if (autoLoadPlaces) {
      _isLoading = true;
      _statusMessage = 'Ayarlar ve favoriler yükleniyor...';
      notifyListeners();
    }

    try {
      final favs = await _storageRepository.loadFavoriteIds();
      final revs = await _storageRepository.loadUserReviews();
      final key = await _storageRepository.loadGoogleApiKey();

      _favoriteIds = favs;
      _userReviewsMap = revs.map(
        (k, v) => MapEntry(k, List<PlaceReview>.unmodifiable(v)),
      );
      _googleApiKey = key;
    } catch (_) {
      // Graceful fallback to default empty states if storage read fails
    }

    if (autoLoadPlaces) {
      await loadPlaces();
    } else {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  /// Updates center coordinates and location label, then loads places.
  Future<void> setLocation({
    required double lat,
    required double lon,
    required String label,
  }) async {
    _centerLat = lat;
    _centerLon = lon;
    _locationLabel = label;
    _recomputeAllPlaces();
    notifyListeners();
    await loadPlaces();
  }

  /// Fetches nearby places from [PlacesRepository], merges user reviews,
  /// recalculates distances, and updates loading/error status.
  Future<void> loadPlaces() async {
    final requestId = ++_loadRequestId;
    _isLoading = true;
    _statusMessage = 'Çevredeki gerçek mekanlar taranıyor...';
    notifyListeners();

    try {
      final fetchedPlaces = await _placesRepository.fetchNearbyPlaces(
        lat: _centerLat,
        lon: _centerLon,
        radiusMeters: _radiusMeters,
        googleApiKey: _googleApiKey,
        searchQuery:
            _searchQuery.trim().isNotEmpty ? _searchQuery.trim() : null,
      );

      // Discard stale responses from superseded requests
      if (requestId != _loadRequestId) return;

      _rawPlaces = fetchedPlaces;
      _recomputeAllPlaces();
      _statusMessage = null;
    } catch (e) {
      if (requestId != _loadRequestId) return;
      _statusMessage = 'Mekanlar yüklenirken bir hata oluştu: ${e.toString()}';
    } finally {
      if (requestId == _loadRequestId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Searches addresses or neighborhoods via [PlacesRepository].
  Future<List<LocationPreset>> searchAddress(String query) async {
    if (query.trim().isEmpty) return const [];
    try {
      return await _placesRepository.searchAddress(query);
    } catch (_) {
      return const [];
    }
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  void setCategoryId(String categoryId) {
    if (_selectedCategoryId == categoryId) return;
    _selectedCategoryId = categoryId;
    notifyListeners();
  }

  void setRadiusMeters(double radius) {
    if (radius.isNaN) return;
    final clamped = radius.clamp(50.0, 3000.0);
    if (_radiusMeters == clamped) return;
    _radiusMeters = clamped;
    notifyListeners();
  }

  void expandRadiusToClosestPlace() {
    final closest = closestPlaceOutsideRadius;
    if (closest != null) {
      setRadiusMeters(calculateExpandedRadius(closest.distanceMeters));
    }
  }

  void setMinRating(double rating) {
    if (rating.isNaN) return;
    final clamped = rating.clamp(0.0, 5.0);
    if (_minRating == clamped) return;
    _minRating = clamped;
    notifyListeners();
  }

  void setMinReviewCount(int count) {
    final clamped = count < 0 ? 0 : count;
    if (_minReviewCount == clamped) return;
    _minReviewCount = clamped;
    notifyListeners();
  }

  void setSortOption(SortOption option) {
    if (_sortOption == option) return;
    _sortOption = option;
    notifyListeners();
  }

  void toggleViewMode() {
    _isMapView = !_isMapView;
    notifyListeners();
  }

  void toggleFavoritesOnly() {
    _showFavoritesOnly = !_showFavoritesOnly;
    notifyListeners();
  }

  /// Toggles favorite status for [placeId] and persists immediately.
  Future<void> toggleFavorite(String placeId) async {
    final updated = Set<String>.from(_favoriteIds);
    if (updated.contains(placeId)) {
      updated.remove(placeId);
    } else {
      updated.add(placeId);
    }
    _favoriteIds = updated;
    notifyListeners();

    try {
      await _storageRepository.saveFavoriteIds(updated);
    } catch (_) {}
  }

  /// Adds a user review for [placeId], persists it to storage,
  /// and updates the weighted rating and review counts.
  Future<void> addUserReview(String placeId, PlaceReview review) async {
    final currentReviews = _userReviewsMap[placeId] ?? const [];
    final updatedList =
        List<PlaceReview>.unmodifiable([review, ...currentReviews]);
    final updatedMap = Map<String, List<PlaceReview>>.from(_userReviewsMap);
    updatedMap[placeId] = updatedList;
    _userReviewsMap = updatedMap;

    _recomputeAllPlaces();
    notifyListeners();

    try {
      await _storageRepository.addUserReview(placeId, review);
    } catch (_) {}
  }

  /// Updates and persists Google Places API key, then refreshes places.
  Future<void> setGoogleApiKey(String? apiKey) async {
    final trimmed = apiKey?.trim();
    _googleApiKey = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    notifyListeners();

    try {
      await _storageRepository.saveGoogleApiKey(trimmed ?? '');
    } catch (_) {}

    await loadPlaces();
  }

  void _recomputeAllPlaces() {
    _allPlaces = _rawPlaces.map((p) {
      final userRevs = _userReviewsMap[p.id] ?? const [];
      final dist = _placesRepository.calculateDistance(
        _centerLat,
        _centerLon,
        p.latitude,
        p.longitude,
      );
      return mergePlaceWithUserReviews(
        place: p,
        userReviews: userRevs,
        distanceMeters: dist,
      );
    }).toList();
  }
}
