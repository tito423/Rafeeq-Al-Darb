import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The app's own screens, as pictures, inside «شرح ميزات واستخدام التطبيق».
///
/// «حط بالله الصور بتاعة البلاي استور في شرح ميزات التطبيق» — asked three
/// times. Until now that card offered two guided tours and nothing to look
/// at; someone who wants to know what the app HAS had to walk a tour to
/// find out.
///
/// These are the eight Play-Store shots from `store/google_play/
/// screenshots/phone/`, the same pictures, resized once to 540×960 JPEG:
/// 6.70 MB of PNG became 0.42 MB, which is a price the install can pay.
/// Regenerate them with `scripts/build_tutorial_shots.py` if the store set
/// is ever reshot.
///
/// The captions are keys the app already has - the tab names and the two
/// section titles - rather than eight new strings in seven languages that
/// would only ever repeat them.
class FeatureGalleryScreen extends StatelessWidget {
  const FeatureGalleryScreen({super.key});

  static const _shots = <(String, String)>[
    ('01_home', 'nav.home'),
    ('02_mushaf', 'nav.quran'),
    ('03_adhan', 'nav.prayer'),
    ('04_azkar', 'nav.azkar'),
    ('05_hadith', 'nav.hadith'),
    ('06_tajweed', 'tajweed.title'),
    ('07_hajj', 'hajj.title'),
    ('08_more', 'nav.more'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('tutorial.card_title'.tr())),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _shots.length,
        separatorBuilder: (_, _) => const SizedBox(height: 18),
        itemBuilder: (context, i) {
          final (file, labelKey) = _shots[i];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
                child: Text(
                  labelKey.tr(),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.30)),
                    borderRadius: BorderRadius.circular(18),
                    color: scheme.surface,
                  ),
                  // The shots are 540×960 - a phone's own shape - so the
                  // frame takes that shape rather than guessing one.
                  child: AspectRatio(
                    aspectRatio: 540 / 960,
                    child: Image.asset(
                      'assets/tutorial_shots/$file.jpg',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
