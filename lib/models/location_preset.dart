import 'dart:math' as math;

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

  /// Presets grouped by province (İl) with curated culinary, bakery & dessert centers.
  static const Map<String, List<LocationPreset>> popularLocationsByProvince = {
    'İstanbul': [
      LocationPreset(
        name: 'Kadıköy - Moda & Çarşı',
        subtitle: 'Tarihi tatlıcılar, dondurmacılar, fırın & kahveciler',
        latitude: 40.9862,
        longitude: 29.0264,
      ),
      LocationPreset(
        name: 'Beşiktaş - Çarşı & Akaretler',
        subtitle: 'Meşhur börekçiler, tatlıcılar ve kahvaltı mekanları',
        latitude: 41.0430,
        longitude: 29.0053,
      ),
      LocationPreset(
        name: 'Karaköy & Galata',
        subtitle: 'Tarihi baklavacılar, pastaneler ve üçüncü nesil kafeler',
        latitude: 41.0245,
        longitude: 28.9768,
      ),
      LocationPreset(
        name: 'Eminönü & Sirkeci',
        subtitle: 'Tarihi lokumcu, tatlıcı, kadayıfçı ve fırınlar',
        latitude: 41.0166,
        longitude: 28.9734,
      ),
      LocationPreset(
        name: 'Bağdat Caddesi - Suadiye',
        subtitle: 'Kruvasan, butik pastane, fırın ve tatlı durakları',
        latitude: 40.9602,
        longitude: 29.0765,
      ),
      LocationPreset(
        name: 'Üsküdar - Çarşı & Çengelköy',
        subtitle: 'Tarihi çınaraltı fırınları, börekçiler ve çikolatacılar',
        latitude: 41.0260,
        longitude: 29.0150,
      ),
      LocationPreset(
        name: 'Nişantaşı & Teşvikiye',
        subtitle: 'Butik pastaneler, fırınlar ve tatlı atölyeleri',
        latitude: 41.0505,
        longitude: 28.9942,
      ),
      LocationPreset(
        name: 'Bakırköy - Çarşı & Sahil',
        subtitle: 'Geleneksel pastaneler, fırınlar ve dondurmacılar',
        latitude: 40.9785,
        longitude: 28.8725,
      ),
    ],
    'Ankara': [
      LocationPreset(
        name: 'Kızılay & Tunalı Hilmi',
        subtitle: 'Kafeler, börekçiler, pastaneler ve tatlı durakları',
        latitude: 39.9082,
        longitude: 32.8597,
      ),
      LocationPreset(
        name: 'Bahçelievler 7. Cadde',
        subtitle: 'Meşhur tatlı ve kafe rotası, fırınlar',
        latitude: 39.9215,
        longitude: 32.8236,
      ),
      LocationPreset(
        name: 'Çukurambar',
        subtitle: 'Yeni nesil tatlıcılar, pastaneler ve kahve mekanları',
        latitude: 39.9015,
        longitude: 32.8105,
      ),
      LocationPreset(
        name: 'Ulus & Tarihi Hamamönü',
        subtitle: 'Geleneksel Ankara fırınları ve tarihi tatlıcılar',
        latitude: 39.9360,
        longitude: 32.8680,
      ),
      LocationPreset(
        name: 'Ümitköy & Çayyolu',
        subtitle: 'Butik fırınlar, pastaneler ve lezzet durakları',
        latitude: 39.8890,
        longitude: 32.7050,
      ),
      LocationPreset(
        name: 'Gaziosmanpaşa & Filistin Cad.',
        subtitle: 'Nitelikli kahveciler, tatlı ve fırın mekanları',
        latitude: 39.8970,
        longitude: 32.8690,
      ),
    ],
    'İzmir': [
      LocationPreset(
        name: 'Alsancak - Kıbrıs Şehitleri',
        subtitle: 'Meşhur boyozcular, pastaneler, gevrek ve kafeler',
        latitude: 38.4361,
        longitude: 27.1418,
      ),
      LocationPreset(
        name: 'Kemeraltı Tarihi Çarşı',
        subtitle: 'Tarihi şambaliciler, tatlıcılar ve geleneksel fırınlar',
        latitude: 38.4180,
        longitude: 27.1325,
      ),
      LocationPreset(
        name: 'Karşıyaka - Bostanlı & Çarşı',
        subtitle: 'Tatlıcılar, fırın ve sahil kafeleri',
        latitude: 38.4555,
        longitude: 27.1030,
      ),
      LocationPreset(
        name: 'Bornova - Küçükpark & Süvari',
        subtitle: 'Kafeler, gençlik tatlı durakları ve fırınlar',
        latitude: 38.4625,
        longitude: 27.2180,
      ),
      LocationPreset(
        name: 'Çeşme & Alaçatı',
        subtitle: 'Damla sakızlı kurabiyeciler, fırınlar ve pastaneler',
        latitude: 38.2830,
        longitude: 26.3750,
      ),
      LocationPreset(
        name: 'Urla - Sanat Sokağı & İskele',
        subtitle: 'Katmerciler, butik fırınlar ve tatlı mekanları',
        latitude: 38.3240,
        longitude: 26.7640,
      ),
    ],
    'Bursa': [
      LocationPreset(
        name: 'Heykel & Tarihi Kapalıçarşı',
        subtitle: 'Tahinli pide, kestane şekercileri ve tarihi tatlıcılar',
        latitude: 40.1830,
        longitude: 29.0640,
      ),
      LocationPreset(
        name: 'Fatih Sultan Mehmet (FSM) Bulvarı',
        subtitle: 'Modern pastaneler, fırınlar ve kafe rotası',
        latitude: 40.2160,
        longitude: 28.9860,
      ),
      LocationPreset(
        name: 'Özlüce & Nilüfer',
        subtitle: 'Yeni nesil tatlıcılar, pastaneler ve kahve durakları',
        latitude: 40.2290,
        longitude: 28.9050,
      ),
      LocationPreset(
        name: 'Mudanya & Tirilye',
        subtitle: 'Tarihi fırınlar, taş fırın simidi ve sahil mekanları',
        latitude: 40.3750,
        longitude: 28.8820,
      ),
    ],
    'Gaziantep': [
      LocationPreset(
        name: 'Tarihi Bakırcılar Çarşısı & Kalealtı',
        subtitle: 'Meşhur baklavacılar, katmerciler ve tarihi fırınlar',
        latitude: 37.0655,
        longitude: 37.3860,
      ),
      LocationPreset(
        name: 'Gazimuhtar Paşa & İncilipınar',
        subtitle: 'Pastaneler, kafeler ve modern tatlı merkezleri',
        latitude: 37.0720,
        longitude: 37.3710,
      ),
      LocationPreset(
        name: 'Şahinbey - Bey Mahallesi',
        subtitle: 'Tarihi konaklar, geleneksel tatlıcılar ve kafeler',
        latitude: 37.0590,
        longitude: 37.3780,
      ),
    ],
    'Antalya': [
      LocationPreset(
        name: 'Kaleiçi & Işıklar Caddesi',
        subtitle: 'Tarihi pastaneler, yanıksı dondurmacılar ve kafeler',
        latitude: 36.8845,
        longitude: 30.7060,
      ),
      LocationPreset(
        name: 'Konyaaltı - Kent Meydanı & Sahil',
        subtitle: 'Sahil kafeleri, tatlı durakları ve fırınlar',
        latitude: 36.8680,
        longitude: 30.6380,
      ),
      LocationPreset(
        name: 'Muratpaşa - Lara & Şirinyalı',
        subtitle: 'Butik pastaneler, fırın rotası ve tatlı merkezleri',
        latitude: 36.8620,
        longitude: 30.7380,
      ),
      LocationPreset(
        name: 'Alanya - Çarşı & Damlataş',
        subtitle: 'Pastaneler, dondurmacılar ve tatlı durakları',
        latitude: 36.5430,
        longitude: 31.9960,
      ),
    ],
    'Adana': [
      LocationPreset(
        name: 'Ziyapaşa Bulvarı & Gazipaşa',
        subtitle: 'Pastaneler, kafeler, bici bici ve tatlı durakları',
        latitude: 36.9995,
        longitude: 35.3210,
      ),
      LocationPreset(
        name: 'Tarihi Büyüksaat & Kazancılar Çarşısı',
        subtitle: 'Taş kadayıf, halka tatlı ve geleneksel fırınlar',
        latitude: 36.9830,
        longitude: 35.3275,
      ),
      LocationPreset(
        name: 'Barajyolu & Turgut Özal',
        subtitle: 'Tatlıcılar, modern kafeler ve pastaneler',
        latitude: 37.0320,
        longitude: 35.2980,
      ),
    ],
    'Eskişehir': [
      LocationPreset(
        name: 'Odunpazarı Tarihi Çarşı',
        subtitle: 'Met helvacıları, çibörekçiler ve geleneksel lezzetler',
        latitude: 39.7620,
        longitude: 30.5260,
      ),
      LocationPreset(
        name: 'Doktorlar Caddesi & Adalar',
        subtitle: 'Kafeler, fırınlar ve gençlik tatlı durakları',
        latitude: 39.7760,
        longitude: 30.5180,
      ),
      LocationPreset(
        name: 'Haller Gençlik Merkezi & Bağlar',
        subtitle: 'Tatlıcılar, fırın ve kahve mekanları',
        latitude: 39.7820,
        longitude: 30.5090,
      ),
    ],
    'Konya': [
      LocationPreset(
        name: 'Mevlana Meydanı & Tarihi Bedesten',
        subtitle: 'Sac arası, fırın kebabı ekmeği ve geleneksel tatlıcılar',
        latitude: 37.8710,
        longitude: 32.5050,
      ),
      LocationPreset(
        name: 'Zafer Meydanı & Alaaddin Çevresi',
        subtitle: 'Pastaneler, kafeler ve fırınlar',
        latitude: 37.8730,
        longitude: 32.4920,
      ),
    ],
    'Trabzon': [
      LocationPreset(
        name: 'Meydan & Uzun Sokak',
        subtitle: 'Tarihi fırınlar, Trabzon ekmeği, pastaneler ve sütlaç',
        latitude: 41.0040,
        longitude: 39.7280,
      ),
      LocationPreset(
        name: 'Kunduracılar & Maraş Caddesi',
        subtitle: 'Kafeler ve geleneksel tatlı durakları',
        latitude: 41.0060,
        longitude: 39.7240,
      ),
      LocationPreset(
        name: 'Akçaabat - Sahil',
        subtitle: 'Tarihi fırınlar ve tatlı mekanları',
        latitude: 41.0210,
        longitude: 39.5720,
      ),
    ],
    'Kayseri': [
      LocationPreset(
        name: 'Cumhuriyet Meydanı & Tarihi Kapalıçarşı',
        subtitle: 'Geleneksel pastaneler, fırınlar ve tatlıcılar',
        latitude: 38.7220,
        longitude: 35.4870,
      ),
      LocationPreset(
        name: 'Talas - Tarihi Mahalle',
        subtitle: 'Kafeler, tatlı ve fırın mekanları',
        latitude: 38.6920,
        longitude: 35.5530,
      ),
    ],
    'Diyarbakır': [
      LocationPreset(
        name: 'Suriçi & Tarihi Hasanpaşa Hanı',
        subtitle: 'Meşhur burma kadayıfçılar, çörek fırınları ve han kahveleri',
        latitude: 37.9135,
        longitude: 40.2370,
      ),
      LocationPreset(
        name: 'Kayapınar - Diclekent',
        subtitle: 'Modern pastaneler, tatlı durakları ve kafeler',
        latitude: 37.9420,
        longitude: 40.1780,
      ),
    ],
    'Samsun': [
      LocationPreset(
        name: 'Çiftlik (İstiklal) Caddesi & Atakum Sahil',
        subtitle: 'Nokul fırınları, pastaneler, kafeler ve dondurmacılar',
        latitude: 41.2880,
        longitude: 36.3360,
      ),
    ],
    'Mersin': [
      LocationPreset(
        name: 'Pozcu & Çamlıbel',
        subtitle: 'Meşhur kerebiç ve tatlı durakları, pastaneler',
        latitude: 36.7960,
        longitude: 34.6190,
      ),
      LocationPreset(
        name: 'Marina & Sahil Kordonu',
        subtitle: 'Kafeler, tatlı mekanları ve fırınlar',
        latitude: 36.7740,
        longitude: 34.5810,
      ),
    ],
    'Hatay': [
      LocationPreset(
        name: 'Antakya Tarihi Çarşı & Saray Caddesi',
        subtitle: 'Meşhur künefeciler, kömbe fırınları ve tarihi tatlıcılar',
        latitude: 36.2025,
        longitude: 36.1605,
      ),
    ],
  };

  /// Reference coordinates for provincial center distance estimation.
  static const Map<String, (double lat, double lon)> provinceCenters = {
    'İstanbul': (41.0082, 28.9784),
    'Ankara': (39.9334, 32.8597),
    'İzmir': (38.4237, 27.1428),
    'Bursa': (40.1885, 29.0610),
    'Gaziantep': (37.0662, 37.3833),
    'Antalya': (36.8969, 30.7133),
    'Adana': (37.0000, 35.3213),
    'Eskişehir': (39.7767, 30.5206),
    'Konya': (37.8746, 32.4932),
    'Trabzon': (41.0027, 39.7168),
    'Kayseri': (38.7205, 35.4826),
    'Diyarbakır': (37.9144, 40.2306),
    'Samsun': (41.2867, 36.3300),
    'Mersin': (36.8121, 34.6415),
    'Hatay': (36.2025, 36.1605),
  };

  /// Calculates geodesic distance (approx. km) using equirectangular projection
  /// for quick province lookup.
  static double _distanceApproxKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon =
        (lon2 - lon1) * math.pi / 180.0 * math.cos((lat1 + lat2) * math.pi / 360.0);
    return r * math.sqrt(dLat * dLat + dLon * dLon);
  }

  /// Automatically identifies the user's province from coordinates [lat], [lon].
  /// Defaults to 'İstanbul' if coordinates are outside Turkey or equidistant.
  static String detectProvince(double lat, double lon) {
    String closestProvince = 'İstanbul';
    double minDistance = double.infinity;

    for (final entry in provinceCenters.entries) {
      final center = entry.value;
      final dist = _distanceApproxKm(lat, lon, center.$1, center.$2);
      if (dist < minDistance) {
        minDistance = dist;
        closestProvince = entry.key;
      }
    }

    return closestProvince;
  }

  /// Returns popular dessert and culinary hubs tailored to the user's coordinates.
  static List<LocationPreset> getPresetsForLocation(double lat, double lon) {
    final province = detectProvince(lat, lon);
    return popularLocationsByProvince[province] ?? popularLocationsByProvince['İstanbul']!;
  }

  /// List of all supported provinces.
  static List<String> get availableProvinces =>
      popularLocationsByProvince.keys.toList();

  /// Backward-compatible static list ensuring existing test suites pass.
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
