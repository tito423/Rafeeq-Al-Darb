import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/shell/tab_request_provider.dart';
import '../../../library/presentation/screens/library_screen.dart';

/// The library, pushed as its own route so BACK returns to التنزيلات.
///
/// «لما افتح حاجة من التنزيلات عايزها ترجعني لما اطلع منها تاني للتنزيلات
/// لان التنزيلات بتشيل البوتوم نافجيشن». The storage hub hides the bottom
/// bar, and its rows used to `popUntil(isFirst)` and switch TAB - which
/// destroys the very screen the reader was managing his storage from and
/// leaves him in the library with nothing to say where he is or how to get
/// back. A pushed route keeps the stack, so one back gesture returns.
class LibraryRoute extends ConsumerWidget {
  final int initialTab;
  const LibraryRoute({
    super.key,
    required this.initialTab,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The library reads its opening tab from the same provider the shell
    // uses, so it lands on the right one whether it is the tab or this route.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(requestedLibraryTabProvider.notifier).state = initialTab;
    });
    // The library's own AppBar is the only one: it shows the back arrow
    // itself when pushed. Wrapping it in a second Scaffold drew two bars,
    // «الكتب» over «المكتبة», each with an arrow (owner's phone, 2026-09-25).
    return const LibraryScreen();
  }
}
