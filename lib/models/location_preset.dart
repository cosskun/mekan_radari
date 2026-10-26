class LocationPreset {
  final String name;
  final String subtitle;
  final double latitude;
  final double longitude;

  const LocationPreset({
    required this.name,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'subtitle': subtitle,
        'latitude': latitude,
        'longitude': longitude,
      };

  factory LocationPreset.fromJson(Map<String, dynamic> json) => LocationPreset(
        name: json['name']?.toString() ?? '',
        subtitle: json['subtitle']?.toString() ?? '',
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      );

  LocationPreset copyWith({
    String? name,
    String? subtitle,
    double? latitude,
    double? longitude,
  }) =>
      LocationPreset(
        name: name ?? this.name,
        subtitle: subtitle ?? this.subtitle,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationPreset &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          subtitle == other.subtitle &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => Object.hash(name, subtitle, latitude, longitude);

  @override
  String toString() =>
      'LocationPreset(name: $name, subtitle: $subtitle, lat: $latitude, lon: $longitude)';

  static const List<LocationPreset> popularLocations = [
    LocationPreset(
      name: 'Kadıköy - Moda & Çarşı',
      subtitle: 'İstanbul Anadolu Yakası',
      latitude: 40.9862,
      longitude: 29.0264,
    ),
    LocationPreset(
      name: 'Beşiktaş - Çarşı & Akaretler',
      subtitle: 'İstanbul Avrupa Yakası',
      latitude: 41.0430,
      longitude: 29.0053,
    ),
    LocationPreset(
      name: 'Karaköy & Galata',
      subtitle: 'Beyoğlu, İstanbul',
      latitude: 41.0245,
      longitude: 28.9768,
    ),
    LocationPreset(
      name: 'Bağdat Caddesi - Suadiye',
      subtitle: 'Kadıköy, İstanbul',
      latitude: 40.9602,
      longitude: 29.0765,
    ),
    LocationPreset(
      name: 'Kızılay & Tunalı Hilmi',
      subtitle: 'Çankaya, Ankara',
      latitude: 39.9082,
      longitude: 32.8597,
    ),
    LocationPreset(
      name: 'Alsancak - Kıbrıs Şehitleri',
      subtitle: 'Konak, İzmir',
      latitude: 38.4361,
      longitude: 27.1418,
    ),
  ];
}
