import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/theme/app_colors.dart';

/// THE DESIGN IS LOCKED. Every colour the app is built out of is pinned here
/// by its exact value, so changing one fails the build.
///
/// This exists because the owner handed this repo's prompt to another agent
/// once and got the design changed underneath him: «جربت gemini pro 3.1 قبل
/// كده وغيّر في التصميم مع اني خدت البرومبت منك وادّيتهوله». A sentence in a
/// prompt asking an agent not to touch something is a request; a failing test
/// is not, and `CLAUDE.md` §2.2 forbids calling anything done while
/// `flutter test` is red.
///
/// It protects against me as much as against anyone else — a colour is easy
/// to "improve" in passing while doing something else entirely.
///
/// **If the owner asks for a colour change**, change it here in the same
/// commit and say so. That is the only way this file should ever move: a
/// deliberate edit the owner asked for, never a silent one.
void main() {
  test('the navy/gold palette is exactly what shipped', () {
    // Deep navy — scaffold, cards, sheets, hairlines.
    expect(AppColors.night, const Color(0xFF071625));
    expect(AppColors.nightElevated, const Color(0xFF0C2135));
    expect(AppColors.nightSurface, const Color(0xFF10293F));
    expect(AppColors.nightBorder, const Color(0xFF1E3A52));

    // The green the app acts in.
    expect(AppColors.primary, const Color(0xFF0E7C61));
    expect(AppColors.primarySoft, const Color(0xFF16A085));
    expect(AppColors.primaryContainer, const Color(0xFF0F3D33));

    // The gold everything Qur'anic is marked with.
    expect(AppColors.gold, const Color(0xFFD4AF37));
    expect(AppColors.goldSoft, const Color(0xFFE8C96A));
    expect(AppColors.goldContainer, const Color(0xFF3A2F14));

    // The mushaf's paper and ink.
    expect(AppColors.paper, const Color(0xFFF8F4E9));
    expect(AppColors.paperDark, const Color(0xFFEFE6D0));
    expect(AppColors.ink, const Color(0xFF241C0E));
    expect(AppColors.inkSoft, const Color(0xFF6B5D45));

    // Light theme surfaces.
    expect(AppColors.lightScaffold, const Color(0xFFF6F8F7));
    expect(AppColors.lightSurface, Colors.white);
    expect(AppColors.lightBorder, const Color(0xFFE2E8E6));

    // Status.
    expect(AppColors.success, const Color(0xFF2E9E6B));
    expect(AppColors.warning, const Color(0xFFE3A008));
    expect(AppColors.error, const Color(0xFFC0453B));
    expect(AppColors.info, const Color(0xFF2F80A9));

    // Text.
    expect(AppColors.textHigh, const Color(0xFFF2F5F4));
    expect(AppColors.textMedium, const Color(0xFFB7C4C0));
    expect(AppColors.textLow, const Color(0xFF7E908B));

    // The ayah highlight, and the brighter one for the ayah being recited.
    // These two carry an alpha on purpose: a translucent highlight over a
    // dark ground composites dark, which is trap 15 in CLAUDE.md — do not
    // "fix" the alpha without recomputing the contrast ratio.
    expect(AppColors.ayahHighlight, const Color(0x5D16A085));
    expect(AppColors.ayahHighlightPlaying, const Color(0x5DD4AF37));
  });
}
