import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../controllers/places_controller.dart';
import '../models/place_model.dart';

/// Interactive OpenStreetMap view displaying the user's radar circle and
/// custom star-rating pill markers for all venues matching active filters.
class InteractiveVenueMap extends StatefulWidget {
  final PlacesController controller;
  final MapController? mapController;
  final ValueChanged<Place>? onPlaceTap;
  final ValueChanged<LatLng>? onMapLongPress;
  final String tileUrlTemplate;

  const InteractiveVenueMap({
    super.key,
    required this.controller,
    this.mapController,
    this.onPlaceTap,
    this.onMapLongPress,
    this.tileUrlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  });

  /// Calculates the recommended OpenStreetMap zoom level for a given radar radius in meters.
  static double zoomForRadius(double radiusMeters) {
    if (radiusMeters <= 60) return 18.0;
    if (radiusMeters <= 150) return 17.2;
    if (radiusMeters <= 350) return 16.3;
    if (radiusMeters <= 700) return 15.4;
    if (radiusMeters <= 1500) return 14.4;
    return 13.3;
  }

  @override
  State<InteractiveVenueMap> createState() => _InteractiveVenueMapState();
}

class _InteractiveVenueMapState extends State<InteractiveVenueMap> {
  late final MapController _mapController;
  bool _isInternalMapController = false;

  double _lastLat = 0.0;
  double _lastLon = 0.0;
  double _lastRadius = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.mapController != null) {
      _mapController = widget.mapController!;
    } else {
      _mapController = MapController();
      _isInternalMapController = true;
    }
    _lastLat = widget.controller.centerLat;
    _lastLon = widget.controller.centerLon;
    _lastRadius = widget.controller.radiusMeters;
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    if (_isInternalMapController) {
      _mapController.dispose();
    }
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    if (_lastLat != widget.controller.centerLat ||
        _lastLon != widget.controller.centerLon ||
        _lastRadius != widget.controller.radiusMeters) {
      _lastLat = widget.controller.centerLat;
      _lastLon = widget.controller.centerLon;
      _lastRadius = widget.controller.radiusMeters;
      try {
        _mapController.move(
          LatLng(_lastLat, _lastLon),
          InteractiveVenueMap.zoomForRadius(_lastRadius),
        );
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final center = LatLng(
          widget.controller.centerLat,
          widget.controller.centerLon,
        );
        final radius = widget.controller.radiusMeters;
        final places = widget.controller.filteredPlaces;

        return Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: InteractiveVenueMap.zoomForRadius(radius),
                onLongPress: (tapPosition, latlng) {
                  if (widget.onMapLongPress != null) {
                    widget.onMapLongPress!(latlng);
                  } else {
                    widget.controller.setLocation(
                      lat: latlng.latitude,
                      lon: latlng.longitude,
                      label:
                          'Haritadan Seçilen Nokta (${latlng.latitude.toStringAsFixed(4)}, ${latlng.longitude.toStringAsFixed(4)})',
                    );
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: widget.tileUrlTemplate,
                  userAgentPackageName: 'com.mekanradari.mekan_radari',
                ),
                // Radar Search Radius Circle in Meters
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: center,
                      radius: radius,
                      useRadiusInMeter: true,
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.18),
                      borderColor: const Color(0xFF38BDF8),
                      borderStrokeWidth: 2.5,
                    ),
                  ],
                ),
                // Marker Layer: User Center + Found Venues
                MarkerLayer(
                  markers: [
                    // User Radar Center Pin
                    Marker(
                      point: center,
                      width: 46,
                      height: 46,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(color: Colors.black45, blurRadius: 8),
                          ],
                        ),
                        child: const Icon(
                          Icons.person_pin_circle_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                    // Venue Markers with Star Rating Pills
                    ...places.map((place) {
                      return Marker(
                        point: LatLng(place.latitude, place.longitude),
                        width: 110,
                        height: 52,
                        child: GestureDetector(
                          onTap: () => widget.onPlaceTap?.call(place),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFFBBF24),
                                    width: 1.5,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black54,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      color: Color(0xFFFBBF24),
                                      size: 13,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      place.rating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        place.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.location_on_rounded,
                                color: Color(0xFFF59E0B),
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
            // Floating Helper Tip at Bottom
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.touch_app_rounded,
                      color: Color(0xFFFBBF24),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'İpucu: Haritada istediğiniz sokağa basılı tutarak o noktadaki 50m-500m yarıçaplı mekanları tarayabilirsiniz.',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
