import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/digits.dart';
import '../../library/data/library_api_service.dart';
import '../../library/presentation/screens/book_text_reader_screen.dart';
import '../data/shamela_book_builder.dart';
import '../data/shamela_catalog.dart';
import '../data/shamela_import_service.dart';
import '../data/shamela_library.dart';

/// «المكتبة الشاملة» inside the app: search Shamela's own catalogue by book
/// title, see a book's card, import it into the library (owner, 2026-09-26).
class ShamelaScreen extends StatefulWidget {
  const ShamelaScreen({super.key});

  @override
  State<ShamelaScreen> createState() => _ShamelaScreenState();
}

class _ShamelaScreenState extends State<ShamelaScreen> {
  final _catalog = ShamelaCatalog.instance;
  final _controller = TextEditingController();
  Timer? _debounce;
  bool _loading = true;
  bool _failed = false;
  List<ShamelaBookRef> _results = const [];

  @override
  void initState() {
    super.initState();
    ShamelaLibrary.instance.addListener(_changed);
    ShamelaImportService.instance.jobs.addListener(_changed);
    _loadCatalog();
  }

  @override
  void dispose() {
    ShamelaLibrary.instance.removeListener(_changed);
    ShamelaImportService.instance.jobs.removeListener(_changed);
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      await ShamelaLibrary.instance.load();
      await _catalog.load();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _onQuery(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _results = _catalog.search(q));
    });
  }

  Future<void> _open(String bookId) async {
    final book = ShamelaLibrary.instance.byId(bookId);
    if (book == null) return;
    final path = await LibraryApiService.instance.bookFilePath(bookId);
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => BookTextReaderScreen(book: book, path: path),
    ));
  }

  Future<void> _delete(String bookId) async {
    await LibraryApiService.instance.deleteBook(bookId);
    await ShamelaLibrary.instance.remove(bookId);
  }

  void _showCard(ShamelaBookRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BookCardSheet(ref: ref, onOpen: _open),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final scheme = Theme.of(context).colorScheme;
    final imported = ShamelaLibrary.instance.books;
    final jobs = ShamelaImportService.instance.jobs.value;
    final query = _controller.text.trim();
    return Scaffold(
      appBar: AppBar(title: Text('shamela.title'.tr())),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: TextField(
            controller: _controller,
            enabled: !_loading && !_failed,
            textInputAction: TextInputAction.search,
            onChanged: _onQuery,
            decoration: InputDecoration(
              hintText: 'shamela.search_hint'.tr(),
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        if (_loading)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text('shamela.loading_catalog'.tr()),
            ]),
          )
        else if (_failed)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Text('shamela.catalog_failed'.tr(), textAlign: TextAlign.center),
              const SizedBox(height: 10),
              FilledButton.tonal(
                  onPressed: _loadCatalog, child: Text('common.retry'.tr())),
            ]),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                localizeDigits(
                    'shamela.count'.tr(args: ['${_catalog.count}']), lang),
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
            children: [
              for (final j in jobs.values)
                _JobTile(job: j, lang: lang),
              if (query.isEmpty && imported.isNotEmpty) ...[
                _Header('shamela.imported_section'.tr()),
                for (final b in imported)
                  Card(
                    child: ListTile(
                      leading: Icon(Icons.menu_book_rounded,
                          color: goldText(context)),
                      title: Text(b.titleAr),
                      subtitle: Text(b.authorAr,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => _open(b.id),
                      trailing: IconButton(
                        tooltip: 'shamela.delete'.tr(),
                        icon: Icon(Icons.delete_outline, color: scheme.error),
                        onPressed: () => _delete(b.id),
                      ),
                    ),
                  ),
              ],
              if (query.isNotEmpty && _results.isEmpty && !_loading)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: Text('shamela.no_results'.tr())),
                ),
              for (final r in _results)
                Card(
                  child: ListTile(
                    title: Text(r.title),
                    subtitle: ShamelaLibrary.instance.isImported(r.id)
                        ? Text('shamela.in_library'.tr(),
                            style: TextStyle(color: scheme.primary))
                        : null,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: ShamelaLibrary.instance.isImported(r.id)
                        ? () => _open(ShamelaLibrary.idFor(r.id))
                        : () => _showCard(r),
                  ),
                ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w800)),
      );
}

class _JobTile extends StatelessWidget {
  const _JobTile({required this.job, required this.lang});
  final ShamelaImportJob job;
  final String lang;
  @override
  Widget build(BuildContext context) {
    final failed = job.error != null;
    final service = ShamelaImportService.instance;
    return Card(
      color: AppColors.gold.withValues(alpha: 0.08),
      child: ListTile(
        leading: failed
            ? const Icon(Icons.error_outline)
            : const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2)),
        title: Text(job.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(failed
            ? 'shamela.failed'.tr()
            : localizeDigits(
                'shamela.importing'.tr(args: ['${job.pages}']), lang)),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => failed
              ? service.dismiss(job.shamelaId)
              : service.cancel(job.shamelaId),
        ),
      ),
    );
  }
}

/// A book's Shamela card - edition, publisher, parts - before importing.
class _BookCardSheet extends StatefulWidget {
  const _BookCardSheet({required this.ref, required this.onOpen});
  final ShamelaBookRef ref;
  final Future<void> Function(String bookId) onOpen;
  @override
  State<_BookCardSheet> createState() => _BookCardSheetState();
}

class _BookCardSheetState extends State<_BookCardSheet> {
  late final Future<ShamelaCard> _card =
      ShamelaBookBuilder(widget.ref.id).fetchCard();

  @override
  Widget build(BuildContext context) {
    final service = ShamelaImportService.instance;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: FutureBuilder<ShamelaCard>(
          future: _card,
          builder: (context, snap) {
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text('shamela.catalog_failed'.tr()),
              );
            }
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final card = snap.data!;
            final excluded = ShamelaBookBuilder.isExcluded(card.author);
            return ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                Text(card.title.isEmpty ? widget.ref.title : card.title,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(card.author,
                    style: TextStyle(color: goldText(context))),
                const SizedBox(height: 12),
                Text(card.card,
                    style: const TextStyle(fontSize: 13, height: 1.6)),
                const SizedBox(height: 16),
                if (excluded)
                  Text('shamela.excluded'.tr(),
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error))
                else
                  ValueListenableBuilder(
                    valueListenable: service.jobs,
                    builder: (context, _, _) => FilledButton.icon(
                      onPressed: service.isRunning(widget.ref.id)
                          ? null
                          : () {
                              service.start(widget.ref.id, card);
                              Navigator.of(context).pop();
                            },
                      icon: const Icon(Icons.download_for_offline_rounded),
                      label: Text(service.isRunning(widget.ref.id)
                          ? 'shamela.importing_short'.tr()
                          : 'shamela.import'.tr()),
                    ),
                  ),
                const SizedBox(height: 8),
                Text('shamela.source'.tr(),
                    style: TextStyle(
                        fontSize: 11.5,
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            );
          },
        ),
      ),
    );
  }
}
