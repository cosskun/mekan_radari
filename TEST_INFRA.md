# Mekan Radarı — E2E Test Infrastructure & Methodology (`TEST_INFRA.md`)

## 1. Executive Summary & Test Philosophy

The **Mekan Radarı** testing architecture employs an **opaque-box, requirement-driven, 4-tier methodology**. The goal is to verify that the refactored 3-tier architecture (Data Layer, State Controller Layer, Presentation Layer) operates with complete functional integrity, mathematical correctness, and persistence reliability across all user-facing features.

### Core Testing Tenets:
1. **Opaque-Box Requirement Verification**: Tests interact with application contracts solely through public interfaces, user inputs, gestures, and observable outputs (filtered venue lists, updated ratings, persisted storage entries, and UI elements). No test relies on private state or implementation details.
2. **Deterministic & Isolated Execution**: External network dependencies (Overpass API, Google Places API, OSM Nominatim) and platform GPS sensors are abstracted via deterministic test doubles (`FakePlacesRepository`, `FakeStorageRepository`) and in-memory `SharedPreferences.setMockInitialValues()`. Every test is self-contained, initializes its own isolated state, and cleans up deterministically.
3. **Progressive & Multi-Tiered Verification**:
   - **Tier 1 (Feature Coverage)**: Isolated happy-path verification of all primary features.
   - **Tier 2 (Boundary Value Analysis)**: Rigorous validation of edge conditions, clamping limits (50m, 3000m, 0.0–5.0 ratings), empty states, and numerical zero points.
   - **Tier 3 (Cross-Feature Combinations)**: Combinatorial and pairwise matrix testing (category + search + radius + rating + review count + favorites + sorting).
   - **Tier 4 (Real-World Workloads & User Journeys)**: Multi-step realistic user journeys representing complete user sessions (tourists, coffee hunters, review contributors).
4. **Authoritative Expected Output Derivation**: Expected outputs for calculations (weighted average ratings, Haversine geodesic distances, walking duration estimates, Turkish case-folding) are derived directly from mathematical specifications defined in `PROJECT.md` and `ORIGINAL_REQUEST.md`.

---

## 2. Feature Inventory Mapping (All 16 Features)

| Feature # | Feature Name | Mapped Scope | Test Tier | Verifiable Expected Behavior |
|:---:|---|---|:---:|---|
| **1** | Repository Abstraction (Places) | Data Layer | Tier 1, 2, 4 | `PlacesRepository` abstraction decouples networking, accepts query/coordinates, supports failover. |
| **2** | Repository Abstraction (Storage) | Data Layer | Tier 1, 2, 4 | `StorageRepository` manages favorites, reviews, and API key via typed interfaces. |
| **3** | Model Extraction (`LocationPreset`) | Models | Tier 1, 4 | Immutable `LocationPreset` with preset locations (Kadıköy, Beşiktaş, Karaköy, etc.) and Nominatim mapping. |
| **4** | Data Layer Unit Tests | Data Layer | Tier 1 | Repository contracts validated with deterministic mock responses. |
| **5** | State & Business Logic Controller | State Layer | Tier 1–4 | `PlacesController` orchestrates state, reactive updates via `notifyListeners()`. |
| **6** | Controller Unit Tests | State Layer | Tier 1, 3 | Pure unit verification of filter, sort, rating, and radius business logic. |
| **7** | Presentation Decomposition | Presentation | Tier 1, 4 | UI modularized into single-responsibility components coordinating seamlessly. |
| **8** | UI Widget Smoke & Component Tests | Presentation | Tier 1, 4 | Component-level rendering, interaction handling, and state reflection. |
| **9** | 50m–3km Radius Slider & Presets | Presentation & State | Tier 1, 2, 3 | Radius slider clamped within [50m, 3000m], preset quick buttons (50m, 100m, 250m, 500m, 1km, 2.5km). |
| **10** | Interactive OSM Map & Radar Circle | Presentation | Tier 1, 4 | Map view toggle, radar radius circle calculation, marker placement, coordinate relocation. |
| **11** | Venue Detail & Review Submission | Presentation & State | Tier 1, 3, 4 | `PlaceDetailSheet` display, star breakdown, directions URL, "Yorum Yaz" submission & weighted rating recalculation. |
| **12** | Adaptive Radius Recommendation | Presentation & State | Tier 1, 2, 4 | When filtered list is empty, detects nearest venue outside radius and recommends expansion to `(dist + 50m).clamp(100, 3000)`. |
| **13** | Local Persistence Integrity | Data & State | Tier 1, 2, 4 | Strict adherence to SharedPreferences keys: `favorite_place_ids_v1`, `user_place_reviews_v1`, `google_places_api_key_v1`. |
| **14** | E2E Testing Suite (Tiers 1–4) | Whole System | Tier 1–4 | 4-tier opaque-box test suite executing under `flutter test test/e2e/`. |
| **15** | Adversarial Coverage Hardening | Whole System | Tier 2, 3 | Fault injection, invalid data types, Turkish unicode edge cases, extreme bounds. |
| **16** | Zero Static Analysis Issues | Whole Project | Verification | Clean `flutter analyze` exit code 0 with 0 errors and 0 warnings. |

