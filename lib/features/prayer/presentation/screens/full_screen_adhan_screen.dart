import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

import '../../../../core/theme/theme_provider.dart';

class FullScreenAdhanScreen extends ConsumerStatefulWidget {
  final String prayerName;
  final String muezzinName;
  
  const FullScreenAdhanScreen({
    super.key,
    required this.prayerName,
    required this.muezzinName,
  });

  @override
  ConsumerState<FullScreenAdhanScreen> createState() => _FullScreenAdhanScreenState();
}

class _FullScreenAdhanScreenState extends ConsumerState<FullScreenAdhanScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _textController;
  
  int _currentSubtitleIndex = 0;
  Timer? _timer;

  // Generic Adhan subtitles with approximate timings in seconds
  final List<({int time, String text})> _subtitles = [
    (time: 0, text: "اللَّهُ أَكْبَرُ، اللَّهُ أَكْبَرُ"),
    (time: 5, text: "اللَّهُ أَكْبَرُ، اللَّهُ أَكْبَرُ"),
    (time: 11, text: "أَشْهَدُ أَنْ لَا إِلَهَ إِلَّا اللَّهُ"),
    (time: 17, text: "أَشْهَدُ أَنْ لَا إِلَهَ إِلَّا اللَّهُ"),
    (time: 23, text: "أَشْهَدُ أَنَّ مُحَمَّدًا رَسُولُ اللَّهِ"),
    (time: 29, text: "أَشْهَدُ أَنَّ مُحَمَّدًا رَسُولُ اللَّهِ"),
    (time: 35, text: "حَيَّ عَلَى الصَّلَاةِ"),
    (time: 41, text: "حَيَّ عَلَى الصَّلَاةِ"),
    (time: 47, text: "حَيَّ عَلَى الْفَلَاحِ"),
    (time: 53, text: "حَيَّ عَلَى الْفَلَاحِ"),
    (time: 60, text: "اللَّهُ أَكْبَرُ، اللَّهُ أَكْبَرُ"),
    (time: 66, text: "لَا إِلَهَ إِلَّا اللَّهُ"),
    (time: 75, text: "الصلاة خير من النوم (في الفجر فقط)"), // Just a fallback, will be omitted if not Fajr
  ];

  @override
  void initState() {
    super.initState();
    
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat(reverse: true);

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _startSubtitleTimer();
    // In a real implementation, we would start playing the Audio here
    // using just_audio and sync exactly.
  }

  void _startSubtitleTimer() {
    int elapsedSeconds = 0;
    _textController.forward();
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      elapsedSeconds++;
      
      // Check if we need to move to the next subtitle
      if (_currentSubtitleIndex < _subtitles.length - 1) {
        final nextSub = _subtitles[_currentSubtitleIndex + 1];
        if (elapsedSeconds >= nextSub.time) {
          // Fade out, change text, fade in
          _textController.reverse().then((_) {
            if (mounted) {
              setState(() {
                _currentSubtitleIndex++;
              });
              _textController.forward();
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _bgController.dispose();
    _textController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider).currentConfig;
    
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Animated Cinematic Background
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  // Base Gradient
                  Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.3),
                        radius: 1.5 + (_bgController.value * 0.2),
                        colors: [
                          theme.cardColor,
                          theme.backgroundColor,
                          Colors.black,
                        ],
                      ),
                    ),
                  ),
                  // Floating particles or glowing orbs
                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.2 + (_bgController.value * 50),
                    left: MediaQuery.of(context).size.width * 0.1 - (_bgController.value * 30),
                    child: _buildOrb(theme.primaryColor.withValues(alpha: 0.1), 200),
                  ),
                  Positioned(
                    bottom: MediaQuery.of(context).size.height * 0.1 - (_bgController.value * 40),
                    right: MediaQuery.of(context).size.width * 0.1 + (_bgController.value * 40),
                    child: _buildOrb(theme.accentColor.withValues(alpha: 0.05), 300),
                  ),
                  // Arabesque watermark
                  Center(
                    child: Transform.rotate(
                      angle: _bgController.value * 0.1,
                      child: Transform.scale(
                        scale: 1.2 + (_bgController.value * 0.1),
                        child: Icon(
                          Icons.mosque,
                          size: 300,
                          color: theme.primaryColor.withValues(alpha: 0.03),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          
          // Foreground Content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 40),
                // Top Header
                Text(
                  'حَانَ الآن مَوْعِدُ أَذَانِ',
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    color: theme.primaryColor.withValues(alpha: 0.8),
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  widget.prayerName,
                  style: GoogleFonts.reemKufi(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: theme.primaryColor.withValues(alpha: 0.5),
                        blurRadius: 20,
                      )
                    ],
                  ),
                ),
                Text(
                  'بصوت ${widget.muezzinName}',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    color: Colors.white54,
                  ),
                ),
                
                const Spacer(),
                
                // Synced Subtitles
                FadeTransition(
                  opacity: _textController,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      _subtitles[_currentSubtitleIndex].text,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.amiri(
                        fontSize: 32,
                        height: 1.8,
                        color: theme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                
                const Spacer(),
                
                // Controls
                Padding(
                  padding: const EdgeInsets.only(bottom: 60),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildControlButton(
                        icon: Icons.volume_off_rounded,
                        label: 'إيقاف الصوت',
                        color: Colors.white54,
                        onTap: () {
                          // Stop audio
                        },
                      ),
                      const SizedBox(width: 40),
                      _buildControlButton(
                        icon: Icons.close_rounded,
                        label: 'إغلاق',
                        color: Colors.redAccent,
                        isPrimary: true,
                        onTap: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isPrimary ? color.withValues(alpha: 0.2) : Colors.white10,
              shape: BoxShape.circle,
              border: Border.all(
                color: isPrimary ? color : Colors.white24,
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              size: 32,
              color: isPrimary ? color : Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: isPrimary ? color : Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}
