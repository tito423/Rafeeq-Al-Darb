import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Quran tab — Mushaf viewer with page-flip navigation.
class QuranScreen extends StatelessWidget {
  const QuranScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('nav.quran'.tr())),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text('common.coming_soon'.tr()),
          ],
        ),
      ),
    );
  }
}
