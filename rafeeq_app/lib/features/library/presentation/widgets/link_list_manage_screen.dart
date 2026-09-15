/// «تخصيص القائمة» for a link list: reorder, hide, edit, delete, restore, and
/// the one choice of where links open. Shared by «قنوات دعوية» and «مواقع
/// إسلامية» so the two can never drift into two different editors.
library;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/external_link.dart';
import '../../data/link_list_customization.dart';

/// One entry as a list shows it — with the reader's edits already applied.
class ManagedLink {
  final String id;
  final String name;
  final String subtitle;
  final String url;
  final Widget leading;

  const ManagedLink({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.url,
    required this.leading,
  });
}

/// [catalogue] in catalogue order, edits applied; the screen arranges it.
class LinkListManageScreen extends ConsumerWidget {
  final String listId;
  final String title;
  final List<ManagedLink> Function(LinkListState) catalogue;

  const LinkListManageScreen({
    super.key,
    required this.listId,
    required this.title,
    required this.catalogue,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(linkListProvider(listId));
    final notifier = ref.read(linkListProvider(listId).notifier);
    final inApp = ref.watch(linkOpenInAppProvider);
    final scheme = Theme.of(context).colorScheme;

    final all = catalogue(state);
    final byId = {for (final l in all) l.id: l};
    final ids = state.arrange([for (final l in all) l.id]);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (state.isCustomised)
            IconButton(
              tooltip: 'links.restore'.tr(),
              icon: const Icon(Icons.settings_backup_restore_rounded),
              onPressed: () async {
                final ok = await _confirm(
                    context, 'links.restore'.tr(), 'links.restore_confirm'.tr());
                if (ok) await notifier.restoreDefaults();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('links.open_mode'.tr(),
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: true,
                        icon: const Icon(Icons.open_in_browser_rounded),
                        label: Text('links.open_in_app'.tr()),
                      ),
                      ButtonSegment(
                        value: false,
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: Text('links.open_external'.tr()),
                      ),
                    ],
                    selected: {inApp},
                    onSelectionChanged: (s) =>
                        ref.read(linkOpenInAppProvider.notifier).set(s.first),
                  ),
                ),
                const SizedBox(height: 10),
                Text('links.drag_hint'.tr(),
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              itemCount: ids.length,
              onReorder: (from, to) {
                final next = [...ids];
                final moved = next.removeAt(from);
                next.insert(to > from ? to - 1 : to, moved);
                notifier.reorder(next);
              },
              itemBuilder: (context, i) {
                final link = byId[ids[i]]!;
                final hidden = state.hidden.contains(link.id);
                return Card(
                  key: ValueKey(link.id),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Opacity(
                    opacity: hidden ? 0.5 : 1,
                    child: ListTile(
                      contentPadding:
                          const EdgeInsetsDirectional.fromSTEB(12, 4, 4, 4),
                      leading: link.leading,
                      title: Text(link.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        hidden ? 'links.hidden_badge'.tr() : link.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: hidden ? null : TextDirection.ltr,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: hidden
                                ? 'links.show'.tr()
                                : 'links.hide'.tr(),
                            icon: Icon(hidden
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded),
                            onPressed: () =>
                                notifier.setHidden(link.id, !hidden),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'edit') {
                                await _edit(context, notifier, link);
                              } else if (v == 'delete') {
                                final ok = await _confirm(context,
                                    link.name, 'links.delete_confirm'.tr());
                                if (ok) await notifier.delete(link.id);
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: ListTile(
                                  leading: const Icon(Icons.edit_rounded),
                                  title: Text('links.edit'.tr()),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: ListTile(
                                  leading: Icon(Icons.delete_outline_rounded,
                                      color: scheme.error),
                                  title: Text('links.delete'.tr()),
                                ),
                              ),
                            ],
                          ),
                          ReorderableDragStartListener(
                            index: i,
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.drag_handle_rounded),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static Future<bool> _confirm(
      BuildContext context, String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  static Future<void> _edit(
      BuildContext context, LinkListNotifier notifier, ManagedLink link) async {
    final name = TextEditingController(text: link.name);
    final url = TextEditingController(text: link.url);
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('links.edit'.tr()),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                decoration: InputDecoration(labelText: 'links.name'.tr()),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: url,
                textDirection: TextDirection.ltr,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(labelText: 'links.url'.tr()),
                validator: (v) => isOpenableLink(v ?? '')
                    ? null
                    : 'links.invalid_url'.tr(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: Text('common.save'.tr()),
          ),
        ],
      ),
    );
    if (saved == true) await notifier.edit(link.id, name.text, url.text);
    name.dispose();
    url.dispose();
  }
}

/// The «تخصيص القائمة» row above a list.
class ManageLinksButton extends StatelessWidget {
  final VoidCallback onPressed;
  const ManageLinksButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.tune_rounded, size: 18),
        label: Text('links.manage'.tr()),
      ),
    );
  }
}

/// Opens [url] the way the reader chose, and says so if it could not.
Future<void> openManagedLink(
    BuildContext context, WidgetRef ref, String url) async {
  final ok = await openLink(url, inApp: ref.read(linkOpenInAppProvider));
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('links.open_failed'.tr())));
  }
}
