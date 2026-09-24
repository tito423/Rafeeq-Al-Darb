import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/download_manager.dart';
import '../../../../core/utils/byte_formatter.dart' show formatBytes;
import '../../../../core/utils/digits.dart' show trn;
import 'offline_pack_row.dart';

/// One downloadable pack, offered on the first-run page.
///
/// «والاوبشنز اللي ممكن يحملها المستخدم في نفس الصفحة بدل مايتفاجأ بيها جوه
/// مش موجودة زي التفاسير مثلا». The first run offered the paper mushaf and
/// nothing else, so a reader met علوم القرآن for the first time as a
/// download prompt inside an ayah card, weeks later — the thing he asked not
/// to be surprised by.
///
/// It shows the real size before he spends it (`formatBytes` wraps the
/// figure in an LTR isolate, trap #16), the live progress while it runs, and
/// nothing at all once the pack is on the device: a first-run page should
/// not offer what the reader already has.
class ContentPackTile extends StatefulWidget {
  final IconData icon;
  final String titleKey;
  final String hintKey;
  final int bytes;
  final String downloadId;
  final Future<void> Function() onDownload;

  /// Null while it is unknown; true hides the tile entirely.
  final bool installed;

  const ContentPackTile({
    super.key,
    required this.icon,
    required this.titleKey,
    required this.hintKey,
    required this.bytes,
    required this.downloadId,
    required this.onDownload,
    this.installed = false,
  });

  @override
  State<ContentPackTile> createState() => _ContentPackTileState();
}

class _ContentPackTileState extends State<ContentPackTile> {
  StreamSubscription<List<DownloadTask>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = DownloadManager.instance.stream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.installed) return const SizedBox.shrink();
    final task = DownloadManager.instance.taskById(widget.downloadId);
    final busy = task != null &&
        (task.status == DownloadStatus.downloading ||
            task.status == DownloadStatus.queued);
    return OfflinePackRow(
      icon: widget.icon,
      title: widget.titleKey.tr(),
      hint: trn(widget.hintKey, args: [formatBytes(widget.bytes)]),
      state: PackState(
        done: task?.status == DownloadStatus.completed,
        busy: busy,
        progress: busy && task.total != null ? task.progress : null,
      ),
      onDownload: widget.onDownload,
      onCancel: () => DownloadManager.instance.cancel(widget.downloadId),
    );
  }
}
