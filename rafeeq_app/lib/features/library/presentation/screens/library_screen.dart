import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/shell/tab_request_provider.dart';
import '../../../../core/theme/app_colors.dart';
import 'books_search_screen.dart';
import '../../../hadeethenc/presentation/screens/hadeethenc_tab.dart';
import '../tabs/books_tab.dart';
import '../tabs/channels_tab.dart';
import '../tabs/hadith_tab.dart';
import '../tabs/websites_tab.dart';
import '../../../tutorial/data/tutorial_anchors.dart';
import '../../../../core/utils/screen_class.dart';
import '../../../shamela/data/shamela_import_service.dart';
import '../../../shamela/presentation/shamela_screen.dart';

/// Library — two top tabs:
///  • "الكتب المتوفرة" — the books catalog, itself split into
///    (كل الكتب · التصنيفات · مكتبتي).
///  • "الحديث" — the 9-collection hadith hub (downloaded on demand).
///  • "الموسوعة" — موسوعة الأحاديث النبوية, a separate collection whose
///    every record carries a takhrij and a grading in the reader's own
///    language, one downloadable pack per language.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

/// P3‑25: an explicit `TabController` instead of `DefaultTabController` —
/// `DownloadsScreen`'s overview rows need to jump straight to "تحميل
/// الكتب"/"الحديث" from outside this screen entirely (a separate pushed
/// route), which `DefaultTabController` has no way to reach; this exposes
/// a controller `build()` can drive from `requestedLibraryTabProvider`.
class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 5,
    vsync: this,
  );

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int?>(requestedLibraryTabProvider, (prev, next) {
      if (next == null) return;
      _tabController.animateTo(next);
      ref.read(requestedLibraryTabProvider.notifier).state = null;
    });

    // «طوّر قسم المكتبة بصريًا … التابات … أحدث وأروع بصريًا وأنيميتد».
    // Each tab is an icon and a word in a pill; the gold pill slides to
    // the chosen tab as the pages swipe (TabBar animates its indicator
    // with the controller), so the eye follows the move.
    final tabs = TutorialAnchor(
      id: TourAnchor.libraryTabs,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        splashBorderRadius: BorderRadius.circular(22),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          // White on the flat gold measured 2.42 : 1
          // (emulator-5554, 2026-09-25): same gold, deepened.
          gradient: LinearGradient(
            colors: [
              fillForWhiteText(AppColors.gold),
              fillForWhiteText(const Color(0xFFB8913A)),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
        tabs: [
          _pill(Icons.auto_stories_rounded, 'library.tab_books'.tr()),
          _pill(Icons.menu_book_rounded, 'library.tab_hadith'.tr()),
          _pill(Icons.library_books_rounded, 'library.tab_hadeethenc'.tr()),
          _pill(Icons.live_tv_rounded, 'library.tab_channels'.tr()),
          _pill(Icons.public_rounded, 'library.tab_websites'.tr()),
        ],
      ),
    );
    // SIDEWAYS THE PILLS SIT BESIDE THE TITLE. Under it, on the owner's
    // Xiaomi held sideways (2026-09-26), the title bar, this row and the
    // books tab's own row took more than half the height before the first
    // author; one row fewer gives the list 62 dp back.
    final sideways = ScreenClass.wide(context);

    return Scaffold(
      appBar: AppBar(
        //  rather than : the bottom bar's label is
        // abbreviated to fit seven tiles (see test/nav_label_width_test.dart),
        // and an AppBar has room for the whole word.
        title: sideways
            ? Row(
                children: [
                  Text('library.title'.tr()),
                  const SizedBox(width: 16),
                  Expanded(child: tabs),
                ],
              )
            : Text('library.title'.tr()),
        toolbarHeight: sideways ? 60 : null,
        bottom: sideways
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(62),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
                  child: tabs,
                ),
              ),
        actions: [
          // Shamela import: the GitHub build only (`kShamelaEnabled`).
          if (kShamelaEnabled)
            IconButton(
              tooltip: 'shamela.title'.tr(),
              icon: const Icon(Icons.travel_explore),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ShamelaScreen(),
                ),
              ),
            ),
          IconButton(
            tooltip: 'library.search_all_books'.tr(),
            icon: const Icon(Icons.manage_search),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const BooksSearchScreen(),
              ),
            ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          BooksTab(),
          HadithTab(),
          HadeethEncTab(),
          ChannelsTab(),
          WebsitesTab(),
        ],
      ),
    );
  }
}

/// One library tab: an icon and its name, padded into a pill.
/// A tab as an icon and a word inside a capsule.
///
/// «التابات عناوينها مقصوصة، ويجب أن يصغر الخط داخل الكبسولة عند اختيار خط
/// كبير حتى لا يخرج عنها». A `Tab` has a FIXED height, so at the largest
/// interface font the label grew past it and was cut off top and bottom —
/// the capsule cannot stretch to meet it. The type inside the capsule is
/// therefore clamped: the reader's chosen size still shows, up to a tenth
/// larger, and past that the capsule wins rather than the word being sliced.
/// `softWrap: false` keeps it one line; the bar scrolls sideways anyway.
Widget _pill(IconData icon, String label) => Tab(
  height: 44,
  child: MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1.1,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(label, softWrap: false, maxLines: 1),
        ],
      ),
    ),
  ),
);
