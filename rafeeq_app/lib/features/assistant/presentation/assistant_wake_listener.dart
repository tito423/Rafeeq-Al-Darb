import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/navigation.dart';
import '../../shamela/data/shamela_library.dart';
import '../data/assistant_intent.dart';
import '../data/assistant_settings.dart';
import '../data/rafeeq_diag.dart';
import '../data/rafeeq_ear.dart';
import '../data/rafeeq_voice_pack.dart';
import 'assistant_describe.dart';
import 'assistant_sheet.dart';

const _channel = MethodChannel('com.tito.rafeeq_aldarb/assistant');

/// «يا رفيق», heard wherever the reader is, while he has it switched on and
/// the voice pack is on the phone.
///
/// There is no button: «الأفضل إنه يختفي، مايظهرش غير لما أنده يا رفيق»
/// (owner, 2026-09-27). Said with a command («يا رفيق شغل الكهف»), the
/// command runs at once; said alone, the sheet opens and takes the next
/// sentence.
///
/// Never in anyone's way («خد بالك من الكونفلكت … ولما تيجي مكالمة … في كل
/// الحالات»): it takes no audio focus, and the microphone is CLOSED while a
/// call rings or runs, while any sound plays (this app's recitation or adhan,
/// another app's music), and while any other app - or the tasmee - records;
/// checked every second, and it opens again when all is quiet. In the
/// background a foreground service with a notification keeps it alive; its
/// «إيقاف» switches the assistant off.
class AssistantWakeListener extends ConsumerStatefulWidget {
  const AssistantWakeListener({super.key});

  @override
  ConsumerState<AssistantWakeListener> createState() =>
      _AssistantWakeListenerState();
}

