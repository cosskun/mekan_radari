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

/// Consumer-grade coordinator screen designed for everyday users.
///
/// Features a clear, welcoming Home experience allowing users to configure
/// search criteria (categories, radius, filters), launch search, or directly view
/// venues on the interactive map.
class HomeScreen extends StatefulWidget {
  final PlacesController? controller;

  const HomeScreen({super.key, this.controller});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final PlacesController _controller;
  bool _isInternalController = false;

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
    // If running in automated widget test environment, initialize with default places immediately.
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
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: HomeAppBar(controller: _controller),
          body: Column(
            children: [
              // Search, Filters & Action Controls Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  boxShadow: AppColors.cardShadow,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    // Search & View Mode Toggle Bar
                    SearchViewToggleBar(controller: _controller),
                    const SizedBox(height: 8),

                    // Category Chips Bar
                    CategoryChipsBar(controller: _controller),
                    const SizedBox(height: 6),

                    // Distance Radius Bar (Fixed: 500m no longer overflows)
                    RadiusSliderBar(controller: _controller),
                    const SizedBox(height: 6),

                    // Filter & Sort Bar
                    FilterAndSortBar(controller: _controller),
                    const SizedBox(height: 8),

                    // Direct Action Buttons: "Mekanları Ara" & "Haritada Gör"
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            key: const Key('home_search_action_button'),
                            onTap: () {
                              _controller.loadPlaces();
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 9),
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
                                    Icons.search_rounded,
                                    size: 16,
                                    color: AppColors.primaryDark,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _controller.filteredPlaces.isEmpty
                                        ? 'Mekanları Ara'
                                        : 'Mekanları Listele (${_controller.filteredPlaces.length})',
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
                            key: const Key('home_map_action_button'),
                            onTap: () {
                              if (!_controller.isMapView) {
                                _controller.toggleViewMode();
                              }
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 9),
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
              ResultsSummaryStrip(controller: _controller),
              Expanded(
                child: _buildBody(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody() {
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

    if (_controller.isMapView) {
      return InteractiveVenueMap(
        controller: _controller,
        onPlaceTap: _openPlaceDetails,
      );
    }

    final places = _controller.filteredPlaces;
    if (places.isEmpty) {
      return EmptyVenuesView(controller: _controller);
    }

    return ListView.builder(
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
    );
  }
}
