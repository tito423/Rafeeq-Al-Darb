/// Mosque photographs behind the Home cards and the full-screen saying.
///
/// Owner, 2026-10-08: «خلي كل كروت الشاشة الرئيسية لها خلفية مسجد زي
/// الكارتين الاولانيين ويبقى كل مسجد مختلف بشكل هادي وجميل … وخلي خلفية
/// المقولة برده مسجد جميل في شاشتها الكبيرة». Every photo here is already
/// bundled and credited on the Sources screen (Wikimedia Commons, each under
/// its own free licence - azkar_backgrounds.dart, about.src_azkar_bg,
/// quote_backgrounds.json); nothing new is fetched.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

abstract final class MosquePhotos {
  static const blueMosque = 'assets/azkar_cards/waking.jpg';
  static const meknes = 'assets/azkar_cards/mosque.jpg';
  static const vakil = 'assets/azkar_background/vakil_mosque.jpg';
  static const alMuizz = 'assets/azkar_cards/sleep.jpg';
  static const suleymaniye = 'assets/azkar_cards/afterPrayer.jpg';
  static const ummAlFahm = 'assets/azkar_cards/evening.jpg';
  static const faisal = 'assets/azkar_cards/morning.jpg';
  static const abuHanifa =
      'assets/quote_backgrounds/abu_hanifa_mosque_muqarnas.jpg';

  /// Whole mosques only, wide and calm, for the full-screen saying (owner:
  /// «مساجد برده كبيرة وجميلة وهادية بس») - no close-up of a carpet or a
  /// ceiling.
  static const wide = [
    blueMosque,
    meknes,
    vakil,
    alMuizz,
    ummAlFahm,
    faisal,
  ];

  static const all = [
    blueMosque,
    meknes,
    vakil,
    alMuizz,
    suleymaniye,
    ummAlFahm,
    faisal,
    abuHanifa,
  ];
}

/// A card with a mosque photograph laid faintly over it, the way the first
/// two Home cards carry theirs: present, calm, and never in the way of the
/// text. It takes no taps.
class MosqueBackdrop extends StatelessWidget {
  final String photo;
  final Widget child;

  /// The card's own corner, so the photo stays inside it.
  final double radius;
  const MosqueBackdrop({
    super.key,
    required this.photo,
    required this.child,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              // Day: the photo lay OVER the card at 12 %, so it veiled every
              // word too (owner, 2026-11-13: «الخط باهت … ألوانها قريبة
              // لخلفيات الكروت»). Multiplied in, it can only darken: the pale
              // card takes the photo's texture, dark ink stays as dark.
              child: dark
                  ? Opacity(
                      opacity: 0.16,
                      child: Image.asset(
                        photo,
                        fit: BoxFit.cover,
                        cacheWidth: 900,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    )
                  : _MultiplyPhoto(photo: photo, strength: 0.16),
            ),
          ),
        ),
      ],
    );
  }
}

/// [photo] painted with [BlendMode.multiply] at [strength] over what is
/// already drawn beneath it.
class _MultiplyPhoto extends StatefulWidget {
  final String photo;
  final double strength;
  const _MultiplyPhoto({required this.photo, required this.strength});

  @override
  State<_MultiplyPhoto> createState() => _MultiplyPhotoState();
}

class _MultiplyPhotoState extends State<_MultiplyPhoto> {
  ImageStream? _stream;
  ImageInfo? _info;
  late final ImageStreamListener _listener = ImageStreamListener(
    (info, _) {
      if (!mounted) return;
      setState(() {
        _info?.dispose();
        _info = info;
      });
    },
    onError: (_, _) {},
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(_MultiplyPhoto old) {
    super.didUpdateWidget(old);
    if (old.photo != widget.photo) _resolve();
  }

  void _resolve() {
    final stream = ResizeImage(
      AssetImage(widget.photo),
      width: 900,
    ).resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _info?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _info?.image;
    if (image == null) return const SizedBox.expand();
    return CustomPaint(
      size: Size.infinite,
      painter: _MultiplyPainter(image, widget.strength),
    );
  }
}

class _MultiplyPainter extends CustomPainter {
  final ui.Image image;
  final double strength;
  _MultiplyPainter(this.image, this.strength);

  @override
  void paint(Canvas canvas, Size size) {
    paintImage(
      canvas: canvas,
      rect: Offset.zero & size,
      image: image,
      fit: BoxFit.cover,
      opacity: strength,
      blendMode: BlendMode.multiply,
    );
  }

  @override
  bool shouldRepaint(_MultiplyPainter old) =>
      old.image != image || old.strength != strength;
}
