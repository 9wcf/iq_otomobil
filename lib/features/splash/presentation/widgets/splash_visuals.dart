import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Automotive-inspired palette aligned with [AppColors] and luxury HUD tones.
class SplashPalette {
  const SplashPalette({
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.backgroundMid,
    required this.glowPrimary,
    required this.glowSecondary,
    required this.glowCyan,
    required this.graphite,
    required this.silver,
    required this.electricBlue,
    required this.hudLine,
    required this.streak,
    required this.particle,
    required this.orbPrimary,
    required this.orbSecondary,
    required this.titleColor,
  });

  factory SplashPalette.light({
    Color background = const Color(0xFFE0E9FF),
    Color primary = const Color(0xFF1341A1),
    Color accent = const Color(0xFF4A6FD4),
  }) {
    return SplashPalette(
      backgroundTop: background,
      backgroundMid: const Color(0xFFECF1FF),
      backgroundBottom: const Color(0xFFF4F7FF),
      glowPrimary: primary,
      glowSecondary: accent,
      glowCyan: const Color(0xFF4A6FD4),
      graphite: const Color(0xFF1E293B),
      silver: const Color(0xFF94A3B8),
      electricBlue: const Color(0xFF1341A1),
      hudLine: primary.withValues(alpha: 0.22),
      streak: accent.withValues(alpha: 0.14),
      particle: primary.withValues(alpha: 0.16),
      orbPrimary: primary.withValues(alpha: 0.12),
      orbSecondary: accent.withValues(alpha: 0.08),
      titleColor: const Color(0xFF0A1E4A),
    );
  }

  factory SplashPalette.dark({
    Color background = const Color(0xFF0F172A),
    Color accent = const Color(0xFF38BDF8),
  }) {
    return SplashPalette(
      backgroundTop: background,
      backgroundMid: const Color(0xFF1E293B),
      backgroundBottom: const Color(0xFF334155),
      glowPrimary: accent,
      glowSecondary: const Color(0xFF7DD3FC),
      glowCyan: const Color(0xFF4A6FD4),
      graphite: const Color(0xFF0F172A),
      silver: const Color(0xFFCBD5E1),
      electricBlue: accent,
      hudLine: accent.withValues(alpha: 0.28),
      streak: accent.withValues(alpha: 0.18),
      particle: accent.withValues(alpha: 0.2),
      orbPrimary: accent.withValues(alpha: 0.1),
      orbSecondary: const Color(0xFF6366F1).withValues(alpha: 0.07),
      titleColor: Colors.white,
    );
  }

  final Color backgroundTop;
  final Color backgroundMid;
  final Color backgroundBottom;
  final Color glowPrimary;
  final Color glowSecondary;
  final Color glowCyan;
  final Color graphite;
  final Color silver;
  final Color electricBlue;
  final Color hudLine;
  final Color streak;
  final Color particle;
  final Color orbPrimary;
  final Color orbSecondary;
  final Color titleColor;
}

class SplashGradientBackground extends StatelessWidget {
  const SplashGradientBackground({super.key, required this.palette});

  final SplashPalette palette;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.backgroundTop,
            palette.backgroundMid,
            palette.backgroundBottom,
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

/// Ambient orbs, particles, and drifting light streaks.
class SplashAmbientLayer extends StatelessWidget {
  const SplashAmbientLayer({
    super.key,
    required this.palette,
    required this.drift,
  });

  final SplashPalette palette;
  final double drift;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SplashAmbientPainter(palette: palette, drift: drift),
      child: const SizedBox.expand(),
    );
  }
}

class _SplashAmbientPainter extends CustomPainter {
  _SplashAmbientPainter({required this.palette, required this.drift});

  final SplashPalette palette;
  final double drift;

