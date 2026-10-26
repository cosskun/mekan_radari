import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekan_radari/controllers/places_controller.dart';
import 'package:mekan_radari/models/location_preset.dart';
import 'package:mekan_radari/widgets/location_picker_sheet.dart';
import '../fakes/fake_places_repository.dart';
import '../fakes/fake_storage_repository.dart';

void main() {
  group('LocationPickerSheet Widget Tests', () {
    testWidgets('renders title, GPS button, search input and popular presets', (tester) async {
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationPickerSheet(controller: controller),
          ),
        ),
      );

      expect(find.text('Arama Konumunu Belirle'), findsOneWidget);
      expect(find.text('Cihazımın Gerçek GPS Konumunu Kullan'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Popüler Lezzet & Tatlı Merkezleri'), findsOneWidget);

      // Check presets are rendered
      expect(find.text('Kadıköy - Moda & Çarşı'), findsOneWidget);
      expect(find.text('Beşiktaş - Çarşı & Akaretler'), findsOneWidget);
    });

    testWidgets('tapping a popular preset calls setLocation', (tester) async {
      double? selectedLat;
      double? selectedLon;

      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationPickerSheet(
              controller: controller,
              onLocationSelected: (lat, lon) {
                selectedLat = lat;
                selectedLon = lon;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Beşiktaş - Çarşı & Akaretler'));
      await tester.pumpAndSettle();

      expect(controller.centerLat, 41.0430);
      expect(controller.centerLon, 29.0053);
      expect(controller.locationLabel, 'Beşiktaş - Çarşı & Akaretler');
      expect(selectedLat, 41.0430);
      expect(selectedLon, 29.0053);
    });

    testWidgets('address search displays results and selecting one sets location', (tester) async {
      const searchedPreset = LocationPreset(
        name: 'Üsküdar Sahil',
        subtitle: 'İstanbul',
        latitude: 41.0260,
        longitude: 29.0150,
      );

      final fakeRepo = FakePlacesRepository(presetsToReturn: [searchedPreset]);
      final controller = PlacesController(
        placesRepository: fakeRepo,
        storageRepository: FakeStorageRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationPickerSheet(controller: controller),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Üsküdar');
      // Wait for debounce timer (500ms)
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.text('Arama Sonuçları (Canlı Harita)'), findsOneWidget);
      expect(find.text('Üsküdar Sahil'), findsOneWidget);

      await tester.tap(find.text('Üsküdar Sahil'));
      await tester.pumpAndSettle();

      expect(controller.locationLabel, 'Üsküdar Sahil');
      expect(controller.centerLat, 41.0260);
      expect(controller.centerLon, 29.0150);
    });
  });
}
