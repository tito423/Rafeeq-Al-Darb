import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/app/rafeeq_app.dart';
import 'package:rafeeq_app/core/models/adhan_mode.dart';
import 'package:rafeeq_app/core/models/adhan_option.dart';
import 'package:rafeeq_app/core/services/adhan_native.dart';
import 'package:rafeeq_app/features/adhan/data/adhan_catalog_provider.dart';
import 'package:rafeeq_app/features/home/presentation/widgets/prayer_slides.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _option = AdhanOption(
  id: 'audit',
  name: 'Audit recording',
  isCustom: false,
  rawResource: 'azan1',
  assetPath: 'assets/audio/adhan/azan1.mp3',
);

class _Catalog extends AdhanCatalogNotifier {
  @override
  Future<List<AdhanOption>> build() async => const [_option];
}

class _Translations extends AssetLoader {
  const _Translations();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => {};
}

enum _Case {
  lateStart,
  lateReply,
  newerPreview,
  realFiring,
  cancelPending,
  failedStart,
  failedAfterClose,
  stopOwn,
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  setUpAll(EasyLocalization.ensureInitialized);
  const channel = MethodChannel('com.tito.rafeeq_aldarb/adhan_player');
  for (final scenario in _Case.values) {
    testWidgets(
      'prayer preview ${scenario.name} preserves playback ownership',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final response = Completer<bool>();
        var playing = false;
        var firing = false;
        String? owner;
        var previews = 0;
        var globalStops = 0;
        var ownedStops = 0;
        final lateStart =
            scenario == _Case.lateStart || scenario == _Case.cancelPending;
        void start(String? requestedOwner) {
          playing = true;
          owner = requestedOwner;
        }

        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) async {
            final args = (call.arguments as Map?)?.cast<Object?, Object?>();
            if (call.method == 'preview') {
              previews++;
              final requestedOwner = args?['previewOwner'] as String?;
              if (previews > 1) {
                start(requestedOwner);
                return true;
              }
              if (!lateStart) start(requestedOwner);
              final result = await response.future;
              if (lateStart && result) start(requestedOwner);
              if (!result) {
                playing = false;
                owner = null;
              }
              return result;
            }
            if (call.method == 'stopPreview') {
              if (!firing && owner != null && owner == args?['previewOwner']) {
                ownedStops++;
                playing = false;
                owner = null;
                return true;
              }
              return false;
            }
            if (call.method == 'stop') {
              globalStops++;
              playing = false;
              owner = null;
            }
            if (call.method == 'state') {
              return {
                'playing': playing,
                'firing': firing,
                'previewOwner': owner,
              };
            }
            return null;
          },
        );
        try {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                sharedPrefsProvider.overrideWithValue(prefs),
                adhanCatalogProvider.overrideWith(_Catalog.new),
              ],
              child: EasyLocalization(
                supportedLocales: const [Locale('en')],
                startLocale: const Locale('en'),
                saveLocale: false,
                path: '.',
                assetLoader: const _Translations(),
                child: Builder(
                  builder: (context) => MaterialApp(
                    localizationsDelegates: context.localizationDelegates,
                    supportedLocales: context.supportedLocales,
                    locale: context.locale,
                    home: const Scaffold(
                      body: SingleChildScrollView(
                        child: PrayerSlideDetails(prayerKey: 'dhuhr'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byIcon(Icons.play_circle_outline));
          await tester.pump();
          expect(previews, 1);
          if (scenario == _Case.newerPreview ||
              scenario == _Case.realFiring ||
              scenario == _Case.stopOwn) {
            response.complete(true);
            await tester.pump();
            await tester.pump();
            expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);
            if (scenario == _Case.newerPreview) {
              final started = await AdhanNative.preview(
                AdhanNative.specFor(
                  prayerKey: 'dhuhr',
                  prayerLabel: 'Dhuhr',
                  mode: AdhanMode.audio,
                  option: _option,
                ),
              );
              expect(started, isTrue);
            } else if (scenario == _Case.realFiring) {
              firing = true;
              owner = null; // A real firing replaced the old preview.
            } else {
              await tester.tap(find.byIcon(Icons.stop_circle_outlined));
              await tester.pump();
            }
            await tester.pumpWidget(const SizedBox());
          } else if (scenario == _Case.failedStart) {
            response.complete(false);
            await tester.pump();
            expect(find.byType(SnackBar), findsOneWidget);
            await tester.pumpWidget(const SizedBox());
          } else if (scenario == _Case.cancelPending) {
            await tester.tap(find.byTooltip('prayer.test'));
            await tester.pump();
            response.complete(true);
            await tester.pump();
            await tester.pump();
            expect(
              previews,
              1,
              reason: 'Tapping again cancels the pending start',
            );
            expect(find.byType(SnackBar), findsNothing);
            await tester.pumpWidget(const SizedBox());
          } else {
            await tester.pumpWidget(const SizedBox());
            response.complete(scenario != _Case.failedAfterClose);
          }
          await tester.pump();
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(
            playing,
            scenario == _Case.newerPreview || scenario == _Case.realFiring,
          );
          expect(
            globalStops,
            0,
            reason: 'Closing a card never issues global Stop',
          );
          if (scenario == _Case.stopOwn || scenario == _Case.lateReply) {
            expect(ownedStops, 1);
          }
        } finally {
          if (!response.isCompleted) response.complete(false);
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
          await AdhanNative.stop();
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          );
        }
      },
    );
  }
}
