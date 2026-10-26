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

/// Slim coordinator screen (~125 lines) subscribing to [PlacesController]
/// via [ListenableBuilder] and assembling decomposed modular sub-widgets.
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
              // Search, Filters & Controls Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  boxShadow: AppColors.cardShadow,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(22),
                  ),
                ),
                child: Column(
                  children: [
                    SearchViewToggleBar(controller: _controller),
                    const SizedBox(height: 8),
                    CategoryChipsBar(controller: _controller),
                    const SizedBox(height: 6),
                    RadiusSliderBar(controller: _controller),
                    const SizedBox(height: 6),
                    FilterAndSortBar(controller: _controller),
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
              _controller.statusMessage ?? 'Gerçek mekanlar yükleniyor...',
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
