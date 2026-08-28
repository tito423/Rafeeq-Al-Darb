import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Hadith tab — searchable library of 9 authentic collections.
class HadithScreen extends StatelessWidget {
  const HadithScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('nav.hadith'.tr())),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_books,
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
