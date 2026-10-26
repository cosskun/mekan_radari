import 'package:flutter/material.dart';

import '../controllers/places_controller.dart';
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
    } else {
      _controller = PlacesController();
      _isInternalController = true;
    }
    _controller.init();
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
