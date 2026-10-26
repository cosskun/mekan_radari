# Project: mekan_radari Clean Architecture Refactoring

## Architecture
The application is refactored from a monolithic screen with static services into a clean, testable 3-tier architecture:
1. **Data Layer (`lib/repositories/`, `lib/models/`)**:
   - `PlacesRepository` (interface) and `PlacesRepositoryImpl`: Handles Overpass OSM API (3 mirrors with failover), Google Places API v1, OSM Nominatim address search, and Haversine distance calculations. Uses an injectable `http.Client`.
   - `StorageRepository` (interface) and `StorageRepositoryImpl`: Manages SharedPreferences persistence for favorites (`favorite_place_ids_v1`), user reviews (`user_place_reviews_v1`), and Google API Key (`google_places_api_key_v1`). Uses injectable `SharedPreferences`.
   - Models: Immutable `Place`, `PlaceReview`, `PlaceCategoryFilter`, and extracted `LocationPreset`.
2. **State / Controller Layer (`lib/controllers/`)**:
   - `PlacesController` (`ChangeNotifier`): Encapsulates UI state (center coordinates, radius, search query, selected category, min rating, min review count, sort option, view mode, places list, filtered places, closest place outside radius, favorite IDs, user reviews map, loading state, error messages).
   - Contains pure business logic: weighted average rating recalculation, multi-criteria filtering pipeline, sorting pipeline, and radius expansion math.
   - Fully testable in headless unit tests with manual fakes or mock doubles.
3. **Presentation Layer (`lib/screens/`, `lib/widgets/`)**:
   - `HomeScreen`: Lightweight coordinator scaffold (~120 lines) subscribing to `PlacesController` via `ListenableBuilder` or constructor callbacks.
   - Modular sub-widgets in `lib/widgets/`:
     - `HomeAppBar`: Location picker button, GPS trigger, favorites filter toggle, API settings.
     - `LocationPickerSheet`: Live Nominatim address search and popular location presets.
     - `ApiSettingsDialog`: Google Places API Key configuration.
     - `SearchViewToggleBar`: Search TextField and Map/List toggle button.
     - `CategoryChipsBar`: Horizontal category filters.
     - `RadiusSliderBar`: Distance slider (50m - 3000m) with 50m, 100m, 250m, 500m, 1km, 2.5km quick buttons.
     - `FilterAndSortBar`: Minimum rating chips, review count popup, sort popup.
     - `ResultsSummaryStrip`: Place count, active filters summary, refresh action.
     - `InteractiveVenueMap`: FlutterMap, OpenStreetMap tiles, radar circle, custom venue pill markers, map gestures.
     - `VenueCard`: Card with walking distance & time, favorite heart button, menu tags, review quote.
     - `EmptyVenuesView`: Radar empty state with adaptive radius suggestion button.
     - `PlaceDetailSheet`: Existing detailed venue sheet with star breakdown and "Yorum Yaz" dialog.

---

## Feature Inventory
Every feature from the Survey phase and `ORIGINAL_REQUEST.md` is mapped below to an assigned milestone:

| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Repository Abstraction (Places) | Abstract Overpass, Google Places, Nominatim, and Distance behind `PlacesRepository` with injectable `http.Client` | M1: Data Layer | ORIGINAL_REQUEST R1, Survey |
| 2 | Repository Abstraction (Storage) | Abstract SharedPreferences (favorites, reviews, API key) behind `StorageRepository` with injectable `SharedPreferences` | M1: Data Layer | ORIGINAL_REQUEST R1, Survey |
| 3 | Model Extraction (`LocationPreset`) | Extract `LocationPreset` from `real_places_service.dart` into `lib/models/location_preset.dart` | M1: Data Layer | Survey |
| 4 | Data Layer Unit Tests | Comprehensive tests for `PlacesRepositoryImpl` (via `MockClient`) and `StorageRepositoryImpl` (via `setMockInitialValues`) | M1: Data Layer | ORIGINAL_REQUEST AC, Survey |
| 5 | State & Business Logic Controller | `PlacesController extends ChangeNotifier` managing search, filters, sorting, coordinates, review merging, and rating calculations | M2: State Layer | ORIGINAL_REQUEST R1, Survey |
| 6 | Controller Unit Tests | Pure unit tests for `PlacesController` state transitions, filter combinations, sorting orders, and review calculations | M2: State Layer | ORIGINAL_REQUEST AC, Survey |
| 7 | Presentation Decomposition | Modularize `home_screen.dart` (1857 lines) into 10+ focused widgets in `lib/widgets/` and slim `home_screen.dart` (~120 lines) | M3: Presentation Layer | ORIGINAL_REQUEST R1, Survey |
| 8 | UI Widget Smoke & Component Tests | Widget tests for decomposed UI widgets (`CategoryChipsBar`, `RadiusSliderBar`, `VenueCard`, etc.) | M3: Presentation Layer | ORIGINAL_REQUEST AC, Survey |
| 9 | 50m–3km Radius Slider & Presets | Interactive radius slider with quick buttons (50m, 100m, 250m, 500m, 1km, 2.5km) and auto-fetch beyond 1200m | M3: Presentation Layer | ORIGINAL_REQUEST R2, Survey |
| 10 | Interactive OSM Map & Radar Circle | FlutterMap with OpenStreetMap tiles, radar radius circle, venue pill markers, and long-press relocation | M3: Presentation Layer | ORIGINAL_REQUEST R2, Survey |
| 11 | Venue Detail & Review Submission | Venue detail sheet with Google-style star breakdown, directions deep links, and "Yorum Yaz" modal dialog | M3: Presentation Layer | ORIGINAL_REQUEST R2, Survey |
| 12 | Adaptive Radius Recommendation | Empty state recommendation finding closest matching venue outside radius with one-tap expansion | M3: Presentation Layer | ORIGINAL_REQUEST R2, Survey |
| 13 | Local Persistence Integrity | Ensure exact SharedPreferences keys (`favorite_place_ids_v1`, `user_place_reviews_v1`, `google_places_api_key_v1`) are preserved | M1: Data Layer | ORIGINAL_REQUEST R2, Survey |
| 14 | E2E Testing Suite (Tiers 1–4) | Requirement-driven opaque-box test suite covering feature coverage, boundary values, pairwise interactions, and user journeys | M4: E2E Testing Track | Dual Track, AC |
| 15 | Adversarial Coverage Hardening (Tier 5) | White-box adversarial testing and code coverage hardening | M5: Final Verification | Dual Track, AC |
| 16 | Zero Static Analysis Issues | `flutter analyze` exits with code 0 (0 errors, 0 warnings under flutter_lints ^6.0.0) | M5: Final Verification | ORIGINAL_REQUEST AC |

---

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Data Layer Abstraction | Extract `LocationPreset` model, define `PlacesRepository` and `StorageRepository` interfaces, implement `PlacesRepositoryImpl` and `StorageRepositoryImpl`, create test doubles and unit tests (122 tests passing) | none | DONE |
| M2 | State & Controller Layer | Implement `PlacesController` (`ChangeNotifier`) with search, filter, sort, favorite, review calculation logic, Turkish case folding, deep immutability, and boundary clamping; comprehensive test suites (258 total project tests passing, analyze 0 issues) | M1 | DONE |
| M3 | Presentation Layer Modularization | Decompose `home_screen.dart` into single-responsibility sub-widgets in `lib/widgets/`, connect to `PlacesController`, write widget tests | M2 | IN_PROGRESS |
| M4 | E2E Testing Track | Develop comprehensive 4-tier E2E opaque-box test suite (`TEST_INFRA.md`), publish `TEST_READY.md` | none (Parallel) | PLANNED |
| M5 | Final Milestone: E2E Test Pass & Hardening | Pass 100% of E2E tests (Tiers 1-4), perform Tier 5 adversarial hardening, verify `flutter analyze` 0 warnings/errors, and complete forensic audit | M3, M4 | PLANNED |

---

## Interface Contracts

