import 'package:latlong2/latlong.dart';
import 'package:mekan_radari/models/location_preset.dart';
import 'package:mekan_radari/models/place_model.dart';
import 'package:mekan_radari/repositories/places_repository.dart';

class FakePlacesRepository implements PlacesRepository {
  List<Place> placesToReturn;
  List<LocationPreset> presetsToReturn;
  bool shouldThrow;
  double Function(double lat1, double lon1, double lat2, double lon2)?
      distanceCalculator;

  FakePlacesRepository({
    this.placesToReturn = const [],
    this.presetsToReturn = const [],
    this.shouldThrow = false,
    this.distanceCalculator,
  });

  @override
  Future<List<Place>> fetchNearbyPlaces({
    required double lat,
    required double lon,
    required double radiusMeters,
    String? googleApiKey,
    String? searchQuery,
  }) async {
    if (shouldThrow) throw Exception('Simulated FakePlacesRepository error');
    return placesToReturn;
  }

  @override
  Future<List<LocationPreset>> searchAddress(String query) async {
    if (shouldThrow) throw Exception('Simulated FakePlacesRepository error');
    return presetsToReturn;
  }

  @override
  double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    if (distanceCalculator != null) {
      return distanceCalculator!(lat1, lon1, lat2, lon2);
    }
    const Distance distance = Distance();
    return distance.as(
      LengthUnit.Meter,
      LatLng(lat1, lon1),
      LatLng(lat2, lon2),
    );
  }
}
