import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_colors.dart';

/// P2‑8 #2 (QuranFlash-style "share ayah as image") — renders the ayah (and
/// an optional translation line) as a small branded card, rasterizes it with
/// `RepaintBoundary`, and hands the PNG to the platform share sheet. Nothing
/// is uploaded anywhere; the file is a temp PNG the OS share sheet reads
/// once. Returns false (and leaves a snackbar for the caller to show) on
/// failure — never throws into the UI.
Future<bool> shareAyahAsImage(
  BuildContext context, {
  required String ayahText,
  required String reference, // "surahName • 2:255"
  String? translation,
}) async {
  final boundaryKey = GlobalKey();
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  final completer = Completer<Uint8List?>();

  entry = OverlayEntry(
    builder: (_) => Positioned(
      // Off-screen but still laid out/painted, so RepaintBoundary can
      // capture it without ever flashing on the real screen.
      left: -2000,
      top: 0,
      child: Material(
        color: Colors.transparent,
        child: RepaintBoundary(
          key: boundaryKey,
          child: _AyahShareCard(
            ayahText: ayahText,
            reference: reference,
            translation: translation,
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);

  // Let one frame render before capturing.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      final boundary = boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      final image = await boundary?.toImage(pixelRatio: 3);
      final bytes = await image?.toByteData(format: ui.ImageByteFormat.png);
      completer.complete(bytes?.buffer.asUint8List());
    } catch (_) {
      completer.complete(null);
    } finally {
      entry.remove();
    }
  });

  final bytes = await completer.future;
  if (bytes == null) return false;

  try {
    final dir = await getTemporaryDirectory();
    final safeRef = reference.replaceAll(RegExp(r'[^\w]+'), '_');
    final file = File(p.join(dir.path, 'ayah_$safeRef.png'));
    await file.writeAsBytes(bytes, flush: true);
    if (!context.mounted) return true;
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'رفيق الدرب — $reference'),
    );
    return true;
  } catch (_) {
    return false;
  }
}

class _AyahShareCard extends StatelessWidget {
  final String ayahText;
  final String reference;
  final String? translation;

  const _AyahShareCard({
    required this.ayahText,
    required this.reference,
    this.translation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 720,
      padding: const EdgeInsets.fromLTRB(36, 44, 36, 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0C2135), Color(0xFF071625)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            ayahText,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontFamily: 'AmiriQuran',
              fontSize: 30,
              height: 1.9,
              color: AppColors.textHigh,
            ),
          ),
          if (translation != null && translation!.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              translation!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                height: 1.5,
                color: AppColors.textMedium,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 26),
          Container(height: 1, width: 80, color: AppColors.gold.withValues(alpha: 0.5)),
          const SizedBox(height: 14),
          Text(
            reference,
            style: const TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'رفيق الدرب',
            style: TextStyle(color: AppColors.textLow, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
