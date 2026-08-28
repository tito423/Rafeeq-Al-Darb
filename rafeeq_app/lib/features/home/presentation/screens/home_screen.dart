import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Home tab — time-aware greeting + quick access to the app's main sections.
class HomeScreen extends StatelessWidget {
  /// [onNavigate] is the shell tab index (1=quran, 2=azkar, 3=hadith, 4=settings).
  final void Function(int tab) onNavigate;

  const HomeScreen({super.key, required this.onNavigate});

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 12) return 'home.greeting_morning'.tr();
    if (hour >= 12 && hour < 18) return 'home.greeting_evening'.tr();
    return 'home.greeting_night'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('app.name'.tr()),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 8),
            Text(
              _greeting,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: scheme.primary,
                fontFamily: 'AmiriQuran',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'app.tagline'.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'home.quick_access'.tr(),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                _QuickCard(
                  icon: Icons.menu_book,
                  label: 'home.mushaf'.tr(),
                  onTap: () => onNavigate(1),
                ),
                _QuickCard(
                  icon: Icons.auto_awesome,
                  label: 'home.tasbeeh'.tr(),
                  onTap: () => onNavigate(2),
                ),
                _QuickCard(
                  icon: Icons.library_books,
                  label: 'new_muslim.title'.tr(),
                  onTap: () => onNavigate(3),
                ),
                _QuickCard(
                  icon: Icons.settings,
                  label: 'nav.settings'.tr(),
                  onTap: () => onNavigate(4),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: scheme.primary),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
