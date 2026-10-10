import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/services/download_foreground_service.dart';

void main() {
  testWidgets(
    'foreground return re-arms protection only while downloads own it',
    (tester) async {
      final calls = <MethodCall>[];
      const channel = MethodChannel('com.tito.rafeeq_aldarb/download_service');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return true;
      });
      addTearDown(() async {
        await DownloadForegroundServiceBridge.release();
        await DownloadForegroundServiceBridge.release();
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        );
      });
      await DownloadForegroundServiceBridge.acquire(title: 'First download');
      await DownloadForegroundServiceBridge.acquire(title: 'Second download');
      expect(calls.where((c) => c.method == 'start').length, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(calls.where((c) => c.method == 'start').length, 2);
      await DownloadForegroundServiceBridge.release();
      expect(calls.where((c) => c.method == 'stop'), isEmpty);
      await DownloadForegroundServiceBridge.release();
      expect(calls.where((c) => c.method == 'stop').length, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(calls.where((c) => c.method == 'start').length, 2);
    },
  );
}
