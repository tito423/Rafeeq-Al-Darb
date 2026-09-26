import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/city_catalog.dart';
import '../../../../core/services/manual_location.dart';
import '../../../../core/utils/user_error.dart';
import '../../../home/data/prayer_controller.dart';
import '../../../../core/widgets/readable_insets.dart';

/// The row in Adhan settings: where the prayer times are calculated for, and
/// the way into [PrayerLocationScreen].
class PrayerLocationTile extends StatefulWidget {
  const PrayerLocationTile({super.key});

  @override
  State<PrayerLocationTile> createState() => _PrayerLocationTileState();
}

class _PrayerLocationTileState extends State<PrayerLocationTile> {
  ManualPlace? _manual;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = await ManualLocationStore.instance.read();
    if (mounted) setState(() => _manual = m);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final m = _manual;
    return ListTile(
      leading: Icon(m == null ? Icons.gps_fixed : Icons.edit_location_alt),
      title: Text('location.title'.tr()),
      subtitle: Text(m == null
          ? 'location.auto'.tr()
          : _placeLine(m, lang)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const PrayerLocationScreen()));
        await _load();
      },
    );
  }
}

String _placeLine(ManualPlace p, String lang) => [
      p.cityIn(lang),
      p.countryIn(lang),
    ].whereType<String>().join('location.sep'.tr());

/// «زود في اعدادات الموقع للصلاة اني ادخله يدوي … ايا كان موقعي فيشتغل حتى
/// لو مفيش نت او الموقع الاوتوماتيكي مش شغال» and «any city in the world …
/// without app size growing» (owner, 2026-09-25).
///
/// Three roads, best first: the offline world list (bundled, unpacked on
/// first open), the phone's geocoder when there is a connection, and
/// typed coordinates when there is neither. Whatever is chosen is stored in
/// [ManualLocationStore]; LocationService answers with it from then on.
class PrayerLocationScreen extends ConsumerStatefulWidget {
  const PrayerLocationScreen({super.key});

  @override
  ConsumerState<PrayerLocationScreen> createState() =>
      _PrayerLocationScreenState();
}

class _PrayerLocationScreenState extends ConsumerState<PrayerLocationScreen> {
  final _query = TextEditingController();
  final _queryFocus = FocusNode();
  final _lat = TextEditingController();
  final _lon = TextEditingController();
  final _name = TextEditingController();
  Timer? _debounce;
  ManualPlace? _manual;
  bool _listReady = false;
  bool _preparing = false;
  bool _searching = false;
  bool _online = false;
  List<CityHit> _hits = const [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final m = await ManualLocationStore.instance.read();
    final ready = await CityCatalog.instance.isInstalled();
    if (!mounted) return;
    setState(() {
      _manual = m;
      _listReady = ready;
      _preparing = !ready;
    });
    if (!ready) await _prepareList();
  }

