import 'package:flutter/material.dart';

import '../data/dedication.dart';

/// Each kind's look: an icon and a colour, the same on the start card, on
/// every gift of that kind and on its counting screen.
(IconData, Color) dedicationLook(DedicationKind k) => switch (k) {
      DedicationKind.quran => (
          Icons.menu_book_rounded,
          const Color(0xFF10AC84),
        ),
      DedicationKind.istighfar => (
          Icons.self_improvement_rounded,
          const Color(0xFF2E86DE),
        ),
      DedicationKind.tasbih => (
          Icons.radio_button_checked_rounded,
          const Color(0xFF8854D0),
        ),
      DedicationKind.dua => (
          Icons.volunteer_activism_rounded,
          const Color(0xFFF79F1F),
        ),
    };
