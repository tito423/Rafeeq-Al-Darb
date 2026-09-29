import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/navigation.dart';
import '../../../core/utils/byte_formatter.dart';
import '../data/assistant_settings.dart';
import '../data/rafeeq_ear.dart';
import '../data/rafeeq_voice_pack.dart';

/// «رفيق» in the settings (and from its row in the downloads): the voice pack
/// - downloaded once, deleted here - and the switch, which does nothing until
/// the pack is on the phone (owner, 2026-09-27: «ولو منزلوش الأفضل مايشتغلش»).
class AssistantSettingsCard extends ConsumerStatefulWidget {
  const AssistantSettingsCard({super.key});

  @override
  ConsumerState<AssistantSettingsCard> createState() =>
      _AssistantSettingsCardState();
}

class _AssistantSettingsCardState extends ConsumerState<AssistantSettingsCard> {
  final _pack = RafeeqVoicePack.instance;
  static const _channel = MethodChannel('com.tito.rafeeq_aldarb/assistant');
  bool? _overlayOk;

  @override
  void initState() {
    super.initState();
    _pack.check();
    _readOverlay();
  }

  Future<void> _readOverlay() async {
    try {
      final ok = await _channel.invokeMethod<bool>('overlayCan');
      if (mounted) setState(() => _overlayOk = ok);
    } catch (_) {
      // Not Android, or the channel is not up: no row.
    }
  }

  Future<void> _grantOverlay() async {
    await _channel.invokeMethod<void>('overlayRequest');
    // The system screen returns to the app when the reader is done.
    await Future<void>.delayed(const Duration(seconds: 1));
    if (mounted) await _readOverlay();
  }

  Future<void> _download() async {
    try {
      await _pack.download();
    } catch (e) {
      debugPrint('rafeeq voice pack: $e');
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('assistant.pack_failed'.tr())),
      );
    }
  }

  Future<void> _delete() async {
    await ref.read(assistantEnabledProvider.notifier).set(false);
    await RafeeqEar.instance.shutdown();
    await _pack.delete();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = ref.watch(assistantEnabledProvider);
    return ValueListenableBuilder<bool?>(
      valueListenable: _pack.installed,
      builder: (context, installed, _) => ValueListenableBuilder<double?>(
        valueListenable: _pack.progress,
        builder: (context, progress, _) => Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: Icon(
                  Icons.record_voice_over_rounded,
                  color: scheme.primary,
                ),
                title: Text('assistant.setting_switch'.tr()),
                subtitle: Text(
                  installed == true
                      ? 'assistant.setting_desc'.tr()
                      : 'assistant.pack_needed'.tr(),
                ),
                value: enabled && installed == true,
                onChanged: installed != true
                    ? null
                    : (v) async {
                        if (v) {
                          if (!(await Permission.microphone.request())
                              .isGranted) {
                            return;
                          }
                          // The listening notification; Android 13+ hides it
                          // without this, and the reader must see it.
                          await Permission.notification.request();
                        }
                        await ref
                            .read(assistantEnabledProvider.notifier)
                            .set(v);
                      },
              ),
              if (enabled && installed == true) ...[
                const Divider(height: 1),
                SwitchListTile(
                  secondary: Icon(
                    Icons.bluetooth_audio_rounded,
                    color: scheme.primary,
                  ),
                  title: Text('assistant.bt_mic'.tr()),
                  subtitle: Text('assistant.bt_mic_desc'.tr()),
                  value: ref.watch(assistantBluetoothMicProvider),
                  onChanged: (v) =>
                      ref.read(assistantBluetoothMicProvider.notifier).set(v),
                ),
              ],
              if (_overlayOk == false) ...[
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.layers_rounded, color: scheme.primary),
                  title: Text('assistant.overlay_title'.tr()),
                  subtitle: Text('assistant.overlay_desc'.tr()),
                  trailing: FilledButton(
                    onPressed: _grantOverlay,
                    child: Text('assistant.overlay_grant'.tr()),
                  ),
                ),
              ],
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  Icons.download_for_offline_rounded,
                  color: scheme.primary,
                ),
                title: Text('assistant.pack_title'.tr()),
                subtitle: progress != null
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LinearProgressIndicator(value: progress),
                            const SizedBox(height: 6),
                            Text(
                              '${formatBytes((progress * voicePackBytes).round())}'
                              ' / ${formatBytes(voicePackBytes)}',
                            ),
                          ],
                        ),
                      )
                    : Text(
                        'assistant.pack_desc'.tr(
                          args: [formatBytes(voicePackBytes)],
                        ),
                      ),
                trailing: progress != null
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: _pack.cancel,
                      )
                    : installed == true
                    ? TextButton(
                        onPressed: _delete,
                        child: Text('assistant.pack_delete'.tr()),
                      )
                    : FilledButton(
                        onPressed: _download,
                        child: Text('assistant.pack_download'.tr()),
                      ),
              ),
              if (installed == true) ...[
                const Divider(height: 1),
                const _AccuratePackTile(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// «دقة أعلى»: the optional whisper pack (RafeeqVoicePack.accurate). Offered
/// only once the base pack is on the phone - it re-reads what the base pack
/// heard, it does not replace it.
class _AccuratePackTile extends StatefulWidget {
  const _AccuratePackTile();

  @override
  State<_AccuratePackTile> createState() => _AccuratePackTileState();
}

class _AccuratePackTileState extends State<_AccuratePackTile> {
  final _pack = RafeeqVoicePack.accurate;

  @override
  void initState() {
    super.initState();
    _pack.check();
  }

  Future<void> _download() async {
    try {
      await _pack.download();
      await RafeeqEar.instance.reload(); // load it now
    } catch (e) {
      debugPrint('rafeeq accurate pack: $e');
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('assistant.pack_failed'.tr())),
      );
    }
  }

  Future<void> _delete() async {
    await RafeeqEar.instance.reload(); // let go of the files first
    await _pack.delete();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<bool?>(
      valueListenable: _pack.installed,
      builder: (context, installed, _) => ValueListenableBuilder<double?>(
        valueListenable: _pack.progress,
        builder: (context, progress, _) => ListTile(
          leading: Icon(Icons.hearing_rounded, color: scheme.primary),
          title: Text('assistant.accurate_title'.tr()),
          subtitle: progress != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(value: progress),
                      const SizedBox(height: 6),
                      Text(
                        ratio(
                          formatBytes((progress * _pack.totalBytes).round()),
                          formatBytes(_pack.totalBytes),
                        ),
                      ),
                    ],
                  ),
                )
              : Text(
                  'assistant.accurate_desc'.tr(
                    args: [formatBytes(_pack.totalBytes)],
                  ),
                ),
          isThreeLine: progress == null,
          trailing: progress != null
              ? IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _pack.cancel,
                )
              : installed == true
              ? TextButton(
                  onPressed: _delete,
                  child: Text('assistant.pack_delete'.tr()),
                )
              : FilledButton(
                  onPressed: _download,
                  child: Text('assistant.pack_download'.tr()),
                ),
        ),
      ),
    );
  }
}
