import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/sync_service.dart';
import '../../../../core/theme/app_colors.dart';

/// Offers Google sign-in once, at the end of the very first run.
///
/// «طلب تسجيل الدخول طبيعي يظهر أول مرة تثبيت». Sign-in lived only on a card
/// deep in «المزيد», so a new reader never learned their khatma and counters
/// could follow them to another device. It is offered here, at the close of
/// onboarding (which runs once per install), with «لاحقًا» as an equal
/// answer - nothing in the app needs an account.
Future<void> offerSignInOnce(BuildContext context, WidgetRef ref) async {
  if (ref.read(authStateProvider) != null) return;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.night,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold.withValues(alpha: 0.15),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
              ),
              child: const Icon(Icons.cloud_sync_rounded,
                  color: AppColors.gold, size: 30),
            ),
            const SizedBox(height: 14),
            Text('sync.sign_in_title'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('sync.sign_in_subtitle'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8), height: 1.6)),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.night,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.login_rounded),
                label: Text('sync.sign_in_title'.tr()),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(ctx);
                  try {
                    final account = await ref.read(syncServiceProvider).signIn();
                    if (account != null && ctx.mounted) Navigator.of(ctx).pop();
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(
                        content: Text('sync.sign_in_failed'
                            .tr(namedArgs: {'error': '$e'}))));
                  }
                },
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('sync.later'.tr(),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.75))),
            ),
          ],
        ),
      ),
    ),
  );
}
