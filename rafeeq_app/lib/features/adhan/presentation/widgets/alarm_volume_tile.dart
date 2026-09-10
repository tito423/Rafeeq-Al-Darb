import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/adhan_native.dart';

/// The phone's alarm volume, adjustable from inside the adhan settings.
///
/// WHY THIS IS HERE. The adhan plays on `STREAM_ALARM` — see `AdhanPlayer`'s
/// `AudioAttributes` — so it is heard when the phone is on silent or in Do Not
/// Disturb. That is the whole point of an adhan and it is not going to change.
/// The consequence is that the volume rocker, which moves the **media**
/// stream, does nothing to it:
///
///   «لما أجي أسمع الأذان … صوتهم مش بيعلى إلا لما أعلي صوت المنبه من الفون»
///
/// The behaviour is right; the errand is not. So the alarm slider is here,
/// beside the adhans it governs, and it says which volume it is so nobody has
/// to work that out either.
class AlarmVolumeTile extends StatefulWidget {
  const AlarmVolumeTile({super.key});

  @override
  State<AlarmVolumeTile> createState() => _AlarmVolumeTileState();
}

class _AlarmVolumeTileState extends State<AlarmVolumeTile> {
  int? _current;
  int _max = 0;

  /// Set when the system refused a change — a Do Not Disturb policy can
  /// forbid this stream. Shown rather than swallowed, because a slider that
  /// moves and changes nothing is worse than one that explains itself.
  bool _refused = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await AdhanNative.alarmVolume();
    if (!mounted || v == null) return;
    setState(() {
      _current = v.current;
      _max = v.max;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = _current;
    // Nothing to show if the platform would not tell us — better an absent
    // control than one that pretends.
    if (current == null || _max <= 0) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.alarm_rounded, size: 20, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'prayer.alarm_volume'.tr(),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  '$current / $_max',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            Text(
              'prayer.alarm_volume_desc'.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            Slider(
              value: current.toDouble().clamp(0, _max.toDouble()),
              min: 0,
              max: _max.toDouble(),
              divisions: _max,
              onChanged: (v) => setState(() => _current = v.round()),
              onChangeEnd: (v) async {
                final ok = await AdhanNative.setAlarmVolume(v.round());
                if (!mounted) return;
                setState(() => _refused = !ok);
                // Read it back: the system is the source of truth, not the
                // position the finger left the thumb in.
                await _load();
              },
            ),
            if (_refused)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'prayer.alarm_volume_refused'.tr(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.error,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
