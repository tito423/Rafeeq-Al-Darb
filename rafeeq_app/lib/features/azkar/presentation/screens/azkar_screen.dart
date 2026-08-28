import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Azkar tab — morning/evening remembrance, tasbeeh counter.
class AzkarScreen extends StatelessWidget {
  const AzkarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('nav.azkar'.tr())),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome,
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