  /// The first open unpacks the bundled list (a few seconds, once).
  Future<void> _prepareList() async {
    try {
      await CityCatalog.instance.ensureReady();
      if (!mounted) return;
      setState(() {
        _listReady = true;
        _preparing = false;
      });
      if (_query.text.trim().length >= 2) unawaited(_search());
    } catch (e) {
      if (!mounted) return;
      setState(() => _preparing = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userErrorText(e))));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _queryFocus.dispose();
    _lat.dispose();
    _lon.dispose();
    _name.dispose();
    super.dispose();
  }

  void _onQuery(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _search);
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.length < 2) {
      setState(() => _hits = const []);
      return;
    }
    setState(() => _searching = true);
    final lang = context.locale.languageCode;
    var hits = _listReady
        ? await CityCatalog.instance.search(q)
        : const <CityHit>[];
    var online = false;
    if (hits.isEmpty) {
      hits = await CityCatalog.instance.searchOnline(q, lang);
      online = hits.isNotEmpty;
    }
    if (!mounted || _query.text.trim() != q) return;
    setState(() {
      _hits = hits;
      _online = online;
      _searching = false;
    });
  }

  Future<void> _use(ManualPlace? place) async {
    if (place == null) {
      await ManualLocationStore.instance.clear();
    } else {
      await ManualLocationStore.instance.write(place);
    }
    // The card, the adhan alarms and the status notification all follow
    // the controller, which now reads the new place (or the GPS again).
    ref.invalidate(prayerControllerProvider);
    if (!mounted) return;
    final lang = context.locale.languageCode;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(place == null
          ? 'location.auto'.tr()
          : 'location.set_to'.tr(args: [_placeLine(place, lang)])),
    ));
    Navigator.of(context).pop();
  }

  void _useCoordinates() {
    final lat = double.tryParse(_lat.text.trim().replaceAll(',', '.'));
    final lon = double.tryParse(_lon.text.trim().replaceAll(',', '.'));
    if (lat == null || lon == null || lat.abs() > 90 || lon.abs() > 180) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('location.invalid'.tr())));
      return;
    }
    final name = _name.text.trim();
    _use(ManualPlace(
      latitude: lat,
      longitude: lon,
      names: {
        'name': name.isEmpty
            ? '${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}'
            : name,
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('location.title'.tr())),
      body: ListView(
        padding: readableInsets(context, const EdgeInsets.fromLTRB(12, 8, 12, 24)),
        children: [
          Card(
            child: Column(children: [
              ListTile(
                onTap: _manual == null ? null : () => _use(null),
                leading: const Icon(Icons.gps_fixed),
                title: Text('location.auto'.tr()),
                subtitle: Text('location.auto_desc'.tr()),
                trailing: _manual == null
                    ? Icon(Icons.check_circle, color: scheme.primary)
                    : const Icon(Icons.radio_button_unchecked),
              ),
              ListTile(
                // «تحديد يدوي» was a row that did nothing when tapped: it
                // takes the reader to the search that sets it.
                onTap: () => _queryFocus.requestFocus(),
                leading: const Icon(Icons.edit_location_alt),
                title: Text('location.manual'.tr()),
                subtitle: Text(_manual == null
                    ? 'location.manual_desc'.tr()
                    : _placeLine(_manual!, lang)),
                trailing: _manual != null
                    ? Icon(Icons.check_circle, color: scheme.primary)
                    : const Icon(Icons.radio_button_unchecked),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _query,
            focusNode: _queryFocus,
            onChanged: _onQuery,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'location.search_hint'.tr(),
              border: const OutlineInputBorder(),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          if (_preparing)
            ListTile(
              leading: const Icon(Icons.public),
              title: Text('location.preparing'.tr()),
              subtitle: const LinearProgressIndicator(),
            )
          else if (_listReady)
            ListTile(
              dense: true,
              leading: Icon(Icons.offline_pin, color: scheme.primary),
              title: Text('location.list_ready'.tr()),
            ),
          if (_online)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('location.online_note'.tr(),
                  style: TextStyle(color: scheme.onSurfaceVariant)),
            ),
          for (final h in _hits)
            ListTile(
              leading: const Icon(Icons.place_outlined),
              title: Text(h.place.cityIn(lang) ?? ''),
              subtitle: Text([
                h.place.countryIn(lang),
                '${h.place.latitude.toStringAsFixed(3)}, '
                    '${h.place.longitude.toStringAsFixed(3)}',
              ].whereType<String>().join(' · ')),
              onTap: () => _use(h.place),
            ),
          if (!_searching && _hits.isEmpty && _query.text.trim().length >= 2)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('location.no_results'.tr(),
                  style: TextStyle(color: scheme.onSurfaceVariant)),
            ),
          const SizedBox(height: 8),
          Card(
            child: ExpansionTile(
              leading: const Icon(Icons.pin_drop_outlined),
              title: Text('location.coords'.tr()),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                _numberField(_lat, 'location.lat'.tr()),
                const SizedBox(height: 8),
                _numberField(_lon, 'location.lon'.tr()),
                const SizedBox(height: 8),
                TextField(
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: 'location.coords_name'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _useCoordinates,
                  child: Text('location.save'.tr()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('location.source'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _numberField(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true, signed: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[-0-9.,]')),
        ],
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      );
}
