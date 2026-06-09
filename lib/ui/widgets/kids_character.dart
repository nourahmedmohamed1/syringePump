// lib/ui/widgets/kids_character.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/constants/app_colors.dart';
import '../../core/models/hr_reading.dart';
import 'elephant_painter.dart';
import 'heart_rate_wave.dart';

class KidsCharacter extends StatefulWidget {
  final double progress;
  final double flowRatio;
  final VoidCallback onClose;
  final List<HrReading> hrReadings;
  final double latestBpm;
  final bool isIdle;

  const KidsCharacter({
    super.key,
    required this.progress,
    required this.flowRatio,
    required this.onClose,
    this.hrReadings = const [],
    this.latestBpm = 72,
    this.isIdle = false,
  });

  @override
  State<KidsCharacter> createState() => _KidsCharacterState();
}

class _KidsCharacterState extends State<KidsCharacter>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _bounceController;
  late AnimationController _earController;
  late AnimationController _trunkController;
  late AnimationController _blinkController;
  late AnimationController _breatheController;
  late AnimationController _starController;

  // Page & language
  int _currentPage = 0;
  bool _isArabic = false;

  // TTS + Speech
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isSpeaking = false;
  String _userSpokenText = '';
  String _ellieReply = '';
  int _speechIndex = 0;

  // Game 3 state (Catch the Drops)
  List<_FallingDrop> _drops = [];
  int _gameScore = 0;
  int _gameLives = 3;
  bool _gameActive = false;
  late AnimationController _gameTickController;

  // Game 4 state (Memory Match)
  List<_MemoryCard> _memCards = [];
  int? _firstFlipIdx;
  bool _memLocked = false;
  int _memMatches = 0;
  bool _memGameOver = false;
  int _memMoves = 0;

  // Messages (English + Arabic)
  static const _messagesEn = [
    "You're doing great! 💪",
    "I'm right here with you! 💜",
    "Take a deep breath... 🌬️",
    "You're so brave! 🌟",
    "Almost like magic! ✨",
    "Let's count stars together! ⭐",
    "You're my hero! 🦸",
    "Ellie loves you! 🐘💕",
    "Think of your favorite toy! 🧸",
    "Imagine flying with clouds! ☁️",
  ];

  static const _messagesAr = [
    "أنت رائع جداً! 💪",
    "أنا هنا معك! 💜",
    "خذ نفس عميق... 🌬️",
    "أنت شجاع جداً! 🌟",
    "مثل السحر تماماً! ✨",
    "هيا نعد النجوم معاً! ⭐",
    "أنت بطلي! 🦸",
    "إيلي تحبك! 🐘💕",
    "فكر بلعبتك المفضلة! 🧸",
    "تخيل أنك تطير مع الغيوم! ☁️",
  ];

  List<String> get _messages => _isArabic ? _messagesAr : _messagesEn;

  @override
  void initState() {
    super.initState();
    // Sync bounce with heartbeat BPM
    final beatMs = _bpmToMs(widget.latestBpm);
    _bounceController = AnimationController(
        vsync: this, duration: Duration(milliseconds: beatMs))
      ..repeat(reverse: true);
    _earController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _trunkController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2500))
      ..repeat(reverse: true);
    _blinkController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _startBlinkCycle();
    _breatheController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3500))
      ..repeat(reverse: true);
    _starController = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _gameTickController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 50))
      ..addListener(_gameTick);
    _initTts();
    _startSpeechCycle();
  }

  /// Convert BPM to milliseconds per beat for animation sync.
  int _bpmToMs(double bpm) {
    if (bpm <= 0 || bpm > 300) return 833; // fallback ~72 BPM
    return (60000 / bpm).round().clamp(200, 3000);
  }

  @override
  void didUpdateWidget(KidsCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Dynamically sync bounce animation to latest BPM
    if ((oldWidget.latestBpm - widget.latestBpm).abs() > 3) {
      final newMs = _bpmToMs(widget.latestBpm);
      _bounceController.duration = Duration(milliseconds: newMs);
      if (!_bounceController.isAnimating) {
        _bounceController.repeat(reverse: true);
      }
    }
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setPitch(1.5);
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(0.8);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  Future<void> _ellieSpeak(String text) async {
    final cleanText = text.replaceAll(RegExp(r'[\u{1F600}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{FE00}-\u{FEFF}]|[\u{1F000}-\u{1FFFF}]', unicode: true), '').trim();
    if (cleanText.isEmpty) return;
    await _tts.setLanguage(_isArabic ? 'ar' : 'en-US');
    setState(() => _isSpeaking = true);
    await _tts.speak(cleanText);
  }

  void _startSpeechCycle() async {
    while (mounted) {
      await Future.delayed(const Duration(seconds: 6));
      if (!mounted) return;
      if (_currentPage == 0) {
        setState(() {
          _speechIndex = (_speechIndex + 1) % _messages.length;
        });
        _ellieSpeak(_messages[_speechIndex]);
      }
    }
  }

  void _startBlinkCycle() async {
    while (mounted) {
      await Future.delayed(
          Duration(milliseconds: 2500 + Random().nextInt(3000)));
      if (!mounted) return;
      await _blinkController.forward();
      await _blinkController.reverse();
    }
  }

  // ── Talk to Ellie (Talking Tom style) ──
  Future<void> _startListening() async {
    bool available = await _speech.initialize(
      onError: (_) {
        if (mounted) setState(() => _isListening = false);
      },
    );
    if (!available) return;

    setState(() {
      _isListening = true;
      _userSpokenText = '';
      _ellieReply = '';
    });
    await _tts.stop();

    _speech.listen(
      localeId: _isArabic ? 'ar_SA' : 'en_US',
      onResult: (result) {
        if (mounted) {
          setState(() => _userSpokenText = result.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 6),
      pauseFor: const Duration(seconds: 2),
    );

    Future.delayed(const Duration(seconds: 6), () {
      if (!mounted) return;
      _speech.stop();
      setState(() => _isListening = false);

      if (_userSpokenText.isNotEmpty) {
        setState(() => _ellieReply = _userSpokenText);
        _ellieSpeak(_userSpokenText);
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) setState(() => _ellieReply = '');
        });
      }
    });
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _earController.dispose();
    _trunkController.dispose();
    _blinkController.dispose();
    _breatheController.dispose();
    _starController.dispose();
    _gameTickController.dispose();
    _tts.stop();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCelebrating = widget.progress >= 1.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D0D2B), Color(0xFF1A1040), Color(0xFF2D1B69)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Top bar ──
              _buildTopBar(),
              // ── Language toggle + Page tabs ──
              _buildTabBar(),
              const SizedBox(height: 8),
              // ── Main content + bottom sections ──
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      // Page content
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.45,
                        child: _currentPage == 0
                            ? _buildEllieSpeaksPage(isCelebrating)
                            : _currentPage == 1
                                ? _buildTalkToElliePage(isCelebrating)
                                : _currentPage == 2
                                    ? _buildGamePage()
                                    : _buildMemoryMatchPage(),
                      ),
                      // ── Syringe progress ──
                      if (_currentPage < 2) _buildProgressSection(),
                      // ── Fun HR graph (kids style) ──
                      if (_currentPage < 2 && widget.hrReadings.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: HeartRateWave(
                            buffer: const [],
                            currentHR: widget.latestBpm,
                            hrReadings: widget.hrReadings,
                            kidsMode: true,
                          ),
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  TOP BAR
  // ═══════════════════════════════════════════
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 22),
            onPressed: widget.onClose,
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.kidsPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.kidsPrimary.withValues(alpha: 0.3)),
            ),
            child: Text(
              '🐘 ${_isArabic ? "وضع الأطفال" : "Kids Mode"}',
              style: GoogleFonts.outfit(
                color: AppColors.kidsPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          const Spacer(),
          // Language toggle
          GestureDetector(
            onTap: () {
              setState(() => _isArabic = !_isArabic);
              _tts.stop();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _isArabic ? 'EN' : 'عربي',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  TAB BAR
  // ═══════════════════════════════════════════
  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _tabButton(
              index: 0,
              icon: Icons.record_voice_over,
              label: _isArabic ? 'إيلي' : 'Ellie',
            ),
            _tabButton(
              index: 1,
              icon: Icons.mic,
              label: _isArabic ? 'كلّم' : 'Talk',
            ),
            _tabButton(
              index: 2,
              icon: Icons.catching_pokemon_rounded,
              label: _isArabic ? 'صيد' : 'Catch',
            ),
            _tabButton(
              index: 3,
              icon: Icons.grid_view_rounded,
              label: _isArabic ? 'ذاكرة' : 'Memory',
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(
      {required int index, required IconData icon, required String label}) {
    final selected = _currentPage == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentPage = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.kidsPrimary.withValues(alpha: 0.25)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: selected ? AppColors.kidsPrimary : Colors.white38),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.kidsPrimary : Colors.white38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  PAGE 1: ELLIE SPEAKS (auto messages + TTS)
  // ═══════════════════════════════════════════
  Widget _buildEllieSpeaksPage(bool isCelebrating) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Breathing guide
        AnimatedBuilder(
          animation: _breatheController,
          builder: (context, _) {
            final phase = _breatheController.value;
            String guide;
            if (_isArabic) {
              guide = phase < 0.4 ? 'تنفس مع إيلي... 🌬️' : phase < 0.6 ? 'إمسك... ⭐' : 'أخرج ببطء... 💨';
            } else {
              guide = phase < 0.4 ? 'Breathe in with Ellie... 🌬️' : phase < 0.6 ? 'Hold... ⭐' : 'Breathe out slowly... 💨';
            }
            return Text(
              guide,
              style: GoogleFonts.outfit(
                color: AppColors.kidsSky.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        // Speech bubble + elephant
        _buildElephantWithBubble(
          bubbleText: _messages[_speechIndex % _messages.length],
          isCelebrating: isCelebrating,
        ),
        const SizedBox(height: 12),
        // Encouraging message
        Text(
          _getProgressMessage(),
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  //  PAGE 2: TALK TO ELLIE (mic + repeat)
  // ═══════════════════════════════════════════
  Widget _buildTalkToElliePage(bool isCelebrating) {
    String bubbleText;
    if (_ellieReply.isNotEmpty) {
      bubbleText = '🐘 "$_ellieReply"';
    } else if (_isListening) {
      bubbleText = _userSpokenText.isNotEmpty
          ? '🎤 "$_userSpokenText"'
          : (_isArabic ? '🎤 أستمع...' : '🎤 Listening...');
    } else {
      bubbleText = _isArabic
          ? 'اضغط على الزر وتكلم! 🎤'
          : 'Press the button and talk! 🎤';
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Elephant + speech bubble
        _buildElephantWithBubble(
          bubbleText: bubbleText,
          isCelebrating: isCelebrating,
          bubbleColor: _isListening
              ? AppColors.kidsPrimary.withValues(alpha: 0.25)
              : null,
        ),
        const SizedBox(height: 20),
        // Mic button
        GestureDetector(
          onTap: _isListening ? null : _startListening,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: _isListening
                    ? [AppColors.kidsPrimary, AppColors.kidsAccent]
                    : [Colors.white.withValues(alpha: 0.15), Colors.white.withValues(alpha: 0.05)],
              ),
              border: Border.all(
                color: _isListening
                    ? AppColors.kidsPrimary
                    : Colors.white.withValues(alpha: 0.2),
                width: 2,
              ),
              boxShadow: _isListening
                  ? [BoxShadow(color: AppColors.kidsPrimary.withValues(alpha: 0.4), blurRadius: 24)]
                  : [],
            ),
            child: Icon(
              _isListening ? Icons.hearing : Icons.mic_rounded,
              color: _isListening ? Colors.white : Colors.white70,
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _isListening
              ? (_isArabic ? 'إيلي تسمعك...' : 'Ellie is listening...')
              : (_isArabic ? 'اضغط لتكلم إيلي 🎤' : 'Tap to talk to Ellie 🎤'),
          style: GoogleFonts.outfit(
            color: _isListening ? AppColors.kidsPrimary : Colors.white60,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  //  SHARED: Elephant + bubble
  // ═══════════════════════════════════════════
  Widget _buildElephantWithBubble({
    required String bubbleText,
    required bool isCelebrating,
    Color? bubbleColor,
  }) {
    return SizedBox(
      height: 250,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Speech bubble
          Positioned(
            top: 0,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 240),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: bubbleColor ??
                          Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.kidsPrimary.withValues(alpha: 0.1),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Text(
                      bubbleText,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  CustomPaint(
                    size: const Size(20, 10),
                    painter: _BubbleTailPainter(
                        color: bubbleColor ??
                            Colors.white.withValues(alpha: 0.15)),
                  ),
                ],
              ),
            ),
          ),
          // Elephant
          Positioned(
            bottom: 0,
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _bounceController,
                  _earController,
                  _trunkController,
                  _blinkController,
                  _breatheController,
                ]),
                builder: (context, _) {
                  return SizedBox(
                    width: 180,
                    height: 180,
                    child: CustomPaint(
                      painter: ElephantPainter(
                        bounce: Curves.easeInOut
                            .transform(_bounceController.value),
                        earFlap: Curves.easeInOut
                            .transform(_earController.value),
                        trunkSway:
                            sin(_trunkController.value * pi * 2) *
                                (isCelebrating ? 0.3 : 1.0),
                        blinkAmount: _blinkController.value,
                        breathe: Curves.easeInOut
                            .transform(_breatheController.value),
                        celebrate: isCelebrating ? 1.0 : 0.0,
                      ),
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

  // ═══════════════════════════════════════════
  //  SHARED: Progress section (bottom)
  // ═══════════════════════════════════════════
  Widget _buildProgressSection() {
    final isIdle = widget.isIdle;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          // Progress bar
          Container(
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withValues(alpha: 0.08),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  if (isIdle)
                    // Animated shimmer for idle state
                    AnimatedBuilder(
                      animation: _starController,
                      builder: (_, __) => FractionallySizedBox(
                        widthFactor:
                            0.15 + (_starController.value * 0.05),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              AppColors.kidsSky.withValues(alpha: 0.4),
                              AppColors.kidsPrimary.withValues(alpha: 0.2),
                            ]),
                          ),
                        ),
                      ),
                    )
                  else
                    FractionallySizedBox(
                      widthFactor: widget.progress.clamp(0, 1),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [
                            AppColors.kidsPrimary,
                            AppColors.kidsAccent,
                            AppColors.kidsGreen,
                          ]),
                        ),
                      ),
                    ),
                  Center(
                    child: Text(
                      isIdle
                          ? (_isArabic ? 'في انتظار الحقنة...' : 'Waiting for infusion...')
                          : '${(widget.progress * 100).toStringAsFixed(0)}%',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (!isIdle) ...[
            // Star milestones
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [0.25, 0.5, 0.75, 1.0].map((m) {
                final achieved = widget.progress >= m;
                return Column(
                  children: [
                    AnimatedBuilder(
                      animation: _starController,
                      builder: (_, __) => Transform.scale(
                        scale: achieved
                            ? 1.0 + _starController.value * 0.15
                            : 0.8,
                        child: Text(
                          achieved ? '⭐' : '☆',
                          style: TextStyle(
                            fontSize: 18,
                            color: achieved
                                ? null
                                : Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ),
                    Text(
                      '${(m * 100).toInt()}%',
                      style: GoogleFonts.outfit(
                        color: achieved
                            ? AppColors.kidsPrimary
                            : Colors.white.withValues(alpha: 0.3),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Text(
              '${(widget.progress * 100).toStringAsFixed(0)}%',
              style: GoogleFonts.outfit(
                color: AppColors.kidsGreen,
                fontWeight: FontWeight.w900,
                fontSize: 44,
                letterSpacing: -2,
              ),
            ),
            Text(
              _isArabic ? 'تم توصيل الدواء' : 'medicine delivered',
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              _isArabic
                  ? 'إيلي جاهزة! العب أو تكلم معها 🐘'
                  : "Ellie is ready! Play or chat while you wait 🐘",
              style: GoogleFonts.outfit(
                color: AppColors.kidsSky.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  String _getProgressMessage() {
    if (_isArabic) {
      if (widget.progress >= 1.0) return 'إيلي تقول: أحسنت! 🎉';
      if (widget.progress >= 0.75) return 'قربنا نخلص! شجاع! 🌟';
      if (widget.progress >= 0.5) return 'نصف الطريق! إيلي فخورة! 🐘';
      if (widget.progress >= 0.25) return 'بداية رائعة! كمّل! ⭐';
      return 'إيلي معك! 💜';
    }
    if (widget.progress >= 1.0) return 'Ellie says: You did it! 🎉';
    if (widget.progress >= 0.75) return 'Almost there! So brave! 🌟';
    if (widget.progress >= 0.5) return 'Halfway! Ellie is proud! 🐘';
    if (widget.progress >= 0.25) return 'Great start! Keep going! ⭐';
    return 'Ellie is here with you! 💜';
  }

  // ═══════════════════════════════════════════
  //  GAME: "Catch the Drops" (kid-friendly)
  // ═══════════════════════════════════════════
  List<_Sparkle> _sparkles = [];

  void _startGame() {
    setState(() {
      _gameScore = 0;
      _gameLives = 5;
      _drops = [];
      _sparkles = [];
      _gameActive = true;
    });
    _gameTickController.repeat();
  }

  void _gameTick() {
    if (!_gameActive || !mounted) return;
    final rng = Random();
    final w = MediaQuery.of(context).size.width;
    // Spawn drops slowly
    if (rng.nextInt(20) == 0) {
      _drops.add(_FallingDrop(
        x: 40 + rng.nextDouble() * (w - 100),
        y: -30,
        speed: 0.7 + rng.nextDouble() * 0.6,
        emoji: ['💧', '💊', '🩹', '⭐', '🌟'][rng.nextInt(5)],
        wobble: rng.nextDouble() * pi * 2,
      ));
    }
    setState(() {
      for (final d in _drops) {
        d.y += d.speed;
        d.wobble += 0.05;
        d.x += sin(d.wobble) * 0.4;
      }
      _sparkles = _sparkles.where((s) => s.life > 0).toList();
      for (final s in _sparkles) { s.x += s.dx; s.y += s.dy; s.life -= 2; }
      final missed = _drops.where((d) => d.y > MediaQuery.of(context).size.height - 220).toList();
      for (final d in missed) { _gameLives--; _drops.remove(d); }
      if (_gameLives <= 0) {
        _gameActive = false;
        _gameTickController.stop();
        _ellieSpeak(_isArabic ? 'أحسنت! لعبت حلو!' : 'Great job! Well played!');
      }
    });
  }

  void _tapDrop(_FallingDrop drop) {
    final rng = Random();
    for (int i = 0; i < 6; i++) {
      _sparkles.add(_Sparkle(
        x: drop.x, y: drop.y,
        dx: (rng.nextDouble() - 0.5) * 4, dy: (rng.nextDouble() - 0.5) * 4,
        life: 40 + rng.nextInt(30),
        emoji: ['✨', '⭐', '💫', '🌟'][rng.nextInt(4)],
      ));
    }
    setState(() { _drops.remove(drop); _gameScore++; });
    if (_gameScore % 3 == 0) {
      final cheers = _isArabic
          ? ['يا بطل!', 'رائع!', 'ممتاز!', 'أحسنت!']
          : ['Amazing!', 'Superstar!', 'Wow!', 'Awesome!'];
      _ellieSpeak(cheers[rng.nextInt(cheers.length)]);
    }
  }

  Widget _buildGamePage() {
    if (!_gameActive) {
      return Center(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_gameScore > 0 ? '🎉' : '🐘', style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 12),
          Text(_gameScore > 0 ? (_isArabic ? 'أحسنت يا بطل!' : 'Great job!') : (_isArabic ? 'ساعد إيلي!' : 'Help Ellie!'),
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 28)),
          if (_gameScore > 0) ...[const SizedBox(height: 8), Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(color: AppColors.kidsGreen.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
            child: Text(_isArabic ? '⭐ مسكت $_gameScore ⭐' : '⭐ Caught $_gameScore ⭐',
              style: GoogleFonts.outfit(color: AppColors.kidsGreen, fontWeight: FontWeight.w700, fontSize: 18)))],
          const SizedBox(height: 16),
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _instrStep('💧', _isArabic ? 'قطرات' : 'Drops'),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('→', style: TextStyle(color: Colors.white30, fontSize: 20))),
              _instrStep('👆', _isArabic ? 'اضغط' : 'Tap'),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('→', style: TextStyle(color: Colors.white30, fontSize: 20))),
              _instrStep('🧪', _isArabic ? 'إملأ' : 'Fill'),
            ])),
          const SizedBox(height: 28),
          GestureDetector(onTap: _startGame, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.kidsPrimary, AppColors.kidsAccent]),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [BoxShadow(color: AppColors.kidsPrimary.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, 6))]),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('▶', style: TextStyle(fontSize: 20, color: Colors.white)),
              const SizedBox(width: 10),
              Text(_gameScore > 0 ? (_isArabic ? 'مرة ثانية!' : 'Again!') : (_isArabic ? 'يلا نلعب!' : "Let's Play!"),
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
            ]))),
        ])));
    }
    return Stack(children: [
      Positioned(top: 8, left: 16, right: 16, child: Row(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.kidsSky.withValues(alpha: 0.25), AppColors.kidsSky.withValues(alpha: 0.1)]),
            borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.kidsSky.withValues(alpha: 0.4))),
          child: Row(children: [const Text('💧', style: TextStyle(fontSize: 18)), const SizedBox(width: 6),
            Text('$_gameScore', style: GoogleFonts.outfit(color: AppColors.kidsSky, fontWeight: FontWeight.w900, fontSize: 22))])),
        const Spacer(),
        Row(children: List.generate(5, (i) => Padding(padding: const EdgeInsets.only(left: 3),
          child: AnimatedScale(scale: i < _gameLives ? 1.0 : 0.7, duration: const Duration(milliseconds: 300),
            child: Text(i < _gameLives ? '❤️' : '🩶', style: const TextStyle(fontSize: 18)))))),
      ])),
      Positioned(bottom: 8, left: 0, right: 0, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🧪', style: TextStyle(fontSize: 22)), const SizedBox(width: 8),
        SizedBox(width: 160, height: 18, child: ClipRRect(borderRadius: BorderRadius.circular(9), child: Stack(children: [
          Container(color: Colors.white.withValues(alpha: 0.08)),
          FractionallySizedBox(widthFactor: (_gameScore / 15).clamp(0.0, 1.0), child: Container(
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.kidsPrimary, AppColors.kidsAccent, AppColors.kidsGreen])))),
          Center(child: Text('${((_gameScore / 15) * 100).clamp(0, 100).toInt()}%',
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))),
        ]))),
      ])),
      ..._sparkles.map((s) => Positioned(left: s.x - 8, top: s.y - 8,
        child: Opacity(opacity: (s.life / 70).clamp(0, 1), child: Text(s.emoji, style: const TextStyle(fontSize: 16))))),
      ..._drops.map((drop) => Positioned(left: drop.x - 32, top: drop.y, child: GestureDetector(
        onTap: () => _tapDrop(drop),
        child: Container(width: 64, height: 64,
          decoration: BoxDecoration(shape: BoxShape.circle,
            gradient: RadialGradient(colors: [AppColors.kidsPrimary.withValues(alpha: 0.3), AppColors.kidsPrimary.withValues(alpha: 0.05)]),
            border: Border.all(color: AppColors.kidsPrimary.withValues(alpha: 0.5), width: 2),
            boxShadow: [BoxShadow(color: AppColors.kidsPrimary.withValues(alpha: 0.25), blurRadius: 14)]),
          child: Center(child: Text(drop.emoji, style: const TextStyle(fontSize: 30))))))),
    ]);
  }

  Widget _instrStep(String emoji, String label) {
    return Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 24)), const SizedBox(height: 4),
      Text(label, style: GoogleFonts.outfit(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w600)),
    ]);
  }

  // ═══════════════════════════════════════════
  //  GAME 4: MEMORY MATCH
  // ═══════════════════════════════════════════

  static const _memEmojis = ['🐘', '🦋', '🌈', '🌟', '💧', '🎈'];

  void _initMemoryGame() {
    final pairs = [..._memEmojis, ..._memEmojis]..shuffle();
    _memCards = List.generate(
      pairs.length,
      (i) => _MemoryCard(emoji: pairs[i]),
    );
    _firstFlipIdx = null;
    _memLocked = false;
    _memMatches = 0;
    _memGameOver = false;
    _memMoves = 0;
  }

  void _onMemCardTap(int idx) {
    if (_memLocked) return;
    final card = _memCards[idx];
    if (card.isMatched || card.isFaceUp) return;

    setState(() {
      _memCards[idx] = card.copyWith(isFaceUp: true);
    });

    if (_firstFlipIdx == null) {
      _firstFlipIdx = idx;
      return;
    }

    final firstIdx = _firstFlipIdx!;
    _firstFlipIdx = null;
    _memMoves++;
    _memLocked = true;

    if (_memCards[firstIdx].emoji == _memCards[idx].emoji) {
      // Match!
      Future.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        setState(() {
          _memCards[firstIdx] = _memCards[firstIdx].copyWith(isMatched: true);
          _memCards[idx] = _memCards[idx].copyWith(isMatched: true);
          _memMatches++;
          _memLocked = false;
        });
        final rng = Random();
        final cheers = _isArabic
            ? ['مطابقة! 🌟', 'رائع!', 'ممتاز!']
            : ['Match! 🌟', 'Amazing!', 'Great find!'];
        _ellieSpeak(cheers[rng.nextInt(cheers.length)]);
        if (_memMatches == _memEmojis.length) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              setState(() => _memGameOver = true);
              _ellieSpeak(_isArabic ? 'أحسنت! فزت!' : 'You won! Amazing!');
            }
          });
        }
      });
    } else {
      // No match — flip back
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        setState(() {
          _memCards[firstIdx] = _memCards[firstIdx].copyWith(isFaceUp: false);
          _memCards[idx] = _memCards[idx].copyWith(isFaceUp: false);
          _memLocked = false;
        });
      });
    }
  }

  Widget _buildMemoryMatchPage() {
    if (_memCards.isEmpty || _memGameOver) {
      final won = _memGameOver;
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(won ? '🏆' : '🧠', style: const TextStyle(fontSize: 64)),
              const SizedBox(height: 10),
              Text(
                won
                    ? (_isArabic ? 'فزت يا بطل! 🎉' : 'You Won! 🎉')
                    : (_isArabic ? 'طابق الصور!' : 'Match the pictures!'),
                style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 26),
                textAlign: TextAlign.center,
              ),
              if (won) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.kidsPink.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.kidsPink.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    _isArabic
                        ? '🌟 $_memMoves حركة فقط! 🌟'
                        : '🌟 $_memMoves moves! 🌟',
                    style: GoogleFonts.outfit(
                        color: AppColors.kidsPink,
                        fontWeight: FontWeight.w700,
                        fontSize: 16),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _isArabic
                        ? 'اضغط على بطاقتين متشابهتين\nلتطابقهما وتفوز!'
                        : 'Flip two matching cards\nto find all 6 pairs!',
                    style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => setState(() => _initMemoryGame()),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 36, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppColors.kidsPink, AppColors.kidsAccent]),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.kidsPink.withValues(alpha: 0.4),
                          blurRadius: 18,
                          offset: const Offset(0, 5))
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('▶', style: TextStyle(fontSize: 18, color: Colors.white)),
                      const SizedBox(width: 8),
                      Text(
                        won
                            ? (_isArabic ? 'مرة ثانية!' : 'Play Again!')
                            : (_isArabic ? 'ابدأ اللعبة!' : "Let's Play!"),
                        style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 17),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Stats bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _memStat('🧩', _isArabic ? 'تطابقات' : 'Matches',
                  '$_memMatches / ${_memEmojis.length}', AppColors.kidsGreen),
              _memStat('👆', _isArabic ? 'حركات' : 'Moves',
                  '$_memMoves', AppColors.kidsSky),
            ],
          ),
        ),
        // Card grid 4 columns × 3 rows
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.85,
              ),
              itemCount: _memCards.length,
              itemBuilder: (_, i) => _buildMemCard(i),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMemCard(int idx) {
    final card = _memCards[idx];
    final faceUp = card.isFaceUp || card.isMatched;
    return GestureDetector(
      onTap: () => _onMemCardTap(idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          gradient: faceUp
              ? (card.isMatched
                  ? LinearGradient(colors: [
                      AppColors.kidsGreen.withValues(alpha: 0.3),
                      AppColors.kidsSky.withValues(alpha: 0.2),
                    ])
                  : LinearGradient(colors: [
                      AppColors.kidsPrimary.withValues(alpha: 0.25),
                      AppColors.kidsPink.withValues(alpha: 0.15),
                    ]))
              : LinearGradient(colors: [
                  const Color(0xFF3D2C8D).withValues(alpha: 0.8),
                  const Color(0xFF5C3D99).withValues(alpha: 0.6),
                ]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: faceUp
                ? (card.isMatched
                    ? AppColors.kidsGreen.withValues(alpha: 0.6)
                    : AppColors.kidsPrimary.withValues(alpha: 0.5))
                : Colors.white.withValues(alpha: 0.15),
            width: card.isMatched ? 2 : 1,
          ),
          boxShadow: card.isMatched
              ? [
                  BoxShadow(
                      color: AppColors.kidsGreen.withValues(alpha: 0.3),
                      blurRadius: 10)
                ]
              : [],
        ),
        child: Center(
          child: faceUp
              ? Text(card.emoji,
                  style: TextStyle(
                      fontSize: card.isMatched ? 28 : 26))
              : Text('🌙',
                  style: TextStyle(
                      fontSize: 22,
                      color: Colors.white.withValues(alpha: 0.4))),
        ),
      ),
    );
  }

  Widget _memStat(
      String icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: GoogleFonts.outfit(
                      color: color.withValues(alpha: 0.8),
                      fontSize: 9,
                      fontWeight: FontWeight.w600)),
              Text(value,
                  style: GoogleFonts.outfit(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }
}

