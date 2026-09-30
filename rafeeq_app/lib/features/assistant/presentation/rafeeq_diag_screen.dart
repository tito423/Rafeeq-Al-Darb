import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/adhan_uri_bridge.dart';
import '../data/rafeeq_diag.dart';
import '../data/rafeeq_ear.dart';

/// «تشخيص رفيق»: what the phone is doing to the listening, and the last
/// thing heard - so a failure on a real phone can be read off the screen
/// (and its audio sent) instead of guessed (owner's Honor, 2026-09-30).
class RafeeqDiagScreen extends StatefulWidget {
  const RafeeqDiagScreen({super.key});

  @override
  State<RafeeqDiagScreen> createState() => _RafeeqDiagScreenState();
}

class _RafeeqDiagScreenState extends State<RafeeqDiagScreen>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('com.tito.rafeeq_aldarb/assistant');
  final _diag = RafeeqDiag.instance;
  Map<String, dynamic> _phone = const {};
  bool? _overlay;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _read();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _read());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    super.dispose();
  }

  // Back from a system settings screen: read everything again at once.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _read();
  }

  Future<void> _read() async {
    try {
      final phone = await _channel.invokeMapMethod<String, dynamic>('diag');
      final overlay = await _channel.invokeMethod<bool>('overlayCan');
      if (!mounted) return;
      setState(() {
        _phone = phone ?? const {};
        _overlay = overlay;
      });
    } catch (_) {
      // Not Android: the rows stay empty.
    }
  }

  Future<void> _share() async {
    final dir = await getTemporaryDirectory();
    final f = await _diag.writeLastClip('${dir.path}/rafeeq_last.wav');
    if (f == null) return;
    final h = _diag.heard.value;
    await SharePlus.instance.share(ShareParams(
      files: [XFile(f.path, mimeType: 'audio/wav')],
      text: '${'assistant.diag_title'.tr()}: ${h?.text ?? ''}',
    ));
  }

  String _yesNo(bool? v) => v == null
      ? '—'
      : v
      ? 'assistant.diag_yes'.tr()
      : 'assistant.diag_no'.tr();

  String _mic(RafeeqMicState s) => switch (s) {
        RafeeqMicState.listening => 'assistant.diag_mic_listening'.tr(),
        RafeeqMicState.off => 'assistant.diag_mic_off'.tr(),
        RafeeqMicState.noPack => 'assistant.diag_mic_no_pack'.tr(),
        RafeeqMicState.noPermission => 'assistant.diag_mic_no_permission'.tr(),
        RafeeqMicState.call => 'assistant.diag_mic_call'.tr(),
        RafeeqMicState.soundPlaying => 'assistant.diag_mic_sound'.tr(),
        RafeeqMicState.otherRecording => 'assistant.diag_mic_other'.tr(),
        RafeeqMicState.backgroundNoService => 'assistant.diag_mic_bg'.tr(),
      };

  // UsageStatsManager's standby buckets.
  String _bucket(int b) => b == 0
      ? '—'
      : b <= 10
      ? 'assistant.diag_bucket_active'.tr()
      : b <= 20
      ? 'assistant.diag_bucket_working'.tr()
      : b <= 30
      ? 'assistant.diag_bucket_frequent'.tr()
      : b <= 40
      ? 'assistant.diag_bucket_rare'.tr()
      : 'assistant.diag_bucket_restricted'.tr();

  @override
  Widget build(BuildContext context) {
    final ear = RafeeqEar.instance;
    final scheme = Theme.of(context).colorScheme;
    final refused = _phone['refused'] as String?;
    final model = ear.accurateModel;
    final battery = _phone['batteryExempt'] as bool?;
    Widget head(String key) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
          child: Text(key.tr(),
              style: TextStyle(
                  color: scheme.primary, fontWeight: FontWeight.bold)),
        );
    Widget row(String key, String value, {Widget? trailing, bool bad = false}) =>
        ListTile(
          title: Text(key.tr()),
          subtitle: Text(value,
              style: bad ? TextStyle(color: scheme.error) : null),
          trailing: trailing,
        );
    return Scaffold(
      appBar: AppBar(title: Text('assistant.diag_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          head('assistant.diag_now'),
          row(
            'assistant.diag_service',
            _phone['service'] == true
                ? 'assistant.diag_service_on'.tr()
                : refused != null
                ? 'assistant.diag_service_refused'.tr(args: [refused])
                : 'assistant.diag_service_off'.tr(),
            bad: _phone['service'] != true,
          ),
          ValueListenableBuilder<RafeeqMicState>(
            valueListenable: _diag.mic,
            builder: (_, s, _) => row('assistant.diag_mic', _mic(s),
                bad: s != RafeeqMicState.listening),
          ),
          row('assistant.diag_silenced', _yesNo(_phone['silenced'] as bool?),
              bad: _phone['silenced'] == true),
          row(
            'assistant.diag_source',
            ear.viaBluetooth
                ? 'assistant.diag_source_bt'.tr()
                : 'assistant.diag_source_phone'.tr(),
          ),
          row(
            'assistant.diag_model',
            model == null
                ? 'assistant.diag_model_none'.tr()
                : model
                ? 'assistant.diag_model_accurate'.tr()
                : 'assistant.diag_model_base'.tr(),
          ),
          head('assistant.diag_last'),
          ValueListenableBuilder(
            valueListenable: _diag.heard,
            builder: (_, h, _) => h == null
                ? row('assistant.diag_last', 'assistant.diag_last_none'.tr())
                : Column(children: [
                    ListTile(
                      title: Text(h.text, textDirection: TextDirection.rtl),
                      subtitle: Text([
                        'assistant.diag_ago'.tr(args: [
                          '${DateTime.now().difference(h.at).inSeconds}'
                        ]),
                        if (h.intent != null)
                          'assistant.diag_understood'.tr(args: [h.intent!]),
                        'assistant.diag_level'.tr(
                            args: ['${(_diag.lastPeak * 100).round()}']),
                        if (_diag.decodeMs != null)
                          'assistant.diag_decode_ms'.tr(args: ['${_diag.decodeMs}']),
                        if (_diag.actMs.value != null)
                          'assistant.diag_act_ms'.tr(args: ['${_diag.actMs.value}']),
                      ].join('\n')),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: OutlinedButton.icon(
                        onPressed: _diag.lastClip == null ? null : _share,
                        icon: const Icon(Icons.share_rounded),
                        label: Text('assistant.diag_share'.tr()),
                      ),
                    ),
                  ]),
          ),
          head('assistant.diag_phone'),
          row('assistant.diag_battery', _yesNo(battery),
              bad: battery == false,
              trailing: battery == false
                  ? FilledButton(
                      onPressed: () async {
                        await Permission.ignoreBatteryOptimizations.request();
                        await _read();
                      },
                      child: Text('assistant.diag_fix'.tr()),
                    )
                  : null),
          row('assistant.diag_bg_restricted',
              _yesNo(_phone['bgRestricted'] as bool?),
              bad: _phone['bgRestricted'] == true),
          row('assistant.diag_bucket',
              _bucket((_phone['bucket'] as int?) ?? 0),
              bad: ((_phone['bucket'] as int?) ?? 0) > 40),
          ListTile(
            title: Text('assistant.diag_autostart'.tr()),
            subtitle: Text('assistant.diag_autostart_desc'.tr()),
            isThreeLine: true,
            trailing: FilledButton(
              onPressed: AdhanUriBridge.openAutostartSettings,
              child: Text('assistant.diag_open'.tr()),
            ),
          ),
          row('assistant.overlay_title', _yesNo(_overlay),
              bad: _overlay == false,
              trailing: _overlay == false
                  ? FilledButton(
                      onPressed: () =>
                          _channel.invokeMethod<void>('overlayRequest'),
                      child: Text('assistant.overlay_grant'.tr()),
                    )
                  : null),
          row(
            'assistant.diag_device',
            _phone.isEmpty
                ? '—'
                : '${_phone['maker']} ${_phone['model']} · Android API ${_phone['sdk']}',
          ),
        ],
      ),
    );
  }
}