  static const _particles = <_ParticleSeed>[
    _ParticleSeed(0.12, 0.18, 2.0, 0.3, 0.05),
    _ParticleSeed(0.78, 0.22, 1.6, 0.45, 0.18),
    _ParticleSeed(0.34, 0.72, 2.2, 0.35, 0.31),
    _ParticleSeed(0.88, 0.64, 1.2, 0.4, 0.44),
    _ParticleSeed(0.52, 0.38, 1.8, 0.28, 0.12),
    _ParticleSeed(0.18, 0.58, 1.4, 0.38, 0.27),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final wave = math.sin(drift * math.pi * 2);

    _drawOrb(
      canvas,
      Offset(size.width * 0.14, size.height * (0.12 + wave * 0.01)),
      size.width * 0.4,
      palette.orbPrimary,
    );
    _drawOrb(
      canvas,
      Offset(size.width * 0.88, size.height * (0.26 - wave * 0.008)),
      size.width * 0.34,
      palette.orbSecondary,
    );
    _drawOrb(
      canvas,
      Offset(size.width * 0.55, size.height * 0.9),
      size.width * 0.28,
      palette.glowCyan.withValues(alpha: 0.06),
    );

    for (final seed in _particles) {
      final bob = math.sin((drift + seed.phase) * math.pi * 2) * 5;
      final paint = Paint()
        ..color = palette.particle.withValues(alpha: seed.alpha);
      canvas.drawCircle(
        Offset(size.width * seed.x + bob * 0.3, size.height * seed.y + bob),
        seed.radius,
        paint,
      );
    }

    _drawLightStreaks(canvas, size);
    _drawSoftWave(canvas, size, wave);
  }

  void _drawOrb(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  void _drawLightStreaks(Canvas canvas, Size size) {
    const streakCount = 4;
    for (var i = 0; i < streakCount; i++) {
      final phase = (drift + i * 0.22) % 1.0;
      final y = size.height * (0.22 + i * 0.14) + phase * 18 - 9;
      final startX = -size.width * 0.15 + phase * size.width * 1.3;
      final endX = startX + size.width * 0.42;

      final paint = Paint()
        ..shader = LinearGradient(
          colors: [
            palette.streak.withValues(alpha: 0),
            palette.streak,
            palette.glowPrimary.withValues(alpha: 0.1),
            palette.streak.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.35, 0.55, 1.0],
        ).createShader(Rect.fromLTRB(startX, y - 2, endX, y + 2))
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(startX, y), Offset(endX, y), paint);
    }
  }

  void _drawSoftWave(Canvas canvas, Size size, double wave) {
    final path = Path();
    final baseY = size.height * 0.58;
    path.moveTo(0, baseY);
    for (var x = 0.0; x <= size.width; x += 10) {
      final t = x / size.width;
      final y = baseY +
          math.sin((t * math.pi * 2) + wave * math.pi) * 8 +
          math.sin((t * math.pi * 3) + drift * math.pi) * 3;
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            palette.glowSecondary.withValues(alpha: 0.05),
            palette.glowSecondary.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(0, baseY - 20, size.width, size.height)),
    );
  }

  @override
  bool shouldRepaint(covariant _SplashAmbientPainter old) =>
      old.drift != drift || old.palette != palette;
}

/// HUD brackets, speed lines, dashboard arc, metallic accents.
class SplashAutomotiveLayer extends StatelessWidget {
  const SplashAutomotiveLayer({
    super.key,
    required this.palette,
    required this.drift,
  });

  final SplashPalette palette;
  final double drift;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SplashAutomotivePainter(palette: palette, drift: drift),
      child: const SizedBox.expand(),
    );
  }
}

class _SplashAutomotivePainter extends CustomPainter {
  _SplashAutomotivePainter({required this.palette, required this.drift});

  final SplashPalette palette;
  final double drift;

  @override
  void paint(Canvas canvas, Size size) {
    _drawHudCorners(canvas, size);
    _drawSpeedLines(canvas, size);
    _drawDashboardArc(canvas, size);
    _drawMetallicSheen(canvas, size);
    _drawCenterCrosshair(canvas, size);
  }