class _FallingDrop {
  double x, y, speed, wobble;
  String emoji;
  _FallingDrop({required this.x, required this.y, required this.speed, required this.emoji, this.wobble = 0});
}

class _Sparkle {
  double x, y, dx, dy;
  int life;
  String emoji;
  _Sparkle({required this.x, required this.y, required this.dx, required this.dy, required this.life, required this.emoji});
}

class _MemoryCard {
  final String emoji;
  final bool isFaceUp;
  final bool isMatched;

  const _MemoryCard({
    required this.emoji,
    this.isFaceUp = false,
    this.isMatched = false,
  });

  _MemoryCard copyWith({
    String? emoji,
    bool? isFaceUp,
    bool? isMatched,
  }) {
    return _MemoryCard(
      emoji: emoji ?? this.emoji,
      isFaceUp: isFaceUp ?? this.isFaceUp,
      isMatched: isMatched ?? this.isMatched,
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  final Color color;
  _BubbleTailPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..style = PaintingStyle.fill;
    canvas.drawPath(Path()..moveTo(0, 0)..lineTo(size.width, 0)..lineTo(size.width / 2, size.height)..close(), p);
    final bp = Paint()..color = Colors.white.withValues(alpha: 0.2)..style = PaintingStyle.stroke..strokeWidth = 1;
    canvas.drawPath(Path()..moveTo(0, 0)..lineTo(size.width / 2, size.height)..lineTo(size.width, 0), bp);
  }
  @override
  bool shouldRepaint(covariant _BubbleTailPainter old) => old.color != color;
}
