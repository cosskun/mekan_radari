import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekan_radari/models/place_model.dart';
import 'package:mekan_radari/widgets/venue_card.dart';

Place _createTestPlace({
  String id = 'place-1',
  String name = 'Moda Çikolatacısı',
  String category = 'Tatlı & Pastane',
  String subCategory = 'Çikolata & Tatlı',
  double rating = 4.8,
  int reviewCount = 120,
  double distanceMeters = 350.0,
  String address = 'Moda Cd. No:12, Kadıköy',
  List<String> popularItems = const ['Sıcak Çikolata', 'Trüf', 'Waffle', 'Kruvasan'],
  List<PlaceReview> reviews = const [
    PlaceReview(
      id: 'rev-1',
      authorName: 'Ece D.',
      authorBadge: 'Yerel Rehber',
      rating: 5.0,
      relativeTime: '2 gün önce',
      comment: 'Harika bir çikolata deneyimi.',
    ),
  ],
}) {
  return Place(
    id: id,
    name: name,
    category: category,
    subCategory: subCategory,
    rating: rating,
    reviewCount: reviewCount,
    latitude: 40.9862,
    longitude: 29.0264,
    distanceMeters: distanceMeters,
    address: address,
    openingHours: '09:00 - 23:00',
    isOpenNow: true,
    priceLevel: 2,
    tags: const ['tatlı', 'çikolata'],
    popularItems: popularItems,
    reviews: reviews,
    starDistribution: const {5: 0.8, 4: 0.2},
    dataSource: 'overpass',
  );
}

void main() {
  group('VenueCard Widget Tests', () {
    testWidgets('renders venue name, address, category and distance badges', (tester) async {
      final place = _createTestPlace();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VenueCard(
              place: place,
              isFavorite: false,
              onToggleFavorite: () {},
            ),
          ),
        ),
      );

      expect(find.text('Moda Çikolatacısı'), findsOneWidget);
      expect(find.text('Moda Cd. No:12, Kadıköy'), findsOneWidget);
      expect(find.text('Çikolata & Tatlı'), findsOneWidget);
      expect(find.text('350 m (5 dk)'), findsOneWidget);
      expect(find.text('4.8'), findsOneWidget);
      expect(find.text('120 yorum'), findsOneWidget);
    });

    testWidgets('renders up to 3 popular item chips with fork prefix', (tester) async {
      final place = _createTestPlace();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VenueCard(
              place: place,
              isFavorite: false,
              onToggleFavorite: () {},
            ),
          ),
        ),
      );

      expect(find.text('🍴 Sıcak Çikolata'), findsOneWidget);
      expect(find.text('🍴 Trüf'), findsOneWidget);
      expect(find.text('🍴 Waffle'), findsOneWidget);
      // Fourth item should be excluded by take(3)
      expect(find.text('🍴 Kruvasan'), findsNothing);
    });

    testWidgets('renders featured review quote when reviews exist', (tester) async {
      final place = _createTestPlace();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VenueCard(
              place: place,
              isFavorite: false,
              onToggleFavorite: () {},
            ),
          ),
        ),
      );

      expect(find.text('"Harika bir çikolata deneyimi." — Ece D.'), findsOneWidget);
    });

    testWidgets('toggles favorite icon between filled red and border outline', (tester) async {
      bool favoriteToggled = false;
      final place = _createTestPlace();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VenueCard(
              place: place,
              isFavorite: false,
              onToggleFavorite: () => favoriteToggled = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsNothing);

      await tester.tap(find.byIcon(Icons.favorite_border_rounded));
      expect(favoriteToggled, isTrue);

      // Re-pump with isFavorite: true
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VenueCard(
              place: place,
              isFavorite: true,
              onToggleFavorite: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
    });

    testWidgets('invokes onTap callback when card is tapped', (tester) async {
      bool tapped = false;
      final place = _createTestPlace();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VenueCard(
              place: place,
              isFavorite: false,
              onToggleFavorite: () {},
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Moda Çikolatacısı'));
      expect(tapped, isTrue);
    });

    testWidgets('invokes onLaunchUrl when Google Yorumlarını Gör is pressed', (tester) async {
      String? launchedUrl;
      final place = _createTestPlace();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VenueCard(
              place: place,
              isFavorite: false,
              onToggleFavorite: () {},
              onLaunchUrl: (url) async => launchedUrl = url,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Google Yorumlarını Gör'));
      expect(launchedUrl, contains('google.com/maps/search'));
    });
  });
}
