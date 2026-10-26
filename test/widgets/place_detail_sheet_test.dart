import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekan_radari/models/place_model.dart';
import 'package:mekan_radari/screens/place_detail_sheet.dart';

void main() {
  group('PlaceDetailSheet Review Filtering, Sorting & Sentiment Tests', () {
    late Place testPlace;

    setUp(() {
      testPlace = const Place(
        id: 'place_test_detail',
        name: 'Moda Çikolatacısı & Tatlı Evi',
        category: 'dessert',
        subCategory: 'Çikolata & Tatlı',
        rating: 4.6,
        reviewCount: 4,
        latitude: 40.9850,
        longitude: 29.0270,
        distanceMeters: 250.0,
        address: 'Moda Cad. No:42, Kadıköy, İstanbul',
        openingHours: '10:00 - 23:00',
        isOpenNow: true,
        priceLevel: 2,
        tags: ['Çikolata', 'Sıcak Çikolata', 'Waffle'],
        popularItems: ['Fondü', 'Trüf Çikolata'],
        dataSource: 'OpenStreetMap',
        starDistribution: {
          5: 0.75,
          4: 0.20,
          3: 0.05,
          2: 0.0,
          1: 0.0,
        },
        reviews: [
          PlaceReview(
            id: 'rev_1',
            authorName: 'Canan Demir',
            authorBadge: 'Yerel Gurme',
            rating: 5.0,
            relativeTime: '2 gün önce',
            comment: 'Sıcak çikolatası İstanbul\'daki en iyisi!',
            likesCount: 14,
            orderedItems: ['Sıcak Çikolata'],
          ),
          PlaceReview(
            id: 'rev_2',
            authorName: 'Barış Yıldız',
            authorBadge: 'Doğrulanmış Ziyaretçi',
            rating: 4.0,
            relativeTime: '1 hafta önce',
            comment: 'Lezzetli tatlılar ama hafta sonu sıra çok oluyor.',
            likesCount: 5,
            orderedItems: ['Fondü'],
          ),
          PlaceReview(
            id: 'rev_3',
            authorName: 'Elif Kaya',
            authorBadge: 'Rehber Seviye 4',
            rating: 3.0,
            relativeTime: '1 ay önce',
            comment: 'Ortalama bir deneyimdi, porsiyonlar biraz küçülmüş.',
            likesCount: 2,
          ),
          PlaceReview(
            id: 'rev_4',
            authorName: 'Kerem Yılmaz',
            authorBadge: 'Doğrulanmış Ziyaretçi',
            rating: 5.0,
            relativeTime: '1 saat önce',
            comment: 'Trüf çikolatalar taptazeydi, servis de çok hızlıydı.',
            likesCount: 8,
          ),
        ],
      );
    });

    Widget buildSheetWidget(Place place, {ValueChanged<PlaceReview>? onAddReview}) {
      return MaterialApp(
        home: Scaffold(
          body: PlaceDetailSheet(
            place: place,
            isFavorite: false,
            onToggleFavorite: () {},
            onAddReview: onAddReview ?? (_) {},
          ),
        ),
      );
    }

    testWidgets('R1: Renders venue details, sentiment card, and all initial reviews',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildSheetWidget(testPlace));
      await tester.pumpAndSettle();

      // Check Place metadata
      expect(find.text('Moda Çikolatacısı & Tatlı Evi'), findsOneWidget);
      expect(find.text('4.6'), findsWidgets);

      // Check Sentiment Breakdown card
      expect(find.text('Duygu & Memnuniyet Analizi'), findsOneWidget);
      expect(find.textContaining('Memnuniyet'), findsWidgets);
      expect(find.textContaining('Olumlu'), findsWidgets);

      // Check Filter Chips exist
      expect(find.byKey(const Key('review_filter_all')), findsOneWidget);
      expect(find.byKey(const Key('review_filter_5')), findsOneWidget);
      expect(find.byKey(const Key('review_filter_4')), findsOneWidget);
      expect(find.byKey(const Key('review_filter_3')), findsOneWidget);
      expect(find.byKey(const Key('review_filter_2')), findsOneWidget);
      expect(find.byKey(const Key('review_filter_1')), findsOneWidget);

      // Check Sort button exists
      expect(find.byKey(const Key('review_sort_button')), findsOneWidget);

      // All 4 initial reviews should be rendered
      expect(find.text('Canan Demir'), findsOneWidget);
      expect(find.text('Barış Yıldız'), findsOneWidget);
      expect(find.text('Elif Kaya'), findsOneWidget);
      expect(find.text('Kerem Yılmaz'), findsOneWidget);
    });

    testWidgets('R1: Star filter chips filter reviews dynamically', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildSheetWidget(testPlace));
      await tester.pumpAndSettle();

      // Tap 5★ filter chip
      await tester.tap(find.byKey(const Key('review_filter_5')));
      await tester.pumpAndSettle();

      // Should only show 5-star reviews (Canan Demir & Kerem Yılmaz)
      expect(find.text('Canan Demir'), findsOneWidget);
      expect(find.text('Kerem Yılmaz'), findsOneWidget);
      expect(find.text('Barış Yıldız'), findsNothing);
      expect(find.text('Elif Kaya'), findsNothing);

      // Tap 4★ filter chip
      await tester.tap(find.byKey(const Key('review_filter_4')));
      await tester.pumpAndSettle();

      // Should only show 4-star review (Barış Yıldız)
      expect(find.text('Barış Yıldız'), findsOneWidget);
      expect(find.text('Canan Demir'), findsNothing);
      expect(find.text('Kerem Yılmaz'), findsNothing);

      // Tap 1★ filter chip (no 1-star reviews)
      await tester.tap(find.byKey(const Key('review_filter_1')));
      await tester.pumpAndSettle();

      expect(find.textContaining('kriterine uygun değerlendirme bulunamadı'), findsOneWidget);
      expect(find.text('Tüm Yorumları Göster'), findsOneWidget);

      // Tap reset button
      await tester.tap(find.text('Tüm Yorumları Göster'));
      await tester.pumpAndSettle();

      // All reviews restored
      expect(find.text('Canan Demir'), findsOneWidget);
      expect(find.text('Barış Yıldız'), findsOneWidget);
      expect(find.text('Elif Kaya'), findsOneWidget);
      expect(find.text('Kerem Yılmaz'), findsOneWidget);

      // Tapping All chip explicitly
      await tester.tap(find.byKey(const Key('review_filter_3')));
      await tester.pumpAndSettle();
      expect(find.text('Elif Kaya'), findsOneWidget);
      expect(find.text('Canan Demir'), findsNothing);

      await tester.tap(find.byKey(const Key('review_filter_all')));
      await tester.pumpAndSettle();
      expect(find.text('Canan Demir'), findsOneWidget);
      expect(find.text('Barış Yıldız'), findsOneWidget);
    });

    testWidgets('R1: Tapping star distribution bar filters reviews dynamically and toggles',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildSheetWidget(testPlace));
      await tester.pumpAndSettle();

      // Tap 4-star distribution bar
      await tester.tap(find.byKey(const ValueKey('star_bar_4')));
      await tester.pumpAndSettle();

      // Only Barış Yıldız (4★) should be visible
      expect(find.text('Barış Yıldız'), findsOneWidget);
      expect(find.text('Canan Demir'), findsNothing);

      // Tap 4-star bar again -> should toggle back to All
      await tester.tap(find.byKey(const ValueKey('star_bar_4')));
      await tester.pumpAndSettle();

      expect(find.text('Canan Demir'), findsOneWidget);
      expect(find.text('Barış Yıldız'), findsOneWidget);
      expect(find.text('Elif Kaya'), findsOneWidget);
      expect(find.text('Kerem Yılmaz'), findsOneWidget);

      // Tap 5-star distribution bar
      await tester.tap(find.byKey(const ValueKey('star_bar_5')));
      await tester.pumpAndSettle();

      expect(find.text('Canan Demir'), findsOneWidget);
      expect(find.text('Kerem Yılmaz'), findsOneWidget);
      expect(find.text('Barış Yıldız'), findsNothing);
    });

    testWidgets('R1: Sorting reorders reviews correctly (Newest, Highest, Lowest)',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildSheetWidget(testPlace));
      await tester.pumpAndSettle();

      // Under Newest (default): Kerem (1 saat önce) should appear before Canan (2 gün önce)
      final keremInitial = tester.getTopLeft(find.text('Kerem Yılmaz')).dy;
      final cananInitial = tester.getTopLeft(find.text('Canan Demir')).dy;
      expect(keremInitial, lessThan(cananInitial));

      // Select 'Lowest Rated' sort option
      await tester.tap(find.byKey(const Key('review_sort_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('review_sort_lowest')).last);
      await tester.pumpAndSettle();

      // In Lowest Rated: Elif Kaya (3.0★) should appear before Kerem Yılmaz (5.0★)
      final elifLowest = tester.getTopLeft(find.text('Elif Kaya')).dy;
      final keremLowest = tester.getTopLeft(find.text('Kerem Yılmaz')).dy;
      expect(elifLowest, lessThan(keremLowest));

      // Select 'Highest Rated' sort option
      await tester.tap(find.byKey(const Key('review_sort_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('review_sort_highest')).last);
      await tester.pumpAndSettle();

      // In Highest Rated: 5.0★ (Kerem/Canan) should appear before 3.0★ (Elif)
      final keremHighest = tester.getTopLeft(find.text('Kerem Yılmaz')).dy;
      final elifHighest = tester.getTopLeft(find.text('Elif Kaya')).dy;
      expect(keremHighest, lessThan(elifHighest));
    });

    testWidgets('R1: Verified visitor badges, rating indicator, and helpful badge interaction',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildSheetWidget(testPlace));
      await tester.pumpAndSettle();

      // Verified visitor tag
      expect(find.text('Doğrulanmış Ziyaretçi'), findsWidgets);
      expect(find.byIcon(Icons.verified_rounded), findsWidgets);

      // Sentiment badges
      expect(find.text('Harika'), findsWidgets);
      expect(find.text('Çok İyi'), findsWidgets);

      // Helpful badge for rev_1 starts at 14 likes
      expect(find.text('Faydalı (14)'), findsOneWidget);

      // Tap helpful button for rev_1 to like it
      await tester.tap(find.byKey(const ValueKey('helpful_badge_rev_1')));
      await tester.pump();

      // Likes count incremented to 15
      expect(find.text('Faydalı (15)'), findsOneWidget);

      // Tap again to toggle off
      await tester.tap(find.byKey(const ValueKey('helpful_badge_rev_1')));
      await tester.pump();

      expect(find.text('Faydalı (14)'), findsOneWidget);
    });

    testWidgets('R1: Adding new review instantly updates UI, recency, and resets filter',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      PlaceReview? capturedReview;
      await tester.pumpWidget(
        buildSheetWidget(
          testPlace,
          onAddReview: (r) => capturedReview = r,
        ),
      );
      await tester.pumpAndSettle();

      // Filter to 3★ first
      await tester.tap(find.byKey(const Key('review_filter_3')));
      await tester.pumpAndSettle();
      expect(find.text('Elif Kaya'), findsOneWidget);
      expect(find.text('Canan Demir'), findsNothing);

      // Open Add Review dialog
      await tester.tap(find.text('Yorum Yaz'));
      await tester.pumpAndSettle();

      // Enter name and comment
      final nameField = find.widgetWithText(TextField, 'Adınız (İsteğe bağlı)');
      final commentField = find.widgetWithText(
        TextField,
        'Deneyiminizi ve önerdiğiniz lezzetleri paylaşın...',
      );

      await tester.enterText(nameField, 'Furkan Çoşkun');
      await tester.enterText(commentField, 'Enfes lezzet ve harika sunum!');
      await tester.pump();

      // Submit
      await tester.tap(find.text('Yorumu Yayınla'));
      await tester.pumpAndSettle();

      // Verify callback was invoked
      expect(capturedReview, isNotNull);
      expect(capturedReview!.authorName, equals('Furkan Çoşkun'));

      // New review should immediately appear at the top with "Sizin Yorumunuz" tag
      expect(find.text('Furkan Çoşkun'), findsOneWidget);
      expect(find.text('Enfes lezzet ve harika sunum!'), findsOneWidget);
      expect(find.text('Sizin Yorumunuz'), findsOneWidget);
    });

    testWidgets(
        'R1 Adversarial: Place with 0 reviews renders honest 0% sentiment, zero star bars, and proper empty state with CTA',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const emptyPlace = Place(
        id: 'place_empty_test',
        name: 'Yeni Açılan Kahveci',
        category: 'coffee',
        subCategory: 'Kahve & Kafe',
        rating: 0.0,
        reviewCount: 0,
        latitude: 40.9900,
        longitude: 29.0300,
        distanceMeters: 100.0,
        address: 'Bahariye Cad. No:1, Kadıköy',
        openingHours: '08:00 - 22:00',
        isOpenNow: true,
        priceLevel: 1,
        tags: ['Kahve'],
        popularItems: [],
        reviews: [],
        starDistribution: {},
        dataSource: 'OpenStreetMap',
      );

      await tester.pumpWidget(buildSheetWidget(emptyPlace));
      await tester.pumpAndSettle();

      // Check sentiment card shows honest zero state
      expect(find.text('Değerlendirme Yok'), findsOneWidget);
      expect(find.text('Olumlu %0'), findsOneWidget);
      expect(find.text('Dengeli %0'), findsOneWidget);
      expect(find.text('Eleştiri %0'), findsOneWidget);

      // Check empty state message and CTA button
      expect(
        find.text('Bu mekan için henüz değerlendirme yapılmamış.'),
        findsOneWidget,
      );
      expect(find.text('İlk Değerlendirmeyi Siz Yapın'), findsOneWidget);
      expect(find.textContaining('null★'), findsNothing);

      // Tapping "İlk Değerlendirmeyi Siz Yapın" opens add review sheet
      await tester.tap(find.text('İlk Değerlendirmeyi Siz Yapın'));
      await tester.pumpAndSettle();

      expect(find.text('Yeni Açılan Kahveci İçin Yorum Yaz'), findsOneWidget);
    });

    testWidgets(
        'R1 Adversarial: Robust recency scoring orders "dün" before "10 ay önce" and handles ISO dates',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final placeWithEdgeTimes = Place(
        id: 'place_edge_times',
        name: 'Tarihi Kahve Fırını',
        category: 'coffee',
        subCategory: 'Kahve',
        rating: 4.5,
        reviewCount: 3,
        latitude: 40.9850,
        longitude: 29.0270,
        distanceMeters: 200.0,
        address: 'Moda Cad.',
        openingHours: '08:00 - 20:00',
        isOpenNow: true,
        priceLevel: 2,
        tags: const [],
        popularItems: const [],
        dataSource: 'OSM',
        starDistribution: const {5: 1.0},
        reviews: const [
          PlaceReview(
            id: 'old_rev',
            authorName: 'Eski Yorumcu',
            authorBadge: 'Ziyaretçi',
            rating: 5.0,
            relativeTime: '10 ay önce',
            comment: 'Eski güzel günler...',
          ),
          PlaceReview(
            id: 'yesterday_rev',
            authorName: 'Dünkü Yorumcu',
            authorBadge: 'Ziyaretçi',
            rating: 5.0,
            relativeTime: 'dün',
            comment: 'Dün uğradım, harikaydı.',
          ),
          PlaceReview(
            id: 'iso_rev',
            authorName: 'ISO Yorumcu',
            authorBadge: 'Ziyaretçi',
            rating: 5.0,
            relativeTime: '2026-10-26T10:00:00Z',
            comment: 'Sistem logu yorumu.',
          ),
        ],
      );

      await tester.pumpWidget(buildSheetWidget(placeWithEdgeTimes));
      await tester.pumpAndSettle();

      // Under Newest:
      // Dünkü Yorumcu (yesterday) should be before Eski Yorumcu (10 months ago)
      final yesterdayY = tester.getTopLeft(find.text('Dünkü Yorumcu')).dy;
      final oldY = tester.getTopLeft(find.text('Eski Yorumcu')).dy;
      expect(yesterdayY, lessThan(oldY));
    });

    testWidgets(
        'R1 Adversarial: Submitting a new review resets sort option to Newest and clears star filter',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildSheetWidget(testPlace));
      await tester.pumpAndSettle();

      // Change sort to Lowest Rated first
      await tester.tap(find.byKey(const Key('review_sort_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('review_sort_lowest')).last);
      await tester.pumpAndSettle();

      // Set filter to 3★
      await tester.tap(find.byKey(const Key('review_filter_3')));
      await tester.pumpAndSettle();

      // Submit 5-star review
      await tester.tap(find.text('Yorum Yaz'));
      await tester.pumpAndSettle();

      final commentField = find.widgetWithText(
        TextField,
        'Deneyiminizi ve önerdiğiniz lezzetleri paylaşın...',
      );
      await tester.enterText(commentField, 'Harika bir tatlı şöleni!');
      await tester.pump();

      await tester.tap(find.text('Yorumu Yayınla'));
      await tester.pumpAndSettle();

      // New review appears at the very top because sort was reset to Newest and filter was cleared
      final newRevY = tester.getTopLeft(find.text('Harika bir tatlı şöleni!')).dy;
      final elifY = tester.getTopLeft(find.text('Elif Kaya')).dy;
      expect(newRevY, lessThan(elifY));
    });

    testWidgets(
        'R1 Round 2 Adversarial: Resilient against empty/whitespace authorName without StateError crash',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final placeWithBlankAuthors = Place(
        id: 'place_blank_authors',
        name: 'Boş İsimli Yorum Mekanı',
        category: 'cafe',
        subCategory: 'Kafe',
        rating: 4.0,
        reviewCount: 2,
        latitude: 40.9850,
        longitude: 29.0270,
        distanceMeters: 150.0,
        address: 'Kadıköy',
        openingHours: '09:00 - 22:00',
        isOpenNow: true,
        priceLevel: 1,
        tags: const [],
        popularItems: const [],
        dataSource: 'OSM',
        starDistribution: const {4: 1.0},
        reviews: const [
          PlaceReview(
            id: 'rev_empty_name',
            authorName: '',
            authorBadge: 'Ziyaretçi',
            rating: 4.0,
            relativeTime: 'bugün',
            comment: 'İsimsiz mükemmel deneyim.',
          ),
          PlaceReview(
            id: 'rev_whitespace_name',
            authorName: '   ',
            authorBadge: 'Ziyaretçi',
            rating: 4.0,
            relativeTime: 'dün',
            comment: 'Boşluklu isimli kullanıcı yorumu.',
          ),
        ],
      );

      // Must build and pump without throwing StateError: No element on characters.first
      await tester.pumpWidget(buildSheetWidget(placeWithBlankAuthors));
      await tester.pumpAndSettle();

      expect(find.text('Anonim Ziyaretçi'), findsNWidgets(2));
      expect(find.text('İsimsiz mükemmel deneyim.'), findsOneWidget);
      expect(find.text('Boşluklu isimli kullanıcı yorumu.'), findsOneWidget);
    });

    testWidgets(
        'R1 Round 2 Adversarial: Honest satisfaction badge coloring (Red for low, Amber for moderate, Emerald for high)',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final lowSatisfactionPlace = Place(
        id: 'place_low_satisfaction',
        name: 'Şikayet Alan Mekan',
        category: 'fast_food',
        subCategory: 'Büfe',
        rating: 1.5,
        reviewCount: 3,
        latitude: 40.9850,
        longitude: 29.0270,
        distanceMeters: 300.0,
        address: 'Kadıköy',
        openingHours: '10:00 - 20:00',
        isOpenNow: true,
        priceLevel: 1,
        tags: const [],
        popularItems: const [],
        dataSource: 'OSM',
        starDistribution: const {1: 1.0},
        reviews: const [
          PlaceReview(
            id: 'rev_bad_1',
            authorName: 'Ali Can',
            authorBadge: 'Ziyaretçi',
            rating: 1.0,
            relativeTime: '1 gün önce',
            comment: 'Kötü servis.',
          ),
          PlaceReview(
            id: 'rev_bad_2',
            authorName: 'Veli Bey',
            authorBadge: 'Ziyaretçi',
            rating: 2.0,
            relativeTime: '2 gün önce',
            comment: 'Lezzetsiz yemekler.',
          ),
          PlaceReview(
            id: 'rev_bad_3',
            authorName: 'Ayşe Hanım',
            authorBadge: 'Ziyaretçi',
            rating: 1.0,
            relativeTime: '3 gün önce',
            comment: 'Asla tavsiye etmem.',
          ),
        ],
      );

      await tester.pumpWidget(buildSheetWidget(lowSatisfactionPlace));
      await tester.pumpAndSettle();

      final badgeFinder = find.text('%0 Memnuniyet');
      expect(badgeFinder, findsOneWidget);

      final Text badgeWidget = tester.widget(badgeFinder);
      // Under 40% positive reviews, color MUST be red (0xFFEF4444), NOT emerald green!
      expect(badgeWidget.style?.color, equals(const Color(0xFFEF4444)));
    });

    testWidgets(
        'R1 Round 2 Adversarial: Parses European dates (DD.MM.YYYY) and named Turkish dates without "Mayıs" regex collision',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final placeWithDiverseDates = Place(
        id: 'place_dates_test',
        name: 'Tarih Format Test Mekanı',
        category: 'cafe',
        subCategory: 'Kafe',
        rating: 4.5,
        reviewCount: 3,
        latitude: 40.9850,
        longitude: 29.0270,
        distanceMeters: 100.0,
        address: 'Kadıköy',
        openingHours: '10:00 - 22:00',
        isOpenNow: true,
        priceLevel: 1,
        tags: const [],
        popularItems: const [],
        dataSource: 'OSM',
        starDistribution: const {5: 1.0},
        reviews: const [
          PlaceReview(
            id: 'rev_older_dmy',
            authorName: 'Geçen Yıl Yorumcusu',
            authorBadge: 'Ziyaretçi',
            rating: 5.0,
            relativeTime: '15.01.2023',
            comment: 'Eski tarihli Avrupa formatı yorumu.',
          ),
          PlaceReview(
            id: 'rev_newer_dmy',
            authorName: 'Bu Hafta Yorumcusu',
            authorBadge: 'Ziyaretçi',
            rating: 5.0,
            relativeTime: '3 gün önce',
            comment: '3 gün önce yazılmış taze yorum.',
          ),
          PlaceReview(
            id: 'rev_may_named',
            authorName: 'Mayıs Yorumcusu',
            authorBadge: 'Ziyaretçi',
            rating: 5.0,
            relativeTime: 'Mayıs 2024',
            comment: 'Mayıs ayı yorumu.',
          ),
        ],
      );

      await tester.pumpWidget(buildSheetWidget(placeWithDiverseDates));
      await tester.pumpAndSettle();

      // Under Newest:
      // "3 gün önce" is newest, followed by "Mayıs 2024", followed by "15.01.2023"
      final freshY = tester.getTopLeft(find.text('Bu Hafta Yorumcusu')).dy;
      final mayY = tester.getTopLeft(find.text('Mayıs Yorumcusu')).dy;
      final oldY = tester.getTopLeft(find.text('Geçen Yıl Yorumcusu')).dy;

      expect(freshY, lessThan(mayY));
      expect(mayY, lessThan(oldY));
    });

    testWidgets(
        'R1 Round 2 Adversarial: Clamps 0.0 rating into 1★ bucket so reviews never disappear',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final placeWithZeroStarReview = Place(
        id: 'place_zero_star',
        name: 'Sıfır Puan Mekanı',
        category: 'cafe',
        subCategory: 'Kafe',
        rating: 3.0,
        reviewCount: 2,
        latitude: 40.9850,
        longitude: 29.0270,
        distanceMeters: 100.0,
        address: 'Kadıköy',
        openingHours: '10:00 - 22:00',
        isOpenNow: true,
        priceLevel: 1,
        tags: const [],
        popularItems: const [],
        dataSource: 'OSM',
        starDistribution: const {5: 0.5, 1: 0.5},
        reviews: const [
          PlaceReview(
            id: 'rev_5',
            authorName: 'İyi Yorumcu',
            authorBadge: 'Ziyaretçi',
            rating: 5.0,
            relativeTime: '1 gün önce',
            comment: 'Çok beğendim.',
          ),
          PlaceReview(
            id: 'rev_zero',
            authorName: 'Sıfır Puan Veren',
            authorBadge: 'Ziyaretçi',
            rating: 0.0,
            relativeTime: '2 gün önce',
            comment: 'Hiç puan hak etmiyor.',
          ),
        ],
      );

      await tester.pumpWidget(buildSheetWidget(placeWithZeroStarReview));
      await tester.pumpAndSettle();

      // Tap 1★ filter chip
      await tester.tap(find.byKey(const Key('review_filter_1')));
      await tester.pumpAndSettle();

      // 0.0-star review should be clamped into 1★ category and visible
      expect(find.text('Sıfır Puan Veren'), findsOneWidget);
      expect(find.text('Hiç puan hak etmiyor.'), findsOneWidget);
    });

    testWidgets(
        'R1 Round 3 Adversarial: Correctly parses compound durations ("2 saat 30 dakika önce") and dates with timestamps ("15.08.2024 14:30")',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final placeWithCompoundAndTimestamp = Place(
        id: 'place_compound_test',
        name: 'Zaman Test Mekanı',
        category: 'cafe',
        subCategory: 'Kafe',
        rating: 4.5,
        reviewCount: 4,
        latitude: 40.9850,
        longitude: 29.0270,
        distanceMeters: 100.0,
        address: 'Kadıköy',
        openingHours: '10:00 - 22:00',
        isOpenNow: true,
        priceLevel: 1,
        tags: const [],
        popularItems: const [],
        dataSource: 'OSM',
        starDistribution: const {5: 1.0},
        reviews: const [
          PlaceReview(
            id: 'rev_1h',
            authorName: '1 Saat Yorumcusu',
            authorBadge: 'Ziyaretçi',
            rating: 5.0,
            relativeTime: '1 saat önce',
            comment: '1 saat önceki yorum.',
          ),
          PlaceReview(
            id: 'rev_2h30m',
            authorName: 'Bileşik Süre Yorumcusu',
            authorBadge: 'Ziyaretçi',
            rating: 5.0,
            relativeTime: '2 saat 30 dakika önce',
            comment: '2 saat 30 dakika önceki yorum.',
          ),
          PlaceReview(
            id: 'rev_5h',
            authorName: '5 Saat Yorumcusu',
            authorBadge: 'Ziyaretçi',
            rating: 5.0,
            relativeTime: '5 saat önce',
            comment: '5 saat önceki yorum.',
          ),
          PlaceReview(
            id: 'rev_timestamp',
            authorName: 'Zaman Damgası Yorumcusu',
            authorBadge: 'Ziyaretçi',
            rating: 5.0,
            relativeTime: '15.08.2024 14:30',
            comment: 'Tarih ve saat içeren yorum.',
          ),
        ],
      );

      await tester.pumpWidget(buildSheetWidget(placeWithCompoundAndTimestamp));
      await tester.pumpAndSettle();

      // Under Newest (default):
      // "1 saat önce" (60m) < "2 saat 30 dakika önce" (150m) < "5 saat önce" (300m) < "15.08.2024 14:30"
      final h1Y = tester.getTopLeft(find.text('1 Saat Yorumcusu')).dy;
      final h2_30Y = tester.getTopLeft(find.text('Bileşik Süre Yorumcusu')).dy;
      final h5Y = tester.getTopLeft(find.text('5 Saat Yorumcusu')).dy;
      final tsY = tester.getTopLeft(find.text('Zaman Damgası Yorumcusu')).dy;

      expect(h1Y, lessThan(h2_30Y));
      expect(h2_30Y, lessThan(h5Y));
      expect(h5Y, lessThan(tsY));
    });

    testWidgets(
        'R1 Round 3 Adversarial: Normalizes raw review counts in starDistribution so ProgressIndicators display accurate relative ratios',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // 280 + 50 + 15 + 3 + 2 = 350 total reviews
      final placeWithRawCounts = Place(
        id: 'place_raw_counts',
        name: 'Sayım Dağılım Mekanı',
        category: 'cafe',
        subCategory: 'Kafe',
        rating: 4.7,
        reviewCount: 350,
        latitude: 40.9850,
        longitude: 29.0270,
        distanceMeters: 100.0,
        address: 'Kadıköy',
        openingHours: '10:00 - 22:00',
        isOpenNow: true,
        priceLevel: 1,
        tags: const [],
        popularItems: const [],
        dataSource: 'OSM',
        starDistribution: const {5: 280, 4: 50, 3: 15, 2: 3, 1: 2},
        reviews: const [],
      );

      await tester.pumpWidget(buildSheetWidget(placeWithRawCounts));
      await tester.pumpAndSettle();

      // Find the LinearProgressIndicators for star bars
      final progressIndicators =
          tester.widgetList<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).toList();

      expect(progressIndicators.length, equals(5));

      // 5-star ratio should be 280 / 350 = 0.8
      final fiveStarRatio = progressIndicators[0].value!;
      expect(fiveStarRatio, closeTo(0.8, 0.01));

      // 4-star ratio should be 50 / 350 = 0.1428...
      final fourStarRatio = progressIndicators[1].value!;
      expect(fourStarRatio, closeTo(0.1428, 0.01));

      // 1-star ratio should be 2 / 350 = 0.0057...
      final oneStarRatio = progressIndicators[4].value!;
      expect(oneStarRatio, closeTo(0.0057, 0.01));
    });

    testWidgets(
        'R1 Round 3 Adversarial: Resilient against NaN, infinite ratings, and duplicate or empty review IDs without fatal crash',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final corruptPlace = Place(
        id: 'place_corrupt',
        name: 'Bozuk Veri Mekanı',
        category: 'cafe',
        subCategory: 'Kafe',
        rating: double.nan,
        reviewCount: 3,
        latitude: 40.9850,
        longitude: 29.0270,
        distanceMeters: 100.0,
        address: 'Kadıköy',
        openingHours: '10:00 - 22:00',
        isOpenNow: true,
        priceLevel: 1,
        tags: const [],
        popularItems: const [],
        dataSource: 'OSM',
        starDistribution: const {5: 1.0},
        reviews: const [
          PlaceReview(
            id: '',
            authorName: 'İsimsiz Birinci',
            authorBadge: 'Ziyaretçi',
            rating: double.nan,
            relativeTime: 'bugün',
            comment: 'İlk boş ID yorumu.',
          ),
          PlaceReview(
            id: '',
            authorName: 'İsimsiz İkinci',
            authorBadge: 'Ziyaretçi',
            rating: double.infinity,
            relativeTime: 'dün',
            comment: 'İkinci boş ID yorumu.',
          ),
          PlaceReview(
            id: 'rev_dup',
            authorName: 'Çift ID Birinci',
            authorBadge: 'Ziyaretçi',
            rating: 4.5,
            relativeTime: '1 saat önce',
            comment: 'Çift ID yorumu 1.',
          ),
          PlaceReview(
            id: 'rev_dup',
            authorName: 'Çift ID İkinci',
            authorBadge: 'Ziyaretçi',
            rating: 3.5,
            relativeTime: '2 saat önce',
            comment: 'Çift ID yorumu 2.',
          ),
        ],
      );

      // Must render without throwing NaN exception or Duplicate Key exception
      await tester.pumpWidget(buildSheetWidget(corruptPlace));
      await tester.pumpAndSettle();

      expect(find.text('İsimsiz Birinci'), findsOneWidget);
      expect(find.text('İsimsiz İkinci'), findsOneWidget);
      expect(find.text('Çift ID Birinci'), findsOneWidget);
      expect(find.text('Çift ID İkinci'), findsOneWidget);
    });
  });
}
