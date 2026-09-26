import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/dorar_service.dart';

/// «تخريج الأحاديث - الدرر السنية»: type any part of a hadith, get every
/// grading Dorar's encyclopaedia holds for it, each with its grader's name,
/// source and page (owner, 2026-09-26). Live; nothing stored.
class DorarScreen extends StatefulWidget {
  const DorarScreen({super.key, this.initialQuery});

  /// A hadith handed over from elsewhere in the app (searched at once).
  final String? initialQuery;

  @override
  State<DorarScreen> createState() => _DorarScreenState();
}

class _DorarScreenState extends State<DorarScreen> {
  final _controller = TextEditingController();
  final List<DorarHadith> _results = [];
  String _query = '';
  int _page = 0;
  bool _busy = false;
  bool _failed = false;
  bool _exhausted = false;

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuery?.trim() ?? '';
    if (q.isNotEmpty) {
      _controller.text = q;
      _search(q);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    q = q.trim();
    if (q.length < 2) return;
    setState(() {
      _query = q;
      _page = 0;
      _results.clear();
      _exhausted = false;
    });
    await _more();
  }

  Future<void> _more() async {
    if (_busy || _exhausted) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final next = await DorarService.instance.search(_query, page: _page + 1);
      if (!mounted) return;
      setState(() {
        _page++;
        // A page that adds nothing new is the end of the results.
        final seen = {for (final h in _results) '${h.text}|${h.muhaddith}|${h.page}'};
        final fresh = [
          for (final h in next)
            if (seen.add('${h.text}|${h.muhaddith}|${h.page}')) h,
        ];
        _results.addAll(fresh);
        _exhausted = fresh.isEmpty;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('dorar.title'.tr())),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            onSubmitted: _search,
            decoration: InputDecoration(
              hintText: 'dorar.hint'.tr(),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward),
                tooltip: 'dorar.title'.tr(),
                onPressed: () => _search(_controller.text),
              ),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        if (_busy && _results.isEmpty) const LinearProgressIndicator(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
            children: [
              if (_failed)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('dorar.failed'.tr(), textAlign: TextAlign.center),
                ),
              if (!_busy && !_failed && _query.isNotEmpty && _results.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('dorar.none'.tr(), textAlign: TextAlign.center),
                ),
              for (final h in _results) DorarGradingCard(h: h),
              if (_results.isNotEmpty && !_exhausted)
                Center(
                  child: _busy
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator())
                      : TextButton.icon(
                          onPressed: _more,
                          icon: const Icon(Icons.expand_more),
                          label: Text('dorar.more'.tr()),
                        ),
                ),
              if (_results.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text('dorar.credit'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11.5, color: scheme.onSurfaceVariant)),
                ),
            ],
          ),
        ),
      ]),
    );
  }
}

/// One grading from Dorar: the text as Dorar has it, then narrator, the
/// named grader, source, page and the verdict. Also used by the
/// «تخريج من الدرر» sheet.
class DorarGradingCard extends StatelessWidget {
  const DorarGradingCard({super.key, required this.h});
  final DorarHadith h;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget row(String key, String value, {bool strong = false}) => value.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text.rich(TextSpan(children: [
              TextSpan(
                  text: '${key.tr()}: ',
                  style: TextStyle(color: scheme.onSurfaceVariant)),
              TextSpan(
                  text: value,
                  style: TextStyle(
                      fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
                      color: strong ? goldText(context) : null)),
            ])),
          );
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectableText(h.text,
                style: const TextStyle(fontSize: 16.5, height: 1.8)),
            const Divider(height: 18),
            row('dorar.rawi', h.rawi),
            row('dorar.muhaddith', h.muhaddith, strong: true),
            row('dorar.source', h.source),
            row('dorar.page', h.page),
            row('dorar.grade', h.grade, strong: true),
          ],
        ),
      ),
    );
  }
}