class _AssistantWakeListenerState extends ConsumerState<AssistantWakeListener>
    with WidgetsBindingObserver {
  final _ear = RafeeqEar.instance;
  Timer? _tick;
  StreamSubscription<String>? _heard;
  bool _foreground = true;
  bool _serviceOn = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    RafeeqVoicePack.instance.check();
    ShamelaLibrary.instance.addListener(_booksChanged);
    // One phrase at a time: «… سورة البقرة آية» and the number said in the
    // next breath arrive milliseconds apart, and the number must see what the
    // first phrase armed (emulator, 2026-09-30).
    _heard = _ear.heard.listen((t) => _queue = _queue.then((_) => _onHeard(t)));
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ShamelaLibrary.instance.removeListener(_booksChanged);
    _tick?.cancel();
    _heard?.cancel();
    super.dispose();
  }

  void _booksChanged() => ref.invalidate(assistantParserProvider);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _check();
  }

  Future<void> _check() async {
    if (_busy || !mounted) return;
    _busy = true;
    try {
      final on = ref.read(assistantEnabledProvider) &&
          RafeeqVoicePack.instance.installed.value == true &&
          ref.read(assistantShellUpProvider);
      // «إيقاف» pressed in the notification.
      if (on && _serviceOn && await _channel.invokeMethod<bool>('stoppedByUser') == true) {
        _serviceOn = false;
        await ref.read(assistantEnabledProvider.notifier).set(false);
        await _ear.stop();
        return;
      }
      final diag = RafeeqDiag.instance.mic;
      if (!on) {
        diag.value = RafeeqVoicePack.instance.installed.value != true
            ? RafeeqMicState.noPack
            : RafeeqMicState.off;
        if (_ear.listening.value) await _ear.stop();
        if (_serviceOn) {
          _serviceOn = false;
          await _channel.invokeMethod('stopService');
        }
        return;
      }
      // Started only while the app is on screen: Android refuses a
      // microphone service started from the background.
      if (!_serviceOn && _foreground) {
        _serviceOn = true;
        await _channel.invokeMethod('startService', {
          'title': 'assistant.name'.tr(),
          'text': 'assistant.notif_text'.tr(),
          'stop': 'assistant.notif_stop'.tr(),
          'channel': 'assistant.setting_title'.tr(),
        });
      }
      final busy = await _channel.invokeMapMethod<String, dynamic>('busy') ?? {};
      final ours = _ear.listening.value ? 1 : 0;
      // Our own Bluetooth call route (MODE_IN_COMMUNICATION = 3) is not a
      // call; ringing and a real call still are.
      final call = busy['call'] == true &&
          !(_ear.viaBluetooth && busy['mode'] == 3);
      // The headset setting changed, or a headset came or went: reopen the
      // microphone on the right source (checked every 5 s).
      _ear.wantBluetooth = ref.read(assistantBluetoothMicProvider);
      if (_ear.listening.value && ++_btTick % 5 == 0 &&
          (_ear.wantBluetooth ? await _ear.bluetoothPresent() : false) !=
              _ear.viaBluetooth) {
        await _ear.stop();
      }
      final others = ((busy['recording'] as int?) ?? 0) > ours;
      final allowed = await Permission.microphone.isGranted;
      final quiet = !call && busy['playing'] != true && !others &&
          (_foreground || _serviceOn) && allowed;
      diag.value = quiet
          ? RafeeqMicState.listening
          : !allowed
          ? RafeeqMicState.noPermission
          : call
          ? RafeeqMicState.call
          : busy['playing'] == true
          ? RafeeqMicState.soundPlaying
          : others
          ? RafeeqMicState.otherRecording
          : RafeeqMicState.backgroundNoService;
      if (quiet && !_ear.listening.value) {
        await _ear.start();
      } else if (!quiet && _ear.listening.value) {
        await _ear.stop();
      }
      if (_ear.listening.value) await _testClip();
    } catch (_) {
      // A failed check is retried on the next tick.
    } finally {
      _busy = false;
    }
  }

  int _btTick = 0;
  DateTime? _fedAt;
  Future<void> _testClip() async => _fedAt = await _ear.feedTestClip() ?? _fedAt;

  /// After a bare background call: the next sentence is the command.
  DateTime? _awaitUntil;
  final _ayahFollow = AyahFollowUp();
  Future<void> _queue = Future.value();

  Future<bool> _overlayCan() async =>
      (await _channel.invokeMethod<bool>('overlayCan')) == true;

  Future<void> _overlay(String text, {int seconds = 4}) =>
      _channel.invokeMethod<void>('overlayShow', {
        'text': text, 'seconds': seconds,
        'rtl': const {'ar', 'ur'}.contains(assistantLanguage()),
      });

  Future<void> _onHeard(String text) async {
    if (_fedAt != null) {
      debugPrint('rafeeq heard in ${DateTime.now().difference(_fedAt!).inMilliseconds} ms: $text');
      _fedAt = null;
    }
    RafeeqDiag.instance.sentence(text);
    if (assistantSheetOpen.value || !mounted) return; // the sheet takes it
    final container = ProviderScope.containerOf(context, listen: false);
    final followUp = _ayahFollow.take(afterWakeWord(text) ?? text);
    if (followUp != null) return _act(container, followUp);
    final waiting = _awaitUntil != null && DateTime.now().isBefore(_awaitUntil!);
    var rest = afterWakeWord(text);
    if (rest == null && waiting) rest = text;
    if (rest == null) return;
    _awaitUntil = null;
    // Over another app: «رفيق» shows its own small card (AssistantOverlay.kt).
    final overlay = !_foreground && await _overlayCan();
    if (rest.isEmpty && overlay) {
      _awaitUntil = DateTime.now().add(const Duration(seconds: 10));
      await _overlay('assistant.listening'.tr(), seconds: 10);
      return;
    }
    if (rest.isNotEmpty) {
      final parser = await ref.read(assistantParserProvider.future);
      final intent = parser.parse(rest);
      debugPrint('rafeeq intent: "$rest" -> $intent');
      RafeeqDiag.instance.understood('$intent');
      if (intent is! UnknownIntent) {
        _ayahFollow.arm(intent);
        await _act(container, intent, overlay: overlay);
        return;
      }
      if (overlay) {
        await _overlay(
            '${'assistant.heard'.tr(args: [rest])}\n${'assistant.not_understood'.tr()}',
            seconds: 5);
        return;
      }
    }
    if (!_foreground) await _channel.invokeMethod('toFront');
    await showAssistantSheet(heard: rest.isEmpty ? null : text);
  }

  Future<void> _act(ProviderContainer container, AssistantIntent intent,
      {bool overlay = false}) async {
    final reply = await describeIntent(container, intent);
    if (overlay) await _overlay(reply, seconds: 3);
    if (!_foreground && intent is! PlaySurahIntent &&
        intent is! SetThemeIntent && intent is! ToggleOptionIntent) {
      await _channel.invokeMethod('toFront');
    }
    rootScaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
        content: Text(reply), duration: const Duration(seconds: 2)));
    await runIntent(container, intent);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(assistantEnabledProvider, (_, _) => _check());
    ref.listen<bool>(assistantShellUpProvider, (_, _) => _check());
    ref.listen<bool>(assistantBluetoothMicProvider, (_, _) async {
      if (_ear.listening.value) await _ear.stop();
      await _check();
    });
    return const SizedBox.shrink();
  }
}
