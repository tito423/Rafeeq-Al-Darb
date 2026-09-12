/// The shells every sciences tab is built from: the async tab that turns one
/// future into a loading / empty / error / content state, the notice it shows
/// in the first three of those, and the source block that credits whichever
/// edition the content came from (§1.2 — every source gets credited).
library;

import 'dart:async';

// easy_localization re-exports package:intl, whose `TextDirection` (LTR/RTL)
// collides with the `dart:ui` enum (rtl/ltr) used throughout this file.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// Shared loading / error / empty handling for every tab.
class AsyncTab<T> extends StatelessWidget {
  final Future<T> future;
  final bool Function(T data) isEmpty;
  final Widget Function(BuildContext context, T data) builder;

  const AsyncTab({
    super.key,
    required this.future,
    required this.isEmpty,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return SciencesNotice(
            icon: Icons.error_outline,
            message: 'errors.generic'.tr(),
          );
        }
        final data = snap.data as T;
        if (isEmpty(data)) {
          return SciencesNotice(
            icon: Icons.menu_book_outlined,
            message: 'quran.no_results'.tr(),
          );
        }
        return builder(context, data);
      },
    );
  }
}

class SciencesNotice extends StatelessWidget {
  final IconData icon;
  final String message;
  const SciencesNotice({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: theme.colorScheme.outline),
          const SizedBox(height: 10),
          Text(message, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// A titled block used by the tafsir and translation tabs.
class SourceBlock extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String body;
  final TextDirection direction;

  const SourceBlock({
    super.key,
    required this.title,
    required this.body,
    required this.direction,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = AppColors.gold;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gold.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 3, height: 16, color: gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: gold, fontWeight: FontWeight.w700),
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            textDirection: direction,
            textAlign:
                direction == TextDirection.rtl ? TextAlign.right : TextAlign.left,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.75),
          ),
        ],
      ),
    );
  }
}

/// P3‑33: reverses P2‑8 #3's "view several tafsirs at once" (with an
/// optional side-by-side compare layout) — the owner didn't like it. Now:
/// one persisted dropdown, one source shown at a time, exactly mirroring
/// `TranslationTab`'s already-established "single persisted choice"
/// pattern below. Every source in `SciencesRepository.tafseerSources` is
/// bundled in `quran_sciences.db` already (no per-source download exists
/// yet — that's P3‑31's job, a separate ~20-source tafsir download section
/// still needing a licence-research pass first); once that lands, a source
/// with no data for a given ayah is the natural place to show a download
/// affordance instead of just falling back silently, as this does for now.