  void _drawHudCorners(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = palette.hudLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    const inset = 28.0;
    const arm = 36.0;

    for (final flipX in [false, true]) {
      for (final flipY in [false, true]) {
        final path = Path();
        final ox = flipX ? size.width - inset : inset;
        final oy = flipY ? size.height - inset * 2.2 : inset + 8;
        final dx = flipX ? -1.0 : 1.0;
        final dy = flipY ? -1.0 : 1.0;

        path.moveTo(ox, oy + dy * arm);
        path.lineTo(ox, oy);
        path.lineTo(ox + dx * arm, oy);

        canvas.drawPath(path, paint);

        final glow = Paint()
          ..color = palette.glowPrimary.withValues(alpha: 0.14)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawPath(path, glow);
      }
    }
  }

  void _drawSpeedLines(Canvas canvas, Size size) {
    final shift = drift * size.width * 0.08;
    final paint = Paint()
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 7; i++) {
      final alpha = 0.04 + (i % 3) * 0.03;
      paint.color = palette.silver.withValues(alpha: alpha);
      final baseX = size.width * (0.05 + i * 0.13) - shift;
      final len = 40.0 + (i % 4) * 18;
      canvas.drawLine(
        Offset(baseX, size.height * 0.32),
        Offset(baseX + len, size.height * 0.32 - len * 0.35),
        paint,
      );
      canvas.drawLine(
        Offset(size.width - baseX, size.height * 0.68),
        Offset(size.width - baseX - len, size.height * 0.68 + len * 0.35),
        paint,
      );
    }
  }

  void _drawDashboardArc(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.92);
    final radius = size.width * 0.52;
    const sweep = math.pi * 0.55;
    const start = math.pi + (math.pi - sweep) / 2;
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    final pulse = 0.78 + math.sin(drift * math.pi * 2) * 0.22;
    final progress = (0.48 + drift * 0.42).clamp(0.38, 0.92);
    final activeSweep = sweep * progress;
    final tipAngle = start + activeSweep;
    final tipPoint = center +
        Offset(
          math.cos(tipAngle) * radius,
          math.sin(tipAngle) * radius,
        );

    // مسار العداد الخافت
    canvas.drawArc(
      arcRect,
      start,
      sweep,
      false,
      Paint()
        ..color = palette.graphite.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // توهج نيون خافت على كامل القوس
    canvas.drawArc(
      arcRect,
      start,
      sweep,
      false,
      Paint()
        ..color = palette.glowCyan.withValues(alpha: 0.06 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // طبقات نيون أزرق مشع على خط التقدّم
    const neonCore = Color(0xFF4A6FD4);
    const neonBright = Color(0xFF7EB3FF);
    const neonHighlight = Color(0xFFB8D4FF);
    final neonLayers = <({double width, double blur, double alpha, Color color})>[
      (width: 18, blur: 16, alpha: 0.14, color: palette.glowPrimary),
      (width: 12, blur: 10, alpha: 0.26, color: palette.glowCyan),
      (width: 8, blur: 6, alpha: 0.38, color: palette.electricBlue),
      (width: 5, blur: 3, alpha: 0.55, color: neonCore),
      (width: 2.8, blur: 0, alpha: 0.92, color: neonBright),
      (width: 1.2, blur: 0, alpha: 1.0, color: neonHighlight),
    ];

    for (final layer in neonLayers) {
      final paint = Paint()
        ..color = layer.color.withValues(alpha: layer.alpha * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = layer.width
        ..strokeCap = StrokeCap.round;
      if (layer.blur > 0) {
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, layer.blur);
      }
      canvas.drawArc(arcRect, start, activeSweep, false, paint);
    }

    // نقطة متوهجة عند طرف الخط (مؤشر السرعة)
    final tipGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          neonBright.withValues(alpha: 0.95 * pulse),
          palette.glowCyan.withValues(alpha: 0.45 * pulse),
          palette.glowCyan.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.35, 1.0],
      ).createShader(Rect.fromCircle(center: tipPoint, radius: 18));
    canvas.drawCircle(tipPoint, 14, tipGlow);
    canvas.drawCircle(
      tipPoint,
      3.2,
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );

    // علامات العداد — الأقرب للخط النيون يضيء
    for (var i = 0; i <= 8; i++) {
      final angle = start + (sweep / 8) * i;
      final tickProgress = i / 8;
      final isNearActive = tickProgress <= progress + 0.08;
      final inner = center + Offset(
        math.cos(angle) * (radius - 6),
        math.sin(angle) * (radius - 6),
      );
      final outer = center + Offset(
        math.cos(angle) * (radius + (i % 2 == 0 ? 9 : 5)),
        math.sin(angle) * (radius + (i % 2 == 0 ? 9 : 5)),
      );

      if (isNearActive) {
        canvas.drawLine(
          inner,
          outer,
          Paint()
            ..color = palette.glowCyan.withValues(alpha: 0.55 * pulse)
            ..strokeWidth = 1.6
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
      }

      final tickPaint = Paint()
        ..color = isNearActive
            ? neonCore.withValues(alpha: 0.85)
            : palette.silver.withValues(alpha: 0.2)
        ..strokeWidth = isNearActive ? 1.4 : 1
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(inner, outer, tickPaint);
    }
  }

  void _drawMetallicSheen(Canvas canvas, Size size) {
    final shimmer = math.sin(drift * math.pi * 2) * 0.5 + 0.5;
    final rect = Rect.fromLTWH(0, size.height * 0.08, size.width, size.height * 0.35);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(-1 + shimmer * 2, 0),
        end: Alignment(shimmer * 2, 1),
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.06),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0.35, 0.5, 0.65],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  void _drawCenterCrosshair(Canvas canvas, Size size) {
    final c = Offset(size.width * 0.5, size.height * 0.46);
    final paint = Paint()
      ..color = palette.hudLine.withValues(alpha: 0.35)
      ..strokeWidth = 0.8;
    const len = 14.0;
    const gap = 52.0;
    canvas.drawLine(Offset(c.dx - gap - len, c.dy), Offset(c.dx - gap, c.dy), paint);
    canvas.drawLine(Offset(c.dx + gap, c.dy), Offset(c.dx + gap + len, c.dy), paint);
    canvas.drawLine(Offset(c.dx, c.dy - gap - len), Offset(c.dx, c.dy - gap), paint);
    canvas.drawLine(Offset(c.dx, c.dy + gap), Offset(c.dx, c.dy + gap + len), paint);
  }

  @override
  bool shouldRepaint(covariant _SplashAutomotivePainter old) =>
      old.drift != drift || old.palette != palette;
}