---

## 3. Test Architecture & Directory Layout

The E2E test suite resides exclusively under `test/e2e/`:

```
test/
├── e2e/
│   ├── tier1_feature_coverage_test.dart  # All 16 features verified in happy-path isolation
│   ├── tier2_boundary_test.dart          # Boundary values, numerical limits, empty edge cases
│   ├── tier3_cross_feature_test.dart     # Combinatorial pairwise interactions across features
│   └── tier4_real_world_test.dart        # End-to-end multi-step user personas and workflows
├── fakes/
│   ├── fake_places_repository.dart       # Controllable fake for location, places, distances
│   └── fake_storage_repository.dart      # Controllable in-memory storage for favorites/reviews
├── controllers/                          # Unit and controller state tests
├── data/                                 # Repository unit and adversarial tests
└── models/                               # Model serialization and calculation tests
```

### Test Harness & Runner Commands:
- **Execute All E2E Suites**:
  ```bash
  flutter test test/e2e/
  ```
- **Execute Specific Tier**:
  ```bash
  flutter test test/e2e/tier1_feature_coverage_test.dart
  flutter test test/e2e/tier2_boundary_test.dart
  flutter test test/e2e/tier3_cross_feature_test.dart
  flutter test test/e2e/tier4_real_world_test.dart
  ```
- **Static Analysis**:
  ```bash
  flutter analyze
  ```

---

## 4. 4-Tier Test Suite Specification

### Tier 1: Feature Coverage (Requirement-Driven, Isolated Happy Path)
- **Scope**: Direct validation of each feature in isolation using canonical inputs and expected outputs.
- **Key Test Areas**:
  1. Default initialization state (Kadıköy Moda center, 500m radius, 4.5+ rating, dessert category, distance sorting).
  2. Location switching to standard presets (Beşiktaş, Karaköy, Ankara Kızılay, İzmir Alsancak).
  3. Radius adjustment within standard bounds (50m, 100m, 250m, 500m, 1000m, 2500m).
  4. Category filtering (All, Dessert, Coffee, Restaurant, Fast Food, Bakery).
  5. Search query filtering with Turkish case-folding ('I' -> 'ı', 'İ' -> 'i').
  6. Rating filter threshold (e.g., 4.5, 4.7).
  7. Review count threshold filter.
  8. Sorting algorithms (distance ascending, rating descending with review count tie-breaker, review count descending).
  9. Favorite toggling and persistence verification.
  10. User review submission with instantaneous weighted average rating recalculation.
  11. View mode toggle (List View <-> Map View).
  12. Adaptive radius recommendation generation when in-radius results are empty.
  13. Google Places API Key storage and retrieval.
  14. Geodesic distance calculation and formatted walking time output.
  15. Google Directions and Search URL generation.
  16. `PlaceDetailSheet` widget display and review addition integration.

### Tier 2: Boundary Value Analysis (Extremes, Clamping, Zero States)
- **Scope**: Boundary Value Analysis (BVA) on all numerical and state constraints.
- **Key Test Areas**:
  1. **Radius Boundaries**: Exact 50m minimum, exact 3000m maximum, clamping of sub-50m (e.g. -10m, 0m -> 50m) and excessive radius (e.g. 5000m, 10000m -> 3000m), NaN handling.
  2. **Rating Boundaries**: Exact 0.0 minimum, 5.0 maximum, clamping of negative ratings (-1.0 -> 0.0) and excessive ratings (6.5 -> 5.0), NaN handling.
  3. **Review Count Boundaries**: 0 reviews boundary (venues with 0 reviews included when minReviewCount = 0), negative review count clamped to 0.
  4. **Geographic Coordinates**: Equator (lat 0, lon 0), North/South extremes (+89.9, -89.9), Date line crossing (lon 180, -180).
  5. **Empty Results Handling**: Empty place list, no matches for search query, empty favorites set.
  6. **Weighted Rating Numerical Extremes**:
     - Venue with 1 existing review (rating 5.0) receiving a 1.0 star user review -> `(5.0*1 + 1.0)/2 = 3.0`.
     - Venue with 10,000 existing reviews receiving 1 review -> infinitesimal shift correctly formatted to 1 decimal place.
     - New venue with 0 existing reviews receiving first review.
  7. **Adaptive Radius Clamping**: Closest venue at 40m distance -> expanded radius `(40 + 50) = 90m` clamped to minimum 100m. Closest venue at 3500m -> clamped to maximum 3000m.

