import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rafeeq_app/features/caravan/data/caravan_world.dart';
import 'package:rafeeq_app/features/caravan/presentation/caravan_map.dart';
import 'package:rafeeq_app/features/caravan/presentation/caravan_painter.dart';
import 'package:rafeeq_app/features/caravan/presentation/caravan_screen.dart';
import 'package:rafeeq_app/features/quiz/data/history_quiz.dart';

class _Translations extends AssetLoader {
  const _Translations();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('assets/translations/en.json').readAsStringSync())
          as Map<String, dynamic>;
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  setUpAll(EasyLocalization.ensureInitialized);
  testWidgets('starting before actual bank loads permanently omits gate question', (tester) async {
    final support = Directory.systemTemp.createTempSync('rafeeq_caravan_audit_');
    addTearDown(() => support.deleteSync(recursive: true));
    final heldBank = Completer<ByteData?>();
    var requested = false;
    final messenger = binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => support.path);
    messenger.setMockMessageHandler('flutter/assets', (message) async {
      final key = utf8.decode(message!.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes));
      if (key == HistoryQuiz.asset) {
        requested = true;
        return heldBank.future;
      }
      final file = File(key);
      return file.existsSync() ? ByteData.sublistView(file.readAsBytesSync()) : null;
    });
    addTearDown(() {
      messenger.setMockMessageHandler('flutter/assets', null);
      messenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), null);
    });
    await tester.pumpWidget(EasyLocalization(
      supportedLocales: const [Locale('en')], startLocale: const Locale('en'),
      path: '.', assetLoader: const _Translations(),
      child: Builder(builder: (context) => MaterialApp(
        locale: context.locale, supportedLocales: context.supportedLocales,
        localizationsDelegates: context.localizationDelegates,
        home: const CaravanScreen(),
      )),
    ));
    // The map's pulsing station intentionally never settles.
    for (var frame = 0; frame < 15; frame++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(requested, isTrue);
    expect(heldBank.isCompleted, isFalse);
    // This is the actual station callback, available before bank completion.
    tester.widget<CaravanMap>(find.byType(CaravanMap)).onPlay(CaravanLeg.first);
    await tester.pump();
    final painter = tester.widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((w) => w.painter).whereType<CaravanPainter>().single;
    final world = painter.w;
    List<QuizQuestion>? loadedBank;
    HistoryQuiz.all().then((value) => loadedBank = value);
    heldBank.complete(ByteData.sublistView(File(HistoryQuiz.asset).readAsBytesSync()));
    for (var attempt = 0; attempt < 100 && loadedBank == null; attempt++) {
      await tester.pump(const Duration(milliseconds: 10));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
    expect(loadedBank, isNotNull);
    final bank = loadedBank!;
    expect(bank.any((q) => CaravanLeg.first.gateIds.contains(q.id)), isTrue);
    await tester.pump();
    // Advance real ticker in bounded frames; do not modify the game state.
    for (var frame = 0; frame < 900 && world.phase != CaravanPhase.atGate; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(world.phase, CaravanPhase.atGate);
    final firstQuestion = bank.firstWhere((q) => CaravanLeg.first.gateIds.contains(q.id)).localized('en');
    expect(find.text(firstQuestion.question), findsNothing);
    expect(find.byWidgetPredicate((w) => w is FilledButton), findsNothing);
    for (var frame = 0; frame < 40; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(world.phase, CaravanPhase.atGate);
    print('AUDIT_CARAVAN_BANK: started with bank pending; actual500-question '
      'asset subsequently loaded with matching first-leg IDs; real ticker '
      'reached atGate; no question/answer controls; remains atGate after2s.');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