### 1. `PlacesRepository` (`lib/repositories/places_repository.dart`)
```dart
abstract class PlacesRepository {
  Future<List<Place>> fetchNearbyPlaces({
    required double lat,
    required double lon,
    required double radiusMeters,
    String? googleApiKey,
    String? searchQuery,
  });

  Future<List<LocationPreset>> searchAddress(String query);

  double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  );
}
```

### 2. `StorageRepository` (`lib/repositories/storage_repository.dart`)
```dart
abstract class StorageRepository {
  Future<Set<String>> loadFavoriteIds();
  Future<void> saveFavoriteIds(Set<String> ids);
  Future<void> toggleFavorite(String placeId);
  Future<bool> isFavorite(String placeId);

  Future<Map<String, List<PlaceReview>>> loadUserReviews();
  Future<List<PlaceReview>> getReviewsForPlace(String placeId);
  Future<void> addUserReview(String placeId, PlaceReview review);

  Future<String?> loadGoogleApiKey();
  Future<void> saveGoogleApiKey(String apiKey);
}
```

### 3. `PlacesController` (`lib/controllers/places_controller.dart`)
```dart
enum SortOption { distance, rating, reviews }

class PlacesController extends ChangeNotifier {
  // State getters
  double get centerLat;
  double get centerLon;
  String get locationLabel;
  String get searchQuery;
  String get selectedCategoryId;
  double get radiusMeters;
  double get minRating;
  int get minReviewCount;
  SortOption get sortOption;
  bool get isMapView;
  bool get showFavoritesOnly;
  bool get isLoading;
  String? get statusMessage;
  List<Place> get allPlaces;
  List<Place> get filteredPlaces;
  Place? get closestPlaceOutsideRadius;
  Set<String> get favoriteIds;
  Map<String, List<PlaceReview>> get userReviewsMap;

  // Actions
  void setLocation({required double lat, required double lon, required String label});
  void setSearchQuery(String query);
  void setCategoryId(String categoryId);
  void setRadiusMeters(double radius);
  void setMinRating(double rating);
  void setMinReviewCount(int count);
  void setSortOption(SortOption option);
  void toggleViewMode();
  void toggleFavoritesOnly();
  Future<void> toggleFavorite(String placeId);
  Future<void> addUserReview(String placeId, PlaceReview review);
  Future<void> loadPlaces();
  Future<List<LocationPreset>> searchAddress(String query);
}
```

---

## Code Layout
Strictly confined to `C:\Users\Developer6\.gemini\Project\mekan_radari`:
```
lib/
├── main.dart
├── models/
│   ├── place_model.dart
│   └── location_preset.dart
├── repositories/
│   ├── places_repository.dart
│   ├── places_repository_impl.dart
│   ├── storage_repository.dart
│   └── storage_repository_impl.dart
├── controllers/
│   └── places_controller.dart
├── screens/
│   ├── home_screen.dart
│   └── place_detail_sheet.dart
└── widgets/
    ├── home_app_bar.dart
    ├── location_picker_sheet.dart
    ├── api_settings_dialog.dart
    ├── search_view_toggle_bar.dart
    ├── category_chips_bar.dart
    ├── radius_slider_bar.dart
    ├── filter_and_sort_bar.dart
    ├── results_summary_strip.dart
    ├── interactive_venue_map.dart
    ├── venue_card.dart
    └── empty_venues_view.dart

test/
├── models/
│   └── place_model_test.dart
├── data/
│   ├── places_repository_test.dart
│   └── storage_repository_test.dart
├── controllers/
│   └── places_controller_test.dart
├── widgets/
│   ├── category_chips_widget_test.dart
│   ├── radius_slider_widget_test.dart
│   ├── filter_and_sort_widget_test.dart
│   ├── venue_card_widget_test.dart
│   └── empty_venues_widget_test.dart
├── fakes/
│   ├── fake_places_repository.dart
│   └── fake_storage_repository.dart
├── e2e/
│   ├── tier1_feature_test.dart
│   ├── tier2_boundary_test.dart
│   ├── tier3_combinations_test.dart
│   └── tier4_workload_test.dart
└── widget_test.dart
```
