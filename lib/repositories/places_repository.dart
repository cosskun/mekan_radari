import '../models/location_preset.dart';
import '../models/place_model.dart';

/// Repository interface for fetching venue data, geocoding addresses,
/// and computing spatial distance.
abstract class PlacesRepository {
  /// Fetches venues around [lat], [lon] within [radiusMeters].
  /// Uses Google Places API (New v1) if [googleApiKey] is provided,
  /// otherwise uses OpenStreetMap Overpass API (with 3-mirror failover and offline fallback).
  Future<List<Place>> fetchNearbyPlaces({
    required double lat,
    required double lon,
    required double radiusMeters,
    String? googleApiKey,
    String? searchQuery,
  });

  /// Searches addresses or neighborhoods via OpenStreetMap Nominatim API.
  Future<List<LocationPreset>> searchAddress(String query);

  /// Calculates geodesic distance in meters between two coordinates using Haversine.
  double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  );
}
