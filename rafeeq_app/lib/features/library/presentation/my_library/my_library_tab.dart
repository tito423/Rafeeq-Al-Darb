/// «مكتبتي» - the reader's own shelves, as a tab of the Library.
///
/// «قسم المكتبة ده قسم مهم جدا انا عايزه جميل جدا وروعة بصريا» (owner,
/// 2026-10-07). A living header (a shelf of books that sways a little, the
/// counts beneath it), the shelves as coloured cards that rise into place
/// one after another, each with its own books standing on it, and a card to
/// start a new one. Long-press a shelf to edit it.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/hero_surface.dart';
import '../../../../core/utils/digits.dart';
import '../../data/my_shelves.dart';
import 'shelf_screen.dart';
import 'shelf_sheets.dart';
import 'shelf_style.dart';

class MyLibraryTab extends ConsumerStatefulWidget {
  const MyLibraryTab({super.key});

  @override
  ConsumerState<MyLibraryTab> createState() => _MyLibraryTabState();
}

class _MyLibraryTabState extends ConsumerState<MyLibraryTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sway = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  )..repeat();

  @override
  void dispose() {
    _sway.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final s = await showShelfEditor(context);
    if (s == null || !mounted) return;
    _openShelf(s);
  }

  void _openShelf(Shelf s) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, a, _) => FadeTransition(
          opacity: a,
          child: ShelfScreen(shelfId: s.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shelves = ref.watch(shelvesProvider);
    final width = MediaQuery.sizeOf(context).width;
    final columns = (width / 190).floor().clamp(2, 5);
    final books = <String>{for (final s in shelves) ...s.bookIds};
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _Header(
            sway: _sway,
            shelves: shelves.length,
            books: books.length,
            sample: [for (final s in shelves) ...s.bookIds],
          ),
        ),
        if (shelves.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _Welcome(onCreate: _create),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 28),
            sliver: SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.82,
              ),
              itemCount: shelves.length + 1,
              itemBuilder: (context, i) {
                if (i == shelves.length) {
                  return _Rise(
                    index: i,
                    child: _NewShelfCard(onTap: _create),
                  );
                }
                final s = shelves[i];
                return _Rise(
                  index: i,
                  child: _ShelfCard(
                    shelf: s,
                    sway: _sway,
                    onTap: () => _openShelf(s),
                    onLongPress: () => showShelfEditor(context, shelf: s),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Rises and fades in, a beat after the card before it.
class _Rise extends StatelessWidget {
  final int index;
  final Widget child;
  const _Rise({required this.index, required this.child});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: Duration(milliseconds: 450 + 70 * index.clamp(0, 10)),
    curve: Curves.easeOutBack,
    builder: (_, t, c) => Opacity(
      opacity: t.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, 30 * (1 - t)),
        child: Transform.scale(scale: 0.92 + 0.08 * t, child: c),
      ),
    ),
    child: child,
  );
}

class _Header extends StatelessWidget {
  final Animation<double> sway;
  final int shelves;
  final int books;
  final List<String> sample;
  const _Header({
    required this.sway,
    required this.shelves,
    required this.books,
    required this.sample,
  });

  @override
  Widget build(BuildContext context) {
    final surface = HeroSurface.of(context);
    final lang = context.locale.languageCode;
    // Books for the header's shelf: the reader's own once he has some, a
    // still row of placeholders' worth of spines before that.
    final spines = sample.isEmpty
        ? const ['a', 'bb', 'ccc', 'dddd', 'eeeee', 'ffffff', 'g', 'hh']
        : sample;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: surface.gradient,
        ),
        border: Border.all(color: surface.border),
        boxShadow: [
          BoxShadow(color: surface.glow, blurRadius: 22, spreadRadius: 1),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withValues(alpha: 0.18),
                ),
                child: Icon(
                  Icons.collections_bookmark_outlined,
                  color: goldText(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'shelves.tab'.tr(),
                      style: TextStyle(
                        color: surface.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      shelves == 0
                          ? 'shelves.header_empty'.tr()
                          : localizeDigits(
                              '${pluralN('shelves.count_shelves', shelves)} · '
                              '${pluralN('shelves.count_books', books)}',
                              lang,
                            ),
                      style: TextStyle(
                        color: surface.onSurfaceMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedBuilder(
            animation: sway,
            builder: (_, _) => BookSpines(
              bookIds: spines,
              base: AppColors.gold,
              max: 24,
              height: 46,
              sway: sway.value,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShelfCard extends StatelessWidget {
  final Shelf shelf;
  final Animation<double> sway;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _ShelfCard({
    required this.shelf,
    required this.sway,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = paletteOf(shelf);
    final lang = context.locale.languageCode;
    final r = shelf.reminder;
    return Hero(
      tag: 'shelf-${shelf.id}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: colors,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.last.withValues(alpha: 0.38),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                // A large faint copy of the icon, as a watermark.
                PositionedDirectional(
                  end: -14,
                  top: -10,
                  child: Icon(
                    iconOf(shelf),
                    size: 96,
                    color: Colors.white.withValues(alpha: 0.09),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                        child: Icon(iconOf(shelf), color: Colors.white),
                      ),
                      const Spacer(),
                      Text(
                        shelf.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              pluralN(
                                'shelves.count_books',
                                shelf.bookIds.length,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.82),
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                          if (r != null) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.notifications_active_outlined,
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              localizeDigits(
                                TimeOfDay(
                                  hour: r.hour,
                                  minute: r.minute,
                                ).format(context),
                                lang,
                              ),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      AnimatedBuilder(
                        animation: sway,
                        builder: (_, _) => BookSpines(
                          bookIds: shelf.bookIds,
                          base: colors.first,
                          sway: sway.value,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NewShelfCard extends StatelessWidget {
  final VoidCallback onTap;
  const _NewShelfCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final gold = goldText(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: CustomPaint(
        painter: _DashedBorder(color: gold.withValues(alpha: 0.7)),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withValues(alpha: 0.14),
                ),
                child: Icon(Icons.add_rounded, color: gold, size: 30),
              ),
              const SizedBox(height: 10),
              Text(
                'shelves.new'.tr(),
                style: TextStyle(color: gold, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  final Color color;
  _DashedBorder({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(22),
    ).deflate(1);
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 8), paint);
        d += 14;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}

class _Welcome extends StatelessWidget {
  final VoidCallback onCreate;
  const _Welcome({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'shelves.welcome_title'.tr(),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'shelves.welcome_body'.tr(),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: Text('shelves.new'.tr()),
            style: FilledButton.styleFrom(minimumSize: const Size(220, 50)),
          ),
        ],
      ),
    );
  }
}
