import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekan_radari/controllers/places_controller.dart';
import 'package:mekan_radari/models/place_model.dart';
import 'package:mekan_radari/screens/home_screen.dart';
import 'package:mekan_radari/widgets/api_settings_dialog.dart';
import 'package:mekan_radari/widgets/empty_venues_view.dart';
import 'package:mekan_radari/widgets/interactive_venue_map.dart';
import 'package:mekan_radari/widgets/location_picker_sheet.dart';
import 'package:mekan_radari/widgets/radius_slider_bar.dart';
import 'package:mekan_radari/widgets/search_view_toggle_bar.dart';
import 'package:mekan_radari/widgets/venue_card.dart';

import '../fakes/fake_places_repository.dart';
import '../fakes/fake_storage_repository.dart';

Place _createStressPlace({
  String id = 'stress-1',
  String name = 'Moda Çikolatacısı & Waffle',
  String category = 'Tatlı & Pastane',
  String subCategory = 'Çikolata & Tatlı',
  double rating = 4.8,
  int reviewCount = 350,
  double lat = 40.9865,
  double lon = 29.0268,
  double distance = 150.0,
  String address = 'Caferağa Mah. Moda Cad. No:12 Kadıköy',
  List<String> popularItems = const ['Sıcak Çikolata', 'Antep Fıstıklı Waffle'],
  List<PlaceReview> reviews = const [
    PlaceReview(
      id: 'rev-1',
      authorName: 'Ahmet Yılmaz',
      authorBadge: 'Yerel Rehber',
      rating: 5.0,
      comment: 'Harika bir mekan, tatlılar çok taze ve personel ilgili.',
      relativeTime: '2 gün önce',
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
    latitude: lat,
    longitude: lon,
    distanceMeters: distance,
    address: address,
    openingHours: '09:00 - 23:00',
    isOpenNow: true,
    priceLevel: 2,
    tags: const ['tatlı', 'çikolata', 'kahve'],
    popularItems: popularItems,
    reviews: reviews,
    starDistribution: const {5: 280, 4: 50, 3: 15, 2: 3, 1: 2},
    dataSource: 'overpass',
  );
}

class _DelayedPlacesRepository extends FakePlacesRepository {
  final Completer<List<Place>> completer;

  _DelayedPlacesRepository(this.completer);

  @override
  Future<List<Place>> fetchNearbyPlaces({
    required double lat,
    required double lon,
    required double radiusMeters,
    String? googleApiKey,
    String? searchQuery,
  }) {
    return completer.future;
  }
}

void main() {
  group('1. Screen Constraints & Rapid Orientation Stress Tests', () {
    testWidgets(
      'HomeScreen renders on desktop/tablet screen without layout exceptions',
      (tester) async {
        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final controller = PlacesController(
          placesRepository: FakePlacesRepository(
            placesToReturn: [_createStressPlace()],
          ),
          storageRepository: FakeStorageRepository(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(controller: controller),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(HomeScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'HomeScreen survives rapid orientation changes between portrait and landscape',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final controller = PlacesController(
          placesRepository: FakePlacesRepository(
            placesToReturn: [_createStressPlace()],
          ),
          storageRepository: FakeStorageRepository(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(controller: controller),
          ),
        );
        await tester.pumpAndSettle();

        // Rotate to landscape
        tester.view.physicalSize = const Size(1000, 800);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Rotate back to portrait
        tester.view.physicalSize = const Size(800, 1000);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Rotate to large tablet
        tester.view.physicalSize = const Size(900, 1200);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Rotate to wide landscape (1280x720)
        tester.view.physicalSize = const Size(1280, 720);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'RadiusSliderBar handles constrained width with horizontal scroll support',
      (tester) async {
        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final controller = PlacesController(
          placesRepository: FakePlacesRepository(),
          storageRepository: FakeStorageRepository(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: RadiusSliderBar(controller: controller),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(RadiusSliderBar), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'VenueCard renders on mobile viewport without RenderFlex overflow',
      (tester) async {
        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final place = _createStressPlace();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  VenueCard(
                    place: place,
                    isFavorite: false,
                    onToggleFavorite: () {},
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(VenueCard), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'EmptyVenuesView renders on 320x480 screen without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 480);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final controller = PlacesController(
          placesRepository: FakePlacesRepository(placesToReturn: const []),
          storageRepository: FakeStorageRepository(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EmptyVenuesView(controller: controller),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(EmptyVenuesView), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'InteractiveVenueMap renders on wide landscape (1280x720) and small screen (320x480)',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 720);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final controller = PlacesController(
          placesRepository: FakePlacesRepository(
            placesToReturn: [_createStressPlace()],
          ),
          storageRepository: FakeStorageRepository(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InteractiveVenueMap(
                controller: controller,
                tileUrlTemplate: '',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(InteractiveVenueMap), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Switch to small screen
        tester.view.physicalSize = const Size(320, 480);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('2. Lifecycle, Mount/Unmount & Listener Hygiene Stress Tests', () {
    testWidgets(
      'Repeatedly mount and unmount HomeScreen 15 times with controller state mutations',
      (tester) async {
        final controller = PlacesController(
          placesRepository: FakePlacesRepository(
            placesToReturn: [_createStressPlace()],
          ),
          storageRepository: FakeStorageRepository(),
        );

        for (var i = 0; i < 15; i++) {
          // Mount
          await tester.pumpWidget(
            MaterialApp(
              home: HomeScreen(controller: controller),
            ),
          );
          await tester.pump();

          // Mutate controller state while mounted
          controller.setRadiusMeters(100.0 + (i * 50));
          controller.setSearchQuery('Döngü $i');
          await tester.pump();

          // Unmount
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(body: SizedBox()),
            ),
          );
          await tester.pump();

          // Mutate controller state while unmounted — must not trigger disposed listener errors!
          controller.setMinRating(4.0 + (i % 5) * 0.2);
          controller.setSearchQuery('Unmounted $i');
          controller.toggleFavoritesOnly();
        }

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'InteractiveVenueMap cleanly detaches controller listener upon unmount',
      (tester) async {
        final controller = PlacesController(
          placesRepository: FakePlacesRepository(
            placesToReturn: [_createStressPlace()],
          ),
          storageRepository: FakeStorageRepository(),
        );

        // Mount InteractiveVenueMap
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InteractiveVenueMap(
                controller: controller,
                tileUrlTemplate: '',
              ),
            ),
          ),
        );
        await tester.pump();

        // Mutate coordinates while mounted
        await controller.setLocation(
          lat: 41.0082,
          lon: 28.9784,
          label: 'Sultanahmet',
        );
        await tester.pump();

        // Unmount InteractiveVenueMap
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: SizedBox()),
          ),
        );
        await tester.pump();

        // Mutate coordinates while unmounted
        await controller.setLocation(
          lat: 40.9862,
          lon: 29.0264,
          label: 'Kadıköy',
        );
        controller.setRadiusMeters(1500.0);
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'SearchViewToggleBar handles rapid rebuilds and external controller swap',
      (tester) async {
        final controller = PlacesController(
          placesRepository: FakePlacesRepository(),
          storageRepository: FakeStorageRepository(),
        );
        final externalTextController = TextEditingController(text: 'Initial');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchViewToggleBar(
                controller: controller,
                searchController: externalTextController,
              ),
            ),
          ),
        );
        await tester.pump();

        // Rebuild with same controller
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchViewToggleBar(
                controller: controller,
                searchController: externalTextController,
              ),
            ),
          ),
        );
        await tester.pump();

        // Rebuild with internal controller (null searchController)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchViewToggleBar(
                controller: controller,
                searchController: null,
              ),
            ),
          ),
        );
        await tester.pump();

        // Unmount
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: SizedBox()),
          ),
        );
        await tester.pump();

        externalTextController.dispose();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'LocationPickerSheet and ApiSettingsDialog show and dismiss without memory leaks',
      (tester) async {
        final controller = PlacesController(
          placesRepository: FakePlacesRepository(),
          storageRepository: FakeStorageRepository(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Column(
                  children: [
                    ElevatedButton(
                      key: const Key('open_location_btn'),
                      onPressed: () => LocationPickerSheet.show(
                        context: context,
                        controller: controller,
                      ),
                      child: const Text('Konum Seç'),
                    ),
                    ElevatedButton(
                      key: const Key('open_api_btn'),
                      onPressed: () => ApiSettingsDialog.show(
                        context: context,
                        controller: controller,
                      ),
                      child: const Text('API Ayarları'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open LocationPickerSheet
        await tester.tap(find.byKey(const Key('open_location_btn')));
        await tester.pumpAndSettle();
        expect(find.byType(LocationPickerSheet), findsOneWidget);

        // Dismiss LocationPickerSheet
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        expect(find.byType(LocationPickerSheet), findsNothing);

        // Open ApiSettingsDialog
        await tester.tap(find.byKey(const Key('open_api_btn')));
        await tester.pumpAndSettle();
        expect(find.byType(ApiSettingsDialog), findsOneWidget);

        // Dismiss ApiSettingsDialog
        await tester.tap(find.text('İptal'));
        await tester.pumpAndSettle();
        expect(find.byType(ApiSettingsDialog), findsNothing);

        expect(tester.takeException(), isNull);
      },
    );
  });

  group('3. Controller States & Screen Reconstitution Stress Tests', () {
    testWidgets(
      'HomeScreen renders custom loading indicator and statusMessage when isLoading is true',
      (tester) async {
        final completer = Completer<List<Place>>();
        final delayedRepo = _DelayedPlacesRepository(completer);
        final controller = PlacesController(
          placesRepository: delayedRepo,
          storageRepository: FakeStorageRepository(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(controller: controller),
          ),
        );
        // Initial pump triggers loadPlaces in initState
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsWidgets);
        expect(
          find.text('Çevredeki gerçek mekanlar taranıyor...'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        // Complete the pending load to prevent hung async tasks
        completer.complete([_createStressPlace()]);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'HomeScreen transitions gracefully through populated -> loading -> empty -> populated',
      (tester) async {
        final fakeRepo = FakePlacesRepository(
          placesToReturn: [_createStressPlace()],
        );
        final controller = PlacesController(
          placesRepository: fakeRepo,
          storageRepository: FakeStorageRepository(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(controller: controller),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Populated state
        expect(find.byType(VenueCard), findsOneWidget);

        // 2. Filter to empty state
        controller.setSearchQuery('NonExistentPlaceQuery123456');
        await tester.pumpAndSettle();
        expect(find.byType(EmptyVenuesView), findsOneWidget);

        // 3. Clear search to recover populated state
        controller.setSearchQuery('');
        await tester.pumpAndSettle();
        expect(find.byType(VenueCard), findsOneWidget);

        // 4. Set filter that isolates closest outside place (coords slightly outside 500m: ~610m)
        fakeRepo.placesToReturn = [
          _createStressPlace(
            id: 'far-1',
            name: 'Uzak Baklavacı',
            lat: 40.9920,
            lon: 29.0268,
          ),
        ];
        controller.setRadiusMeters(500.0);
        await controller.loadPlaces();
        await tester.pumpAndSettle();

        expect(find.byType(EmptyVenuesView), findsOneWidget);
        expect(find.textContaining('Uzak Baklavacı'), findsOneWidget);

        // Tap adaptive expansion button
        await tester.tap(find.textContaining('Yap ve Göster'));
        await tester.pumpAndSettle();

        expect(find.byType(VenueCard), findsOneWidget);
        expect(find.text('Uzak Baklavacı'), findsOneWidget);

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'HomeScreen handles large list of 50 venues with smooth scrolling',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final venues = List.generate(
          50,
          (i) => _createStressPlace(
            id: 'place-$i',
            name: 'Mekan #$i - Kadıköy Lezzet Durağı',
            distance: 100.0 + (i * 20),
          ),
        );

        final controller = PlacesController(
          placesRepository: FakePlacesRepository(placesToReturn: venues),
          storageRepository: FakeStorageRepository(),
          initialRadiusMeters: 2000.0,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(controller: controller),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(VenueCard), findsWidgets);
        expect(find.text('50 mekan bulundu'), findsOneWidget);

        // Scroll down 5 times
        for (var s = 0; s < 5; s++) {
          await tester.drag(
            find.byWidgetPredicate(
              (w) => w is ListView && w.scrollDirection == Axis.vertical,
            ),
            const Offset(0, -300),
          );
          await tester.pumpAndSettle();
        }

        expect(tester.takeException(), isNull);
      },
    );
  });

  group('4. Long Turkish Strings & Special Character Stress Tests', () {
    testWidgets(
      'VenueCard renders extremely long Turkish venue name, address, and special characters',
      (tester) async {
        const extremeName =
            'İstanbul Kadıköy Tarihi Meşhur Hakiki Antep Baklavacısı & Dondurma Çeşitleri Şubesi (1881\'den Beri) - ĞÜŞİÖÇ ğüşıöç';
        const extremeAddress =
            'Caferağa Mahallesi Şair Latifi Sokak No: 48/A Daire: 2 (Moda İlkokulu Karşısı, Çeşme Yanı) Kadıköy / İSTANBUL';
        const extremeSubCategory = 'Özel Taş Fırın Baklava';

        final place = _createStressPlace(
          name: extremeName,
          address: extremeAddress,
          subCategory: extremeSubCategory,
          popularItems: const [
            'Havuç Dilim Baklava & Maraş Dondurması',
            'Fıstıklı Şöbiyet (Özel Şerbetli)',
            'Cevizli Ev Baklavası (Organik Tereyağlı)',
          ],
          reviews: const [
            PlaceReview(
              id: 'rev-2',
              authorName: 'Ömer Seyfettin Çetinkaya',
              authorBadge: 'Gezgin Gurme',
              rating: 5.0,
              comment:
                  'Harika bir lezzet şöleni! Fıstıklar yemyeşil, şerbeti tam kıvamında ağır değil. "Moda\'da tek geçerim" dedikleri kadar varmış ✨🍮🍰',
              relativeTime: '3 gün önce',
            ),
          ],
        );

        tester.view.physicalSize = const Size(800, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  VenueCard(
                    place: place,
                    isFavorite: true,
                    onToggleFavorite: () {},
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(extremeName), findsOneWidget);
        expect(find.text(extremeAddress), findsOneWidget);
        expect(find.text(extremeSubCategory), findsOneWidget);
        expect(find.textContaining('Harika bir lezzet şöleni!'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'HomeScreen searches and filters with Turkish special characters and uppercase İ / I',
      (tester) async {
        final places = [
          _createStressPlace(id: 't-1', name: 'IHLAMUR KAFE', subCategory: 'Kahve'),
          _createStressPlace(id: 't-2', name: 'İNCİR TATLICISI', subCategory: 'Tatlı'),
          _createStressPlace(id: 't-3', name: 'ŞÖLEN DONDURMA', subCategory: 'Dondurma'),
        ];

        final controller = PlacesController(
          placesRepository: FakePlacesRepository(placesToReturn: places),
          storageRepository: FakeStorageRepository(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(controller: controller),
          ),
        );
        await tester.pumpAndSettle();

        // Search with lowercase 'ı'
        controller.setSearchQuery('ıhlamur');
        await tester.pumpAndSettle();
        expect(find.text('IHLAMUR KAFE'), findsOneWidget);
        expect(find.text('İNCİR TATLICISI'), findsNothing);

        // Search with lowercase 'i'
        controller.setSearchQuery('incir');
        await tester.pumpAndSettle();
        expect(find.text('İNCİR TATLICISI'), findsOneWidget);
        expect(find.text('IHLAMUR KAFE'), findsNothing);

        // Search with uppercase 'Ş' and 'Ö'
        controller.setSearchQuery('şölen');
        await tester.pumpAndSettle();
        expect(find.text('ŞÖLEN DONDURMA'), findsOneWidget);

        expect(tester.takeException(), isNull);
      },
    );
  });
}
