import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/adhan_sync_data.dart';

// Global player so audio continues if screen is dismissed
final AudioPlayer globalAdhanPlayer = AudioPlayer();

Future<void> playAdhanInBackground(String prayerName, String muezzinName) async {
  try {
    String assetName = 'minshawi';
    if (muezzinName.contains('مكة')) assetName = 'minshawi'; // Fallback
    else if (muezzinName.contains('عبد الباسط')) assetName = 'abdulbasit';
    else if (muezzinName.contains('المنشاوي')) assetName = 'minshawi';
    else if (muezzinName.contains('مشاري') || muezzinName.contains('العفاسي')) assetName = 'mishary';
    else if (muezzinName.contains('مصطفى') || muezzinName.contains('اسماعيل')) assetName = 'mustafa_ismail';
    else if (muezzinName.contains('حافظ')) assetName = 'abdulbasit'; // Fallback
    else if (muezzinName.contains('الحسيني')) assetName = 'mustafa_ismail'; // Fallback

    await globalAdhanPlayer.setAudioSource(
      AudioSource.uri(
        Uri.parse('asset:///assets/audio/$assetName.m4a'),
        tag: MediaItem(
          id: 'adhan_$assetName',
          title: 'أذان $prayerName',
          artist: muezzinName,
        ),
      ),
    );
    globalAdhanPlayer.play();
  } catch (e) {
    debugPrint("Background adhan play failed: $e");
  }
}

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
  late AnimationController _rgbController;
  
  int _activePhraseIndex = 0;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    
    // Spinning RGB Border Controller
    _rgbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _setupAudioStreams();
    _startAdhan();
  }

  void _setupAudioStreams() {
    globalAdhanPlayer.positionStream.listen((pos) {
      if (mounted) {
        setState(() {
          _position = pos;
          _updateActivePhrase();
        });
      }
    });
    
    globalAdhanPlayer.durationStream.listen((dur) {
      if (mounted && dur != null) {
        setState(() {
          _duration = dur;
        });
      }
    });

    globalAdhanPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (mounted) Navigator.pop(context);
      }
    });
  }

  void _updateActivePhrase() {
    bool isFajr = widget.prayerName.contains('الفجر');
    final newIndex = AdhanSyncData.getActivePhraseIndex(_position, _duration, isFajr);
    if (newIndex != _activePhraseIndex) {
      _activePhraseIndex = newIndex;
    }
  }

  Future<void> _startAdhan() async {
    try {
      // Map muezzin name to the local m4a asset
      String assetName = 'minshawi'; // Default to a guaranteed local asset
      if (widget.muezzinName.contains('مكة')) assetName = 'minshawi'; // Fallback
      else if (widget.muezzinName.contains('عبد الباسط')) assetName = 'abdulbasit';
      else if (widget.muezzinName.contains('المنشاوي')) assetName = 'minshawi';
      else if (widget.muezzinName.contains('مشاري') || widget.muezzinName.contains('العفاسي')) assetName = 'mishary';
      else if (widget.muezzinName.contains('مصطفى') || widget.muezzinName.contains('اسماعيل')) assetName = 'mustafa_ismail';
      else if (widget.muezzinName.contains('حافظ')) assetName = 'abdulbasit'; // Fallback
      else if (widget.muezzinName.contains('الحسيني')) assetName = 'mustafa_ismail'; // Fallback

      // We use local assets downloaded by yt-dlp
      await globalAdhanPlayer.setAudioSource(
        AudioSource.uri(
          Uri.parse('asset:///assets/audio/$assetName.m4a'),
          tag: MediaItem(
            id: 'adhan_$assetName',
            title: 'أذان ${widget.prayerName}',
            artist: widget.muezzinName,
          ),
        ),
      );
      globalAdhanPlayer.play();
    } catch (e) {
      debugPrint("Could not play adhan audio from assets, trying fallback... $e");
      try {
        await globalAdhanPlayer.setAudioSource(
          AudioSource.uri(
            Uri.parse('https://download.quranicaudio.com/adhan/makkah.mp3'),
            tag: MediaItem(
              id: 'adhan_fallback',
              title: 'أذان ${widget.prayerName}',
              artist: widget.muezzinName,
            ),
          ),
        );
        globalAdhanPlayer.play();
      } catch (e2) {
        debugPrint("Fallback failed: $e2");
      }
    }
  }

  @override
  void dispose() {
    _rgbController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const goldColor = Color(0xFFD4AF37);
    const darkGreen = Color(0xFF0A1F16);
    
    bool isFajr = widget.prayerName.contains('الفجر');
    final phrases = isFajr ? AdhanSyncData.fajrAdhan : AdhanSyncData.standardAdhan;
    final currentPhrase = phrases[_activePhraseIndex].text;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Blurred Background
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
            child: Container(
              color: Colors.black.withValues(alpha: 0.6),
            ),
          ),
          
          // 2. Center Animated RGB Card
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: AnimatedBuilder(
                animation: _rgbController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // RGB Rotating Glow
                        ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: Transform.rotate(
                            angle: _rgbController.value * 2 * math.pi,
                            child: Container(
                              width: double.maxFinite,
                              height: 600, // Large enough to cover rotation corners
                              decoration: const BoxDecoration(
                                gradient: SweepGradient(
                                  colors: [
                                    Color(0xFFFF0000), // Red
                                    Color(0xFFFF7F00), // Orange
                                    Color(0xFFFFFF00), // Yellow
                                    Color(0xFF00FF00), // Green
                                    Color(0xFF0000FF), // Blue
                                    Color(0xFF4B0082), // Indigo
                                    Color(0xFF8B00FF), // Violet
                                    Color(0xFFFF0000), // Red (close loop)
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                        // Inner Dark Green Card
                        Container(
                          margin: const EdgeInsets.all(3.0), // Border thickness for the RGB glow
                          decoration: BoxDecoration(
                            color: darkGreen,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: goldColor.withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Header: Prayer Name
                                Text(
                                  'أذان ${widget.prayerName}',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.scheherazadeNew(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: goldColor,
                                  ),
                                ),
                                Text(
                                  'بصوت ${widget.muezzinName}',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.cairo(
                                    fontSize: 14,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                
                                // Karaoke Sync Area
                                SizedBox(
                                  height: 180,
                                  child: Center(
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 500),
                                      transitionBuilder: (Widget child, Animation<double> animation) {
                                        return FadeTransition(
                                          opacity: animation,
                                          child: ScaleTransition(
                                            scale: animation,
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: Text(
                                        currentPhrase,
                                        key: ValueKey<int>(_activePhraseIndex),
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.amiri(
                                          fontSize: 34,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          height: 1.5,
                                          shadows: [
                                            Shadow(
                                              color: goldColor.withValues(alpha: 0.8),
                                              blurRadius: 20,
                                            )
                                          ]
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                
                                // Progress Bar
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: _duration.inMilliseconds > 0 
                                          ? _position.inMilliseconds / _duration.inMilliseconds 
                                          : 0,
                                      backgroundColor: Colors.white24,
                                      color: goldColor,
                                      minHeight: 6,
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Action Buttons
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Stop Button
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          globalAdhanPlayer.stop();
                                          Navigator.pop(context);
                                        },
                                        icon: const Icon(Icons.stop_circle_rounded, color: Colors.black87),
                                        label: Text(
                                          'إيقاف',
                                          style: GoogleFonts.cairo(
                                            color: Colors.black87,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: goldColor,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(24),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    // Background Button
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          Navigator.pop(context); 
                                          // Keep playing in background (since we are just popping the screen, 
                                          // but wait, popping the screen calls dispose() which disposes the player!
                                          // So actually popping WILL stop the audio because of dispose().
                                          // To truly keep it in background, we need a global Adhan service.
                                          // For now, this is labeled "إغلاق الشاشة" (Close Screen).
                                        },
                                        icon: const Icon(Icons.close_fullscreen_rounded, color: goldColor),
                                        label: Text(
                                          'إغلاق',
                                          style: GoogleFonts.cairo(
                                            color: goldColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: goldColor, width: 1.5),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(24),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