### Tier 3: Cross-Feature Interactions (Pairwise & Multi-Criteria Matrix)
- **Scope**: Validating that independent feature filters do not regress or interfere with each other when applied simultaneously.
- **Key Combinatorial Matrices**:
  1. `[Category: Coffee] + [Radius: 250m] + [MinRating: 4.8] + [Search: "Espresso"] + [Sort: Distance]`
  2. `[Favorites Only: True] + [Category: Dessert] + [Radius: 500m] + [Sort: Rating]`
  3. `[Category: Restaurant] + [Search: "Kebap"] + [MinReviewCount: 50] + [Sort: Reviews]`
  4. `[Search: Turkish "Şekerci"] + [Radius: 1000m] + [Review Added] + [Recalculated Filter]`
  5. `[Location Relocated to Beşiktaş] + [Category: Bakery] + [MinRating: 4.0] + [Favorites Filter Active]`
  6. `[Empty Category Filter] + [Adaptive Radius Recommended] + [Radius Auto-Expanded] + [Venue Appears in Filtered List]`
  7. `[Multiple User Reviews on Single Venue] + [Weighted Rating Clamped to 5.0] + [Sorting Order Shifted]`

### Tier 4: Real-World Workloads & End-to-End User Journeys
- **Scope**: Simulation of end-to-end user workflows across multiple screens and operations.
- **Key User Scenarios**:
  - **Journey 1: "The Kadıköy Dessert Connoisseur"**:
    1. User starts at Kadıköy Moda hub with default 500m radius and dessert category.
    2. Searches for "Baklava" in Turkish lowercase/uppercase.
    3. Finds top-rated Baklava venue, opens `PlaceDetailSheet`.
    4. Toggles favorite heart (verified in storage).
    5. Submits a 5-star review ("Harika çıtır fıstıklı baklava!").
    6. Verifies that venue rating updates, review count increments, and venue ranks #1 when sorted by rating.
  - **Journey 2: "The Beşiktaş Remote Worker Coffee Hunt"**:
    1. User selects Beşiktaş location preset from LocationPicker.
    2. Changes category to "Kahve & Kafe" and sets radius to 250m.
    3. Filters for high review count (min 50 reviews) to find established cafes with fast Wi-Fi.
    4. Switches view to Map View, then toggles back to List View.
    5. Verifies distance sorting places the closest coffee roastery at the top.
  - **Journey 3: "The Late-Night Street Food Search (Adaptive Radius Expansion)"**:
    1. User sets category to "Burger & Sokak Lezzeti" with a tight 50m radius.
    2. No venues found within 50m (`filteredPlaces.isEmpty`).
    3. System identifies closest burger joint outside radius at 220m.
    4. User triggers `expandRadiusToClosestPlace()`.
    5. Radius expands automatically to 270m (`220m + 50m`).
    6. Filtered list now includes the venue immediately.
  - **Journey 4: "The Tourist Custom Search & Google Maps Integration"**:
    1. User enters custom address search ("Karaköy İskelesi") and relocates center.
    2. Enters Google Places API Key in settings dialog (persisted).
    3. Inspects directions link and Google Maps search URI.
    4. Toggles favorites-only view to review saved gems across the trip.

---

## 5. Coverage & Quality Thresholds

| Metric | Target | Enforced In |
|---|:---:|:---:|
| **E2E Test Pass Rate** | **100% (0 failures)** | `flutter test test/e2e/` |
| **Static Analysis Errors** | **0 errors** | `flutter analyze` |
| **Static Analysis Warnings** | **0 warnings** | `flutter analyze` |
| **Feature Coverage** | **16 / 16 Features (100%)** | `TEST_READY.md` Matrix |
| **Execution Speed** | **< 15 seconds** | Headless automated runner |
| **Network Independence** | **100% Deterministic (No live HTTP)** | Mock & Fake Injectables |