class _ParticleSeed {
  const _ParticleSeed(this.x, this.y, this.radius, this.alpha, this.phase);

  final double x;
  final double y;
  final double radius;
  final double alpha;
  final double phase;
}

/// Centered app icon: entrance fade/scale + soft blue glow pulse + shimmer.
class SplashAnimatedLogo extends StatelessWidget {
  const SplashAnimatedLogo({
    super.key,
    required this.assetPath,
    required this.palette,
    required this.entrance,
    required this.breath,
    required this.shimmer,
    this.size = 120,
  });

  final String assetPath;
  final SplashPalette palette;
  final double entrance;
  final double breath;
  final double shimmer;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fade = Curves.easeOutCubic.transform(entrance.clamp(0.0, 1.0));
    final scale =
        0.86 + (Curves.easeOutBack.transform(entrance.clamp(0.0, 1.0)) * 0.14);
    final glowPulse = 0.5 + (breath * 0.5);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheSize = (size * dpr).round();

    return Opacity(
      opacity: fade,
      child: Transform.scale(
        scale: scale,
        child: SizedBox(
          width: size + 56,
          height: size + 56,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: size + 48,
                height: size + 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color:
                          palette.glowPrimary.withValues(alpha: 0.22 * glowPulse),
                      blurRadius: 44,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: palette.glowCyan.withValues(alpha: 0.16 * glowPulse),
                      blurRadius: 32,
                    ),
                    BoxShadow(
                      color:
                          palette.glowSecondary.withValues(alpha: 0.1 * glowPulse),
                      blurRadius: 20,
                    ),
                  ],
                ),
              ),
              Container(
                width: size + 30,
                height: size + 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      palette.glowCyan.withValues(alpha: 0.12 * glowPulse),
                      palette.glowPrimary.withValues(alpha: 0.1 * glowPulse),
                      palette.glowPrimary.withValues(alpha: 0),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                elevation: 10,
                shadowColor: palette.glowPrimary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(28),
                child: Container(
                  width: size + 12,
                  height: size + 12,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: palette.glowPrimary.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: palette.graphite.withValues(alpha: 0.1),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          assetPath,
                          fit: BoxFit.cover,
                          width: size + 12,
                          height: size + 12,
                          gaplessPlayback: true,
                          cacheWidth: cacheSize,
                          cacheHeight: cacheSize,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (context, error, stackTrace) {
                            return ColoredBox(
                              color: palette.glowPrimary.withValues(alpha: 0.08),
                              child: Icon(
                                Icons.directions_car_filled_rounded,
                                size: size * 0.45,
                                color: palette.glowPrimary,
                              ),
                            );
                          },
                        ),
                        IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment(-1.0 + shimmer * 2, -0.4),
                                end: Alignment(shimmer * 2, 0.4),
                                colors: [
                                  Colors.transparent,
                                  Colors.white.withValues(alpha: 0.22),
                                  Colors.transparent,
                                ],
                                stops: const [0.38, 0.5, 0.62],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Letter-by-letter title — LTR sequential order (fixes RTL reversed animation).
class SplashCinematicTitle extends StatelessWidget {
  const SplashCinematicTitle({
    super.key,
    required this.text,
    required this.progress,
    required this.palette,
    this.fontSize = 20,
  });

  final String text;
  final double progress;
  final SplashPalette palette;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final letters = text.split('');
    if (letters.isEmpty) return const SizedBox.shrink();

    final style = GoogleFonts.orbitron(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      letterSpacing: 4.2,
      height: 1.1,
      color: palette.titleColor,
      shadows: [
        Shadow(
          color: palette.glowCyan.withValues(alpha: 0.35),
          blurRadius: 12,
        ),
        Shadow(
          color: palette.glowPrimary.withValues(alpha: 0.2),
          blurRadius: 8,
          offset: const Offset(0, 1),
        ),
      ],
    );

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < letters.length; i++)
            _CinematicLetter(
              char: letters[i],
              index: i,
              total: letters.length,
              progress: progress,
              style: style,
              glow: palette.glowCyan,
            ),
        ],
      ),
    );
  }
}

class _CinematicLetter extends StatelessWidget {
  const _CinematicLetter({
    required this.char,
    required this.index,
    required this.total,
    required this.progress,
    required this.style,
    required this.glow,
  });

  final String char;
  final int index;
  final int total;
  final double progress;
  final TextStyle style;
  final Color glow;

  @override
  Widget build(BuildContext context) {
    if (char == ' ') {
      return SizedBox(width: style.fontSize! * 0.35);
    }

    // تتابع حرف بحرف بدون تداخل: I → Q → space → O → ...
    final exact = progress * total;
    final fullCount = exact.floor();
    double local;
    if (index < fullCount) {
      local = 1.0;
    } else if (index == fullCount) {
      local = (exact - fullCount).clamp(0.0, 1.0);
    } else {
      local = 0.0;
    }

    final eased = Curves.easeOutCubic.transform(local);
    final slideY = (1 - eased) * 10;
    final scale = 0.94 + eased * 0.06;

    return Opacity(
      opacity: eased,
      child: Transform.translate(
        offset: Offset(0, slideY),
        child: Transform.scale(
          scale: scale,
          child: Text(
            char,
            style: style,
          ),
        ),
      ),
    );
  }
}
