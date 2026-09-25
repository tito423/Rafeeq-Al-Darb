import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;

import '../../../../core/utils/user_error.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/islamic_action_card.dart';

class SyncAccountCard extends ConsumerStatefulWidget {
  const SyncAccountCard({super.key});

  @override
  ConsumerState<SyncAccountCard> createState() => _SyncAccountCardState();
}

class _SyncAccountCardState extends ConsumerState<SyncAccountCard> with SingleTickerProviderStateMixin {
  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;
  bool _showingDetails = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutBack),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _toggleCard() {
    if (_flipController.isAnimating) return;
    if (_showingDetails) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() => _showingDetails = !_showingDetails);
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(authStateProvider);
    final status = 'sync.status_${ref.watch(syncStatusProvider).name}'.tr();

    // If not logged in, just show the normal card
    if (account == null) {
      return IslamicActionCard(
        icon: Icons.sync,
        accent: AppColors.info,
        title: 'sync.sign_in_title'.tr(),
        subtitle: 'sync.sign_in_subtitle'.tr(),
        // Awaited, and its failure said out loud. The first cut called
        // `signIn()` and dropped the future on the floor, so a sign-in that
        // threw looked identical to a button that was not wired to anything
        // — «بضغط عليه مش بيعمل حاجة». A tap must always answer: it signs
        // in, or it says why it could not.
        onTap: () async {
          final messenger = ScaffoldMessenger.of(context);
          try {
            final account = await ref.read(syncServiceProvider).signIn();
            if (account == null) return; // the reader closed Google's sheet
          } catch (e) {
            messenger.showSnackBar(
              SnackBar(
                content: Text('sync.sign_in_failed'
                    .tr(namedArgs: {'error': userErrorText(e)})),
              ),
            );
          }
        },
      );
    }

    // Logged in: Animated flip card
    return AnimatedBuilder(
      animation: _flipAnimation,
      builder: (context, child) {
        final angle = _flipAnimation.value * math.pi;
        final isFront = angle < math.pi / 2;

        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // perspective
            ..rotateX(angle),
          alignment: Alignment.center,
          child: isFront
              ? IslamicActionCard(
                  icon: Icons.cloud_done,
                  accent: AppColors.success,
                  title: account.displayName ?? account.email,
                  subtitle: status,
                  onTap: _toggleCard,
                )
              : Transform(
                  transform: Matrix4.identity()..rotateX(math.pi),
                  alignment: Alignment.center,
                  // The theme's own container and its "on" colour. It was the
                  // fixed dark green of the dark palette with the theme's
                  // text on it, so in the light theme the name was dark on
                  // dark (owner's phone, 2026-09-25).
                  child: Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundImage: account.photoUrl != null ? NetworkImage(account.photoUrl!) : null,
                                child: account.photoUrl == null ? const Icon(Icons.person) : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      account.displayName ?? '',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          color: Theme.of(context).colorScheme.onPrimaryContainer),
                                    ),
                                    Text(
                                      account.email,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onPrimaryContainer),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                    foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer),
                                onPressed: _toggleCard,
                                icon: const Icon(Icons.arrow_upward),
                                label: Text('sync.hide'.tr()),
                              ),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                                onPressed: () {
                                  ref.read(syncServiceProvider).signOut();
                                  _toggleCard();
                                },
                                icon: const Icon(Icons.logout),
                                label: Text('sync.sign_out'.tr()),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}
