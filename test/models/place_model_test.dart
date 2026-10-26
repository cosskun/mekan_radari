import 'package:flutter_test/flutter_test.dart';
import 'package:mekan_radari/models/location_preset.dart';
import 'package:mekan_radari/models/place_model.dart';

Place _createTestPlace({
  String id = 'test-place-1',
  String name = 'Moda Çikolatacısı',
  String category = 'dessert',
  String subCategory = 'Çikolata & Tatlı',
  double rating = 4.8,
  int reviewCount = 245,
  double latitude = 40.9862,
  double longitude = 29.0264,
  double distanceMeters = 350.0,
  String address = 'Moda Cd. No:12, Kadıköy/İstanbul',
  String? phone = '+90 216 555 1234',
  String? website = 'https://modacikolata.test',
  String openingHours = '09:00 - 23:00',
  bool isOpenNow = true,
  int priceLevel = 2,
  List<String> tags = const ['Çikolata', 'Kahve', 'Dondurma'],
  List<String> popularItems = const ['Sıcak Çikolata', 'Trüf'],
  List<PlaceReview> reviews = const [],
  Map<int, double> starDistribution = const {
    5: 0.8,
    4: 0.15,
    3: 0.05,
    2: 0.0,
    1: 0.0
  },
  String dataSource = 'overpass',
  String? customGoogleMapsUri,
}) {
  return Place(
    id: id,
    name: name,
    category: category,
    subCategory: subCategory,
    rating: rating,
    reviewCount: reviewCount,
    latitude: latitude,
    longitude: longitude,
    distanceMeters: distanceMeters,
    address: address,
    phone: phone,
    website: website,
    openingHours: openingHours,
    isOpenNow: isOpenNow,
    priceLevel: priceLevel,
    tags: tags,
    popularItems: popularItems,
    reviews: reviews,
    starDistribution: starDistribution,
    dataSource: dataSource,
    customGoogleMapsUri: customGoogleMapsUri,
  );
}

