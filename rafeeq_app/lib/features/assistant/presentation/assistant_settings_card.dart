import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _pack.check();
  }

  Future<void> _download() async {
    try {
      await _pack.download();
    } catch (e) {
      debugPrint('rafeeq voice pack: $e');
      rootScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('assistant.pack_failed'.tr())));
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
                secondary: Icon(Icons.record_voice_over_rounded,
                    color: scheme.primary),
                title: Text('assistant.setting_switch'.tr()),
                subtitle: Text(installed == true
                    ? 'assistant.setting_desc'.tr()
                    : 'assistant.pack_needed'.tr()),
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
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.download_for_offline_rounded,
                    color: scheme.primary),
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
                    : Text('assistant.pack_desc'
                        .tr(args: [formatBytes(voicePackBytes)])),
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
            ],
          ),
        ),
      ),
    );
  }
}
