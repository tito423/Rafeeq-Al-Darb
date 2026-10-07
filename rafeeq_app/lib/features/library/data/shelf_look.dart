/// The colours and icons a shelf in «مكتبتي» can take. A shelf stores only
/// the index, so this list may grow but must never be reordered.
library;

import 'package:flutter/material.dart';

/// Eight grounds a reader can give a shelf. Each is a deep two-stop
/// gradient that carries white text on either app theme.
const shelfPalettes = <List<Color>>[
  [Color(0xFF0E5E55), Color(0xFF13887A)], // teal
  [Color(0xFF6B4A12), Color(0xFFB0812A)], // gold leaf
  [Color(0xFF1D3A6E), Color(0xFF3263B0)], // night blue
  [Color(0xFF5B1F3B), Color(0xFF9B3A62)], // rose
  [Color(0xFF2F4A1C), Color(0xFF5E8A36)], // olive
  [Color(0xFF3B2A6B), Color(0xFF6A51B5)], // violet
  [Color(0xFF6E2B17), Color(0xFFB2552E)], // terracotta
  [Color(0xFF263238), Color(0xFF52656F)], // slate
];

const shelfIcons = <IconData>[
  Icons.auto_stories_outlined,
  Icons.book_outlined,
  Icons.mosque_outlined,
  Icons.favorite_border_rounded,
  Icons.star_border_rounded,
  Icons.school_outlined,
  Icons.lightbulb_outline_rounded,
  Icons.nights_stay_outlined,
  Icons.local_florist_outlined,
  Icons.bookmark_border_rounded,
  Icons.history_edu_outlined,
  Icons.explore_outlined,
];
