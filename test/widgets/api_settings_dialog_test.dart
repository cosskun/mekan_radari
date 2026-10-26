import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekan_radari/controllers/places_controller.dart';
import 'package:mekan_radari/widgets/api_settings_dialog.dart';
import '../fakes/fake_places_repository.dart';
import '../fakes/fake_storage_repository.dart';

void main() {
  group('ApiSettingsDialog Widget Tests', () {
    testWidgets('renders dialog title and informative text', (tester) async {
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => ApiSettingsDialog.show(
                  context: ctx,
                  controller: controller,
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Veri Kaynağı & API Ayarları'), findsOneWidget);
      expect(
        find.textContaining('Şu Anda Aktif: Canlı OpenStreetMap'),
        findsOneWidget,
      );
      expect(find.text('İptal'), findsOneWidget);
      expect(find.text('Kaydet & Yenile'), findsOneWidget);
    });

    testWidgets('saving API key updates controller and storage', (tester) async {
      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: FakeStorageRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => ApiSettingsDialog.show(
                  context: ctx,
                  controller: controller,
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'AIzaSyTestApiKey123');
      await tester.tap(find.text('Kaydet & Yenile'));
      await tester.pumpAndSettle();

      expect(controller.googleApiKey, 'AIzaSyTestApiKey123');
    });

    testWidgets('clearing stored API key clears controller key', (tester) async {
      final fakeStorage = FakeStorageRepository();
      await fakeStorage.saveGoogleApiKey('AIzaSyExistingKey');

      final controller = PlacesController(
        placesRepository: FakePlacesRepository(),
        storageRepository: fakeStorage,
      );
      await controller.init();
      expect(controller.googleApiKey, 'AIzaSyExistingKey');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => ApiSettingsDialog.show(
                  context: ctx,
                  controller: controller,
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Anahtarı Temizle'), findsOneWidget);

      await tester.tap(find.text('Anahtarı Temizle'));
      await tester.pumpAndSettle();

      expect(controller.googleApiKey, isNull);
    });
  });
}
