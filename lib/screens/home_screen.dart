import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../controllers/places_controller.dart';
import '../models/location_preset.dart';
import '../models/place_model.dart';
import '../theme/app_theme.dart';
import '../widgets/category_chips_bar.dart';
import '../widgets/empty_venues_view.dart';
import '../widgets/filter_and_sort_bar.dart';
import '../widgets/home_app_bar.dart';
import '../widgets/interactive_venue_map.dart';
import '../widgets/radius_slider_bar.dart';
import '../widgets/results_summary_strip.dart';
import '../widgets/search_view_toggle_bar.dart';
import '../widgets/venue_card.dart';
import 'place_detail_sheet.dart';

/// Consumer-grade coordinator screen with a dedicated welcoming Home Screen,
/// clear search & discovery options, full-screen venue list, interactive map,
/// and bottom navigation bar.
class HomeScreen extends StatefulWidget {
  final PlacesController? controller;

  const HomeScreen({super.key, this.controller});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final PlacesController _controller;
  bool _isInternalController = false;
  int _selectedTabIndex = 0; // 0: Ana Sayfa, 1: Mekanlar, 2: Harita, 3: Favoriler

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _controller.init();
    } else {
      _controller = PlacesController(
        initialLocationLabel: 'Konum Belirleniyor...',
      );
      _isInternalController = true;
      _initProductionLocationFlow();
    }
  }

  /// Production initialization flow:
  /// 1. Initializes storage without blindly searching Moda.
  /// 2. If permission is already granted, immediately acquires GPS & loads places for user's real location.
  /// 3. If permission not yet determined, displays friendly permission dialog after first frame.
  Future<void> _initProductionLocationFlow() async {
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        await _controller.init(autoLoadPlaces: true);
        return;
      }
    } catch (_) {}

    await _controller.init(autoLoadPlaces: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndHandleLocationPermission();
    });
  }

  Future<void> _checkAndHandleLocationPermission() async {
    if (!mounted) return;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _fallbackToDefaultLocation();
        return;
      }

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        // Permission was already granted by user in previous session or settings!
        await _acquireGpsAndLoadPlaces();
      } else if (permission == LocationPermission.denied) {
        // First install / not determined: present user friendly in-app permission dialog
        if (mounted) {
          _showLocationPermissionDialog();
        }
      } else {
        // Permanently denied: fallback to default without nagging
        _fallbackToDefaultLocation();
      }
    } catch (_) {
      _fallbackToDefaultLocation();
    }
  }

  Future<void> _acquireGpsAndLoadPlaces() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );

      if (!mounted) return;
      final province = LocationPreset.detectProvince(pos.latitude, pos.longitude);
      final label = 'Mevcut Konumum • $province';

      await _controller.setLocation(
        lat: pos.latitude,
        lon: pos.longitude,
        label: label,
      );
    } catch (_) {
      _fallbackToDefaultLocation();
    }
  }

  void _fallbackToDefaultLocation() {
    if (!mounted) return;
    if (_controller.allPlaces.isEmpty) {
      _controller.setLocation(
        lat: 40.9862,
        lon: 29.0264,
        label: 'Kadıköy - Moda & Çarşı',
      );
    }
  }

  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        backgroundColor: AppColors.surface,
        titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
        contentPadding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.location_on_rounded,
                color: AppColors.primaryDark,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Konumunuza İzin Verin',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'Mekan Radarı, çevrenizdeki en lezzetli pastane, börekçi, fırın ve tatlıcıları anında bulabilmek için cihazınızın konumuna ihtiyaç duyar.\n\nİzin verirseniz haritada otomatik olarak mevcut konumunuz işaretlenir.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13.5,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // User declined: do not mark location, use default so user can search or pick
              _fallbackToDefaultLocation();
            },
            child: const Text(
              'Şimdilik İzin Verme',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final req = await Geolocator.requestPermission();
                if (req == LocationPermission.whileInUse ||
                    req == LocationPermission.always) {
                  await _acquireGpsAndLoadPlaces();
                } else {
                  _fallbackToDefaultLocation();
                }
              } catch (_) {
                _fallbackToDefaultLocation();
              }
            },
            icon: const Icon(Icons.my_location_rounded, size: 18),
            label: const Text('Konumuma İzin Ver'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    if (_isInternalController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _openPlaceDetails(Place place) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PlaceDetailSheet(
        place: place,
        isFavorite: _controller.isFavorite(place.id),
        onToggleFavorite: () => _controller.toggleFavorite(place.id),
        onAddReview: (review) => _controller.addUserReview(place.id, review),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final places = _controller.filteredPlaces;
        final isMapView = _controller.isMapView;

        // Synchronize tab index with controller map toggle
        final effectiveTabIndex = isMapView ? 2 : (_selectedTabIndex == 2 ? 0 : _selectedTabIndex);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: HomeAppBar(controller: _controller),
          body: _buildCurrentView(effectiveTabIndex, places),
          bottomNavigationBar: NavigationBar(
            selectedIndex: effectiveTabIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedTabIndex = index;
                if (index == 2) {
                  if (!_controller.isMapView) {
                    _controller.toggleViewMode();
                  }
                } else {
                  if (_controller.isMapView) {
                    _controller.toggleViewMode();
                  }
                }
              });
            },
            backgroundColor: AppColors.surface,
            indicatorColor: AppColors.primaryLight,
            elevation: 3,
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded, color: AppColors.primaryDark),
                label: 'Ana Sayfa',
              ),
              NavigationDestination(
                icon: const Icon(Icons.storefront_outlined),
                selectedIcon: const Icon(Icons.storefront_rounded, color: AppColors.primaryDark),
                label: 'Mekanlar (${places.length})',
              ),
              const NavigationDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map_rounded, color: AppColors.primaryDark),
                label: 'Harita',
              ),
              NavigationDestination(
                icon: const Icon(Icons.favorite_border_rounded),
                selectedIcon: const Icon(Icons.favorite_rounded, color: AppColors.red),
                label: 'Favoriler (${_controller.favoriteIds.length})',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCurrentView(int tabIndex, List<Place> places) {
    if (_controller.isLoading && _controller.allPlaces.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 14),
            Text(
              _controller.statusMessage ?? 'Çevredeki gerçek mekanlar taranıyor...',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_controller.isMapView || tabIndex == 2) {
      return _buildMapView();
    }

    if (tabIndex == 1) {
      return _buildVenuesListView(places);
    }

    if (tabIndex == 3) {
      return _buildFavoritesView();
    }

    // Default: Ana Sayfa (Home Hub)
    return _buildHomeView(places);
  }

  /// Interactive Map View with an overlaid search & view toggle bar
  Widget _buildMapView() {
    return Stack(
      children: [
        Positioned.fill(
          child: InteractiveVenueMap(
            controller: _controller,
            onPlaceTap: _openPlaceDetails,
          ),
        ),
        Positioned(
          top: 10,
          left: 16,
          right: 16,
          child: SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppColors.cardShadow,
              ),
              child: SearchViewToggleBar(controller: _controller),
            ),
          ),
        ),
      ],
    );
  }

  /// Welcoming Home Screen containing search hub, category chips, radius panel,
  /// filters, action buttons ("Mekanları Listele" / "Haritada Gör"), and venue list.
  Widget _buildHomeView(List<Place> places) {
    return Column(
      children: [
        // Ana Sayfa Header Container with Welcome Hero & Controls
        Container(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            boxShadow: AppColors.cardShadow,
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Welcome Hero Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.radar_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Yakınındaki Lezzetleri Keşfet',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Pastane, börekçi, fırın ve tatlıcıları anında bul',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Search & View Toggle Bar
              SearchViewToggleBar(controller: _controller),
              const SizedBox(height: 6),

              // 3. Category Chips Bar
              CategoryChipsBar(controller: _controller),
              const SizedBox(height: 6),

              // 4. Distance Radius Bar (Fixed: 500m no longer overflows)
              RadiusSliderBar(controller: _controller),
              const SizedBox(height: 6),

              // 5. Filter & Sort Bar
              FilterAndSortBar(controller: _controller),
              const SizedBox(height: 6),

              // 6. Two Prominent Action Buttons: "Mekanları Listele" & "Haritada Gör"
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      key: const Key('explore_venues_button'),
                      onTap: () {
                        setState(() {
                          _selectedTabIndex = 1;
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.format_list_bulleted_rounded,
                              size: 16,
                              color: AppColors.primaryDark,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              places.isEmpty
                                  ? 'Mekanları Ara'
                                  : 'Mekanları Listele (${places.length})',
                              style: const TextStyle(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      key: const Key('explore_map_button'),
                      onTap: () {
                        if (!_controller.isMapView) {
                          _controller.toggleViewMode();
                        }
                        setState(() {
                          _selectedTabIndex = 2;
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.blueLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.blue.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.map_rounded,
                              size: 16,
                              color: AppColors.blue,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Haritada Gör',
                              style: TextStyle(
                                color: AppColors.blue,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 7. Results Strip
        ResultsSummaryStrip(controller: _controller),

        // 8. Venue Cards or Empty View inside Expanded (Instantly mounts and fits viewport!)
        Expanded(
          child: places.isEmpty
              ? EmptyVenuesView(controller: _controller)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                  itemCount: places.length,
                  itemBuilder: (context, index) {
                    final place = places[index];
                    return VenueCard(
                      place: place,
                      isFavorite: _controller.isFavorite(place.id),
                      onToggleFavorite: () => _controller.toggleFavorite(place.id),
                      onTap: () => _openPlaceDetails(place),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Dedicated Full Results View with clean top strip and zero clutter.
  Widget _buildVenuesListView(List<Place> places) {
    if (places.isEmpty) {
      return EmptyVenuesView(controller: _controller);
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${places.length} mekan bulundu',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedTabIndex = 0;
                  });
                },
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: const Text('Filtreleri Değiştir (Ana Sayfa)'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            itemCount: places.length,
            itemBuilder: (context, index) {
              final place = places[index];
              return VenueCard(
                place: place,
                isFavorite: _controller.isFavorite(place.id),
                onToggleFavorite: () => _controller.toggleFavorite(place.id),
                onTap: () => _openPlaceDetails(place),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Favorites View showing all user-saved venues.
  Widget _buildFavoritesView() {
    final favoritePlaces = _controller.allPlaces
        .where((p) => _controller.isFavorite(p.id))
        .toList();

    if (favoritePlaces.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppColors.redLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: AppColors.red,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Henüz Favori Mekanınız Yok',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Beğendiğiniz mekanların kalp ikonuna dokunarak favorilerinize ekleyebilirsiniz.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedTabIndex = 0;
                  });
                },
                icon: const Icon(Icons.explore_rounded, size: 18),
                label: const Text('Mekanları Keşfet'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      itemCount: favoritePlaces.length,
      itemBuilder: (context, index) {
        final place = favoritePlaces[index];
        return VenueCard(
          place: place,
          isFavorite: true,
          onToggleFavorite: () => _controller.toggleFavorite(place.id),
          onTap: () => _openPlaceDetails(place),
        );
      },
    );
  }
}
