import '../models/location_preset.dart';
import '../models/place_model.dart';
import '../repositories/places_repository.dart';
import '../repositories/places_repository_impl.dart';

export '../models/location_preset.dart';

class RealPlacesService {
  static final PlacesRepository _repo = PlacesRepositoryImpl();

  /// Calculates exact distance in meters between two coordinates using Haversine formula
  static double calculateDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return _repo.calculateDistance(lat1, lon1, lat2, lon2);
  }

  /// Search any address, neighborhood, or city via OpenStreetMap Nominatim API
  static Future<List<LocationPreset>> searchAddress(String query) async {
    return _repo.searchAddress(query);
  }

  /// Fetches real places around [lat], [lon].
  /// Uses official Google Places API (New) if [googleApiKey] is provided,
  /// otherwise uses live OpenStreetMap Overpass API for real-world venues.
  static Future<List<Place>> fetchNearbyPlaces({
    required double lat,
    required double lon,
    required double radiusMeters,
    String? googleApiKey,
    String? searchQuery,
  }) async {
    return _repo.fetchNearbyPlaces(
      lat: lat,
      lon: lon,
      radiusMeters: radiusMeters,
      googleApiKey: googleApiKey,
      searchQuery: searchQuery,
    );
  }
}