void main() {
  group('PlaceReview Model Tests', () {
    test('instantiates with defaults correctly', () {
      const review = PlaceReview(
        id: 'r1',
        authorName: 'Ahmet Y.',
        authorBadge: 'Yerel Rehber',
        rating: 4.5,
        relativeTime: '2 gün önce',
        comment: 'Harika tatlılar!',
      );

      expect(review.id, 'r1');
      expect(review.authorName, 'Ahmet Y.');
      expect(review.authorBadge, 'Yerel Rehber');
      expect(review.rating, 4.5);
      expect(review.relativeTime, '2 gün önce');
      expect(review.comment, 'Harika tatlılar!');
      expect(review.likesCount, 0);
      expect(review.orderedItems, isEmpty);
      expect(review.isUserReview, false);
    });

    test('toJson serializes all fields properly', () {
      const review = PlaceReview(
        id: 'r2',
        authorName: 'Zeynep K.',
        authorBadge: 'Gezgin',
        rating: 5.0,
        relativeTime: '1 hafta önce',
        comment: 'En iyi cheesecake.',
        likesCount: 12,
        orderedItems: ['San Sebastian', 'Filtre Kahve'],
        isUserReview: true,
      );

      final json = review.toJson();
      expect(json['id'], 'r2');
      expect(json['authorName'], 'Zeynep K.');
      expect(json['authorBadge'], 'Gezgin');
      expect(json['rating'], 5.0);
      expect(json['relativeTime'], '1 hafta önce');
      expect(json['comment'], 'En iyi cheesecake.');
      expect(json['likesCount'], 12);
      expect(json['orderedItems'], ['San Sebastian', 'Filtre Kahve']);
      expect(json['isUserReview'], true);
    });

    test('fromJson deserializes complete JSON map', () {
      final json = {
        'id': 'r3',
        'authorName': 'Can B.',
        'authorBadge': 'Gurme',
        'rating': 4.0,
        'relativeTime': '3 gün önce',
        'comment': 'Güzel ama biraz pahalı.',
        'likesCount': 3,
        'orderedItems': ['Tiramisu'],
        'isUserReview': false,
      };

      final review = PlaceReview.fromJson(json);
      expect(review.id, 'r3');
      expect(review.authorName, 'Can B.');
      expect(review.rating, 4.0);
      expect(review.likesCount, 3);
      expect(review.orderedItems, ['Tiramisu']);
      expect(review.isUserReview, false);
    });

    test('fromJson handles empty or null fields with robust fallbacks', () {
      final emptyJson = <String, dynamic>{};
      final review = PlaceReview.fromJson(emptyJson);

      expect(review.id, '');
      expect(review.authorName, 'Ziyaretçi');
      expect(review.authorBadge, 'Yerel Rehber');
      expect(review.rating, 5.0);
      expect(review.relativeTime, 'Yeni');
      expect(review.comment, '');
      expect(review.likesCount, 0);
      expect(review.orderedItems, isEmpty);
      expect(review.isUserReview, false);
    });

    test('round-trip JSON serialization preserves all data', () {
      const original = PlaceReview(
        id: 'r4',
        authorName: 'Mert S.',
        authorBadge: '5. Seviye',
        rating: 4.7,
        relativeTime: 'Dün',
        comment: 'Sıcak çikolatası efsane.',
        likesCount: 7,
        orderedItems: ['Sıcak Çikolata'],
        isUserReview: true,
      );

      final roundTrip = PlaceReview.fromJson(original.toJson());
      expect(roundTrip.id, original.id);
      expect(roundTrip.authorName, original.authorName);
      expect(roundTrip.authorBadge, original.authorBadge);
      expect(roundTrip.rating, original.rating);
      expect(roundTrip.relativeTime, original.relativeTime);
      expect(roundTrip.comment, original.comment);
      expect(roundTrip.likesCount, original.likesCount);
      expect(roundTrip.orderedItems, original.orderedItems);
      expect(roundTrip.isUserReview, original.isUserReview);
    });
  });

  group('Place Model Distance & Walking Calculations', () {
    test('formattedDistance formats meters when under 1000m', () {
      expect(_createTestPlace(distanceMeters: 0).formattedDistance, '0 m');
      expect(_createTestPlace(distanceMeters: 45.2).formattedDistance, '45 m');
      expect(_createTestPlace(distanceMeters: 500).formattedDistance, '500 m');
      expect(_createTestPlace(distanceMeters: 999.4).formattedDistance, '999 m');
    });

    test('formattedDistance formats km with 2 decimals when 1000m or more', () {
      expect(_createTestPlace(distanceMeters: 1000.0).formattedDistance, '1.00 km');
      expect(_createTestPlace(distanceMeters: 1250.0).formattedDistance, '1.25 km');
      expect(_createTestPlace(distanceMeters: 2567.8).formattedDistance, '2.57 km');
      expect(_createTestPlace(distanceMeters: 5000.0).formattedDistance, '5.00 km');
    });

    test('walkingMinutes calculates ceil(distance / 75) with minimum of 1 min', () {
      expect(_createTestPlace(distanceMeters: 0).walkingMinutes, 1);
      expect(_createTestPlace(distanceMeters: 30).walkingMinutes, 1);
      expect(_createTestPlace(distanceMeters: 75).walkingMinutes, 1);
      expect(_createTestPlace(distanceMeters: 76).walkingMinutes, 2);
      expect(_createTestPlace(distanceMeters: 150).walkingMinutes, 2);
      expect(_createTestPlace(distanceMeters: 151).walkingMinutes, 3);
      expect(_createTestPlace(distanceMeters: 750).walkingMinutes, 10);
      expect(_createTestPlace(distanceMeters: 1500).walkingMinutes, 20);
      expect(_createTestPlace(distanceMeters: 3000).walkingMinutes, 40);
    });
  });

  group('Place Model Price Symbol & URLs', () {
    test('priceSymbol repeats Turkish Lira sign according to priceLevel clamped 1..4', () {
      expect(_createTestPlace(priceLevel: 1).priceSymbol, '₺');
      expect(_createTestPlace(priceLevel: 2).priceSymbol, '₺₺');
      expect(_createTestPlace(priceLevel: 3).priceSymbol, '₺₺₺');
      expect(_createTestPlace(priceLevel: 4).priceSymbol, '₺₺₺₺');
      expect(_createTestPlace(priceLevel: 0).priceSymbol, '₺');
      expect(_createTestPlace(priceLevel: -3).priceSymbol, '₺');
      expect(_createTestPlace(priceLevel: 5).priceSymbol, '₺₺₺₺');
      expect(_createTestPlace(priceLevel: 10).priceSymbol, '₺₺₺₺');
    });

    test('googleMapsSearchUrl returns custom URI when present and non-empty', () {
      const customUri = 'https://maps.google.com/?cid=123456789';
      final place = _createTestPlace(customGoogleMapsUri: customUri);
      expect(place.googleMapsSearchUrl, customUri);
    });

    test('googleMapsSearchUrl generates valid query URL when custom URI is null or empty', () {
      final placeNull = _createTestPlace(
        id: 'place-abc',
        name: 'Tatlıcı Ali',
        address: 'Kadıköy Çarşı',
        customGoogleMapsUri: null,
      );
      final expectedQuery = Uri.encodeComponent('Tatlıcı Ali Kadıköy Çarşı');
      expect(
        placeNull.googleMapsSearchUrl,
        'https://www.google.com/maps/search/?api=1&query=$expectedQuery&query_place_id=place-abc',
      );

      final placeEmpty = _createTestPlace(
        id: 'place-xyz',
        name: 'Kahve Durağı',
        address: 'Beşiktaş',
        customGoogleMapsUri: '',
      );
      final expectedEmptyQuery = Uri.encodeComponent('Kahve Durağı Beşiktaş');
      expect(
        placeEmpty.googleMapsSearchUrl,
        'https://www.google.com/maps/search/?api=1&query=$expectedEmptyQuery&query_place_id=place-xyz',
      );
    });

    test('googleDirectionsUrl formats walking directions with latitude and longitude', () {
      final place = _createTestPlace(latitude: 41.0430, longitude: 29.0053);
      expect(
        place.googleDirectionsUrl,
        'https://www.google.com/maps/dir/?api=1&destination=41.043,29.0053&travelmode=walking',
      );
    });
  });

  group('Place Model copyWith', () {
    test('updates specified fields while keeping remaining fields unchanged', () {
      final original = _createTestPlace(
        rating: 4.5,
        reviewCount: 100,
        distanceMeters: 500.0,
      );

      const newReview = PlaceReview(
        id: 'r-new',
        authorName: 'Test',
        authorBadge: 'Rehber',
        rating: 5.0,
        relativeTime: 'Şimdi',
        comment: 'Harika',
      );

      final modified = original.copyWith(
        rating: 4.9,
        reviewCount: 150,
        distanceMeters: 250.0,
        reviews: [newReview],
      );

      expect(modified.rating, 4.9);
      expect(modified.reviewCount, 150);
      expect(modified.distanceMeters, 250.0);
      expect(modified.reviews, [newReview]);

      // Unchanged fields preserved
      expect(modified.id, original.id);
      expect(modified.name, original.name);
      expect(modified.category, original.category);
      expect(modified.subCategory, original.subCategory);
      expect(modified.latitude, original.latitude);
      expect(modified.longitude, original.longitude);
      expect(modified.address, original.address);
      expect(modified.phone, original.phone);
      expect(modified.website, original.website);
      expect(modified.openingHours, original.openingHours);
      expect(modified.isOpenNow, original.isOpenNow);
      expect(modified.priceLevel, original.priceLevel);
      expect(modified.tags, original.tags);
      expect(modified.popularItems, original.popularItems);
      expect(modified.starDistribution, original.starDistribution);
      expect(modified.dataSource, original.dataSource);
      expect(modified.customGoogleMapsUri, original.customGoogleMapsUri);
    });

    test('copyWith without parameters retains all original values', () {
      final original = _createTestPlace();
      final identicalCopy = original.copyWith();

      expect(identicalCopy.id, original.id);
      expect(identicalCopy.rating, original.rating);
      expect(identicalCopy.reviewCount, original.reviewCount);
      expect(identicalCopy.distanceMeters, original.distanceMeters);
      expect(identicalCopy.reviews, original.reviews);
    });
  });

  group('PlaceCategoryFilter Model Tests', () {
    test('allCategories contains 6 standard categories with unique IDs', () {
      final categories = PlaceCategoryFilter.allCategories;
      expect(categories.length, 6);

      final ids = categories.map((c) => c.id).toSet();
      expect(ids.length, 6);
      expect(
        ids,
        containsAll([
          'all',
          'dessert',
          'coffee',
          'restaurant',
          'fast_food',
          'bakery'
        ]),
      );
    });

    test('allCategories entries have valid labels and emojis', () {
      for (final cat in PlaceCategoryFilter.allCategories) {
        expect(cat.id.isNotEmpty, true);
        expect(cat.label.isNotEmpty, true);
        expect(cat.emoji.isNotEmpty, true);
      }
    });

    test('all category has empty keywords and dessert category contains dessert keywords', () {
      final allCat = PlaceCategoryFilter.allCategories.firstWhere((c) => c.id == 'all');
      expect(allCat.keywords, isEmpty);

      final dessertCat =
          PlaceCategoryFilter.allCategories.firstWhere((c) => c.id == 'dessert');
      expect(dessertCat.keywords, contains('tatlı'));
      expect(dessertCat.keywords, contains('pastane'));
      expect(dessertCat.keywords, contains('baklava'));
      expect(dessertCat.keywords, contains('dondurma'));

      final coffeeCat =
          PlaceCategoryFilter.allCategories.firstWhere((c) => c.id == 'coffee');
      expect(coffeeCat.keywords, contains('kahve'));
      expect(coffeeCat.keywords, contains('kafe'));
      expect(coffeeCat.keywords, contains('espresso'));
    });
  });

  group('LocationPreset Model Tests', () {
    test('popularLocations contains 6 verified Turkish dining hubs', () {
      final locations = LocationPreset.popularLocations;
      expect(locations.length, 6);

      expect(locations[0].name, 'Kadıköy - Moda & Çarşı');
      expect(locations[0].latitude, closeTo(40.9862, 0.0001));
      expect(locations[0].longitude, closeTo(29.0264, 0.0001));

      expect(locations[1].name, 'Beşiktaş - Çarşı & Akaretler');
      expect(locations[2].name, 'Karaköy & Galata');
      expect(locations[3].name, 'Bağdat Caddesi - Suadiye');
      expect(locations[4].name, 'Kızılay & Tunalı Hilmi');
      expect(locations[5].name, 'Alsancak - Kıbrıs Şehitleri');
    });

    test('all popularLocations have valid coordinates and non-empty metadata', () {
      for (final loc in LocationPreset.popularLocations) {
        expect(loc.name.isNotEmpty, true);
        expect(loc.subtitle.isNotEmpty, true);
        expect(loc.latitude >= -90 && loc.latitude <= 90, true);
        expect(loc.longitude >= -180 && loc.longitude <= 180, true);
      }
    });

    test('toJson and fromJson support round-trip serialization', () {
      const preset = LocationPreset(
        name: 'Kadıköy Moda',
        subtitle: 'İstanbul',
        latitude: 40.9862,
        longitude: 29.0264,
      );

      final json = preset.toJson();
      expect(json['name'], 'Kadıköy Moda');
      expect(json['subtitle'], 'İstanbul');
      expect(json['latitude'], 40.9862);
      expect(json['longitude'], 29.0264);

      final deserialized = LocationPreset.fromJson(json);
      expect(deserialized, preset);
    });

    test('fromJson handles empty JSON with defaults', () {
      final emptyPreset = LocationPreset.fromJson(const {});
      expect(emptyPreset.name, '');
      expect(emptyPreset.subtitle, '');
      expect(emptyPreset.latitude, 0.0);
      expect(emptyPreset.longitude, 0.0);
    });

    test('copyWith updates fields as requested', () {
      const preset = LocationPreset(
        name: 'Kadıköy',
        subtitle: 'Anadolu',
        latitude: 40.9862,
        longitude: 29.0264,
      );

      final updated = preset.copyWith(name: 'Beşiktaş', latitude: 41.0430);
      expect(updated.name, 'Beşiktaş');
      expect(updated.subtitle, 'Anadolu');
      expect(updated.latitude, 41.0430);
      expect(updated.longitude, 29.0264);
    });

    test('equality and hashCode evaluate correctly', () {
      const a = LocationPreset(
        name: 'X',
        subtitle: 'Y',
        latitude: 10.0,
        longitude: 20.0,
      );
      const b = LocationPreset(
        name: 'X',
        subtitle: 'Y',
        latitude: 10.0,
        longitude: 20.0,
      );
      const c = LocationPreset(
        name: 'Z',
        subtitle: 'Y',
        latitude: 10.0,
        longitude: 20.0,
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, false);
    });
  });
}
