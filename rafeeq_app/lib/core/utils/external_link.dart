/// One way out of the app, and it only ever opens a web page.
///
/// Every outbound link in this app went straight to
/// `launchUrl(Uri.parse(x), mode: LaunchMode.externalApplication)`. For the
/// six call sites whose `x` is a literal in one of the app's own catalogues
/// that is fine. The seventh is not: the Library's reader opens
/// `meta.shamelaUrl`, which arrives inside a book downloaded from the content
/// bucket — and `LaunchMode.externalApplication` hands Android whatever scheme
/// the string carries. `tel:`, `sms:`, `market:` and especially `intent:` are
/// all things a URL can be, and an `intent:` URL is a request to start another
/// app's component with extras of the sender's choosing.
///
/// Nobody is putting one there today; the bucket is this project's own. But
/// "the content is ours" is the same assumption that let a book catalogue ship
/// eleven entries whose URLs had no host (trap #23), and checking a scheme
/// costs one comparison.
///
/// So: http and https only, and one place to change if that ever needs to
/// widen.
library;

import 'package:url_launcher/url_launcher.dart';

/// Opens [url] in the phone's browser. Returns false — without throwing, and
/// without launching anything — if it is not a well-formed http(s) URL.
Future<bool> openExternalLink(String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return false;
  if (uri.scheme != 'http' && uri.scheme != 'https') return false;
  if (uri.host.isEmpty) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    // No browser installed, or the OS refused. A dead link must not take the
    // screen down with it.
    return false;
  }
}
