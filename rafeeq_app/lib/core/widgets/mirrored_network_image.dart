import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/content_mirrors.dart';

/// A [CachedNetworkImage] that, when a host fails, asks the next mirror of
/// the same file ([ContentMirrors.of]) before giving up — and only then
/// shows [errorWidget]. A mushaf page used to fall straight to «غير متصل»
/// the moment R2 did not answer, though the same scan sat on a second host.
class MirroredNetworkImage extends StatelessWidget {
  final String url;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final int? memCacheWidth;
  final ImageWidgetBuilder? imageBuilder;
  final PlaceholderWidgetBuilder? placeholder;
  final LoadingErrorWidgetBuilder? errorWidget;

  const MirroredNetworkImage({
    super.key,
    required this.url,
    this.fit,
    this.width,
    this.height,
    this.memCacheWidth,
    this.imageBuilder,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) => _at(ContentMirrors.of(url), 0);

  Widget _at(List<String> urls, int i) => CachedNetworkImage(
        imageUrl: urls[i],
        fit: fit,
        width: width,
        height: height,
        memCacheWidth: memCacheWidth,
        imageBuilder: imageBuilder,
        placeholder: placeholder,
        errorWidget: (context, u, e) => i + 1 < urls.length
            ? _at(urls, i + 1)
            : (errorWidget?.call(context, u, e) ?? const SizedBox.shrink()),
      );
}
