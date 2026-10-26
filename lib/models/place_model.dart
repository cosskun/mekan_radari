import 'dart:math';

class PlaceReview {
  final String id;
  final String authorName;
  final String authorBadge;
  final double rating;
  final String relativeTime;
  final String comment;
  final int likesCount;
  final List<String> orderedItems;
  final bool isUserReview;

  const PlaceReview({
    required this.id,
    required this.authorName,
    required this.authorBadge,
    required this.rating,
    required this.relativeTime,
    required this.comment,
    this.likesCount = 0,
    this.orderedItems = const [],
    this.isUserReview = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorName': authorName,
        'authorBadge': authorBadge,
        'rating': rating,
        'relativeTime': relativeTime,
        'comment': comment,
        'likesCount': likesCount,
        'orderedItems': orderedItems,
        'isUserReview': isUserReview,
      };

  factory PlaceReview.fromJson(Map<String, dynamic> json) => PlaceReview(
        id: json['id']?.toString() ?? '',
        authorName: json['authorName']?.toString() ?? 'Ziyaretçi',
        authorBadge: json['authorBadge']?.toString() ?? 'Yerel Rehber',
        rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
        relativeTime: json['relativeTime']?.toString() ?? 'Yeni',
        comment: json['comment']?.toString() ?? '',
        likesCount: (json['likesCount'] as num?)?.toInt() ?? 0,
        orderedItems: (json['orderedItems'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        isUserReview: json['isUserReview'] == true,
      );
}

class Place {
  final String id;
  final String name;
  final String category;
  final String subCategory;
  final double rating;
  final int reviewCount;
  final double latitude;
  final double longitude;
  final double distanceMeters;
  final String address;
  final String? phone;
  final String? website;
  final String openingHours;
  final bool isOpenNow;
  final int priceLevel; // 1: ₺, 2: ₺₺, 3: ₺₺₺, 4: ₺₺₺₺
  final List<String> tags;
  final List<String> popularItems;
  final List<PlaceReview> reviews;
  final Map<int, double> starDistribution; // 5..1 -> 0.0..1.0
  final String dataSource;
  final String? customGoogleMapsUri;

  const Place({
    required this.id,
    required this.name,
    required this.category,
    required this.subCategory,
    required this.rating,
    required this.reviewCount,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    required this.address,
    this.phone,
    this.website,
    required this.openingHours,
    required this.isOpenNow,
    required this.priceLevel,
    required this.tags,
    required this.popularItems,
    required this.reviews,
    required this.starDistribution,
    required this.dataSource,
    this.customGoogleMapsUri,
  });

  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(2)} km';
  }

  String get priceSymbol => '₺' * priceLevel.clamp(1, 4);

  String get googleMapsSearchUrl {
    if (customGoogleMapsUri != null && customGoogleMapsUri!.isNotEmpty) {
      return customGoogleMapsUri!;
    }
    final query = Uri.encodeComponent('$name $address');
    return 'https://www.google.com/maps/search/?api=1&query=$query&query_place_id=$id';
  }

  String get googleDirectionsUrl {
    return 'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=walking';
  }

  int get walkingMinutes {
    // Average walking speed ~75 meters per minute
    return max(1, (distanceMeters / 75).ceil());
  }

  Place copyWith({
    double? rating,
    int? reviewCount,
    double? distanceMeters,
    List<PlaceReview>? reviews,
  }) {
    return Place(
      id: id,
      name: name,
      category: category,
      subCategory: subCategory,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      latitude: latitude,
      longitude: longitude,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      address: address,
      phone: phone,
      website: website,
      openingHours: openingHours,
      isOpenNow: isOpenNow,
      priceLevel: priceLevel,
      tags: tags,
      popularItems: popularItems,
      reviews: reviews ?? this.reviews,
      starDistribution: starDistribution,
      dataSource: dataSource,
      customGoogleMapsUri: customGoogleMapsUri,
    );
  }
}

class PlaceCategoryFilter {
  final String id;
  final String label;
  final String emoji;
  final List<String> keywords;

  const PlaceCategoryFilter({
    required this.id,
    required this.label,
    required this.emoji,
    required this.keywords,
  });

  static const List<PlaceCategoryFilter> allCategories = [
    PlaceCategoryFilter(
      id: 'all',
      label: 'Tümü',
      emoji: '✨',
      keywords: [],
    ),
    PlaceCategoryFilter(
      id: 'dessert',
      label: 'Tatlı & Pastane',
      emoji: '🍰',
      keywords: [
        'tatlı',
        'pastane',
        'baklava',
        'künefe',
        'waffle',
        'dondurma',
        'çikolata',
        'profiterol',
        'muhallebi',
        'sütlaç',
        'cheesecake',
        'pasta',
        'pastry',
        'confectionery',
        'dessert',
        'ice_cream',
        'bakery',
      ],
    ),
    PlaceCategoryFilter(
      id: 'coffee',
      label: 'Kahve & Kafe',
      emoji: '☕',
      keywords: [
        'kahve',
        'kafe',
        'cafe',
        'coffee',
        'espresso',
        'roastery',
        'çay',
      ],
    ),
    PlaceCategoryFilter(
      id: 'restaurant',
      label: 'Restoran & Yemek',
      emoji: '🍽️',
      keywords: [
        'restoran',
        'restaurant',
        'kebap',
        'pide',
        'lahmacun',
        'balık',
        'et',
        'meyhane',
        'ev yemekleri',
        'lokanta',
      ],
    ),
    PlaceCategoryFilter(
      id: 'fast_food',
      label: 'Burger & Sokak Lezzeti',
      emoji: '🍔',
      keywords: [
        'burger',
        'pizza',
        'döner',
        'tantuni',
        'kokoreç',
        'tost',
        'fast_food',
        'sandviç',
      ],
    ),
    PlaceCategoryFilter(
      id: 'bakery',
      label: 'Fırın & Kahvaltı',
      emoji: '🥐',
      keywords: [
        'fırın',
        'börek',
        'simit',
        'kahvaltı',
        'kruvasan',
        'poğaça',
        'unlu',
      ],
    ),
  ];
}
