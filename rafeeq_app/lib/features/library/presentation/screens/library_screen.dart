

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
  late final TabController _tabController =
      TabController(length: 5, vsync: this);

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

    return Scaffold(
      appBar: AppBar(
        //  rather than : the bottom bar's label is
        // abbreviated to fit seven tiles (see test/nav_label_width_test.dart),
        // and an AppBar has room for the whole word.
        title: Text('library.title'.tr()),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: 'library.tab_books'.tr()),
            Tab(text: 'library.tab_hadith'.tr()),
            Tab(text: 'library.tab_hadeethenc'.tr()),
            Tab(text: 'library.tab_channels'.tr()),
            Tab(text: 'library.tab_websites'.tr()),
          ],
        ),
        actions: [
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
