import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models/weather_model.dart';

/// Animated weather scene (v2) — soft gradient shapes, eased motion, day/night
/// aware. Canvas-based so it works offline and themes cleanly.
class WeatherMoodAnimation extends StatefulWidget {
  const WeatherMoodAnimation({
    super.key,
    required this.kind,
    required this.size,
    this.isDay = true,
  });

  final DashboardWeatherKind kind;
  final double size;
  final bool isDay;

  @override
  State<WeatherMoodAnimation> createState() => _WeatherMoodAnimationState();
}

class _WeatherMoodAnimationState extends State<WeatherMoodAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _WeatherScenePainter(
              kind: widget.kind,
              t: _controller.value,
              isDay: widget.isDay,
            ),
            size: Size.square(widget.size),
          );
        },
      ),
    );
  }
}

class _WeatherScenePainter extends CustomPainter {
  _WeatherScenePainter({
    required this.kind,
    required this.t,
    required this.isDay,
  });

  final DashboardWeatherKind kind;
  final double t;
  final bool isDay;

  // Smooth ping-pong 0→1→0 with easing.
  double get _sway {
    final phase = (math.sin(t * math.pi * 2) + 1) / 2;
    return Curves.easeInOut.transform(phase);
  }

  @override
  void paint(Canvas canvas, Size size) {
    switch (kind) {
      case DashboardWeatherKind.sunny:
        isDay ? _paintSun(canvas, size) : _paintMoon(canvas, size);
      case DashboardWeatherKind.partlyCloudy:
        _paintPartlyCloudy(canvas, size);
      case DashboardWeatherKind.cloudy:
        _paintCloudy(canvas, size);
      case DashboardWeatherKind.foggy:
        _paintFoggy(canvas, size);
      case DashboardWeatherKind.rainy:
        _paintRain(canvas, size, storm: false);
      case DashboardWeatherKind.stormy:
        _paintRain(canvas, size, storm: true);
      case DashboardWeatherKind.snowy:
        _paintSnow(canvas, size);
    }
  }

  // ---------------------------------------------------------------- sun/moon

  void _paintSun(Canvas canvas, Size size, {Offset? at, double scale = 1}) {
    final center = at ?? Offset(size.width * 0.5, size.height * 0.5);
    final breath = 0.96 + _sway * 0.08;
    final r = size.width * 0.21 * scale * breath;

    // Outer halo.
    canvas.drawCircle(
      center,
      r * 2.3,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFE082).withValues(alpha: 0.5),
            const Color(0xFFFFE082).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: r * 2.3)),
    );

    // Rays — 12, alternating length, slow rotation with eased wobble.
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(t * math.pi / 3 + _sway * 0.06);
    final rayPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFB300), Color(0xFFFFD54F)],
      ).createShader(Rect.fromLTWH(-r, -r * 2, r * 2, r * 2));
    for (var i = 0; i < 12; i++) {
      final long = i.isEven;
      rayPaint.strokeWidth = size.width * (long ? 0.038 : 0.028);
      canvas.drawLine(
        Offset(0, -r * 1.32),
        Offset(0, -r * (long ? 1.75 : 1.55)),
        rayPaint,
      );
      canvas.rotate(math.pi / 6);
    }
    canvas.restore();

    // Body with warm gradient + inner highlight.
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          colors: const [Color(0xFFFFF176), Color(0xFFFFB300)],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
    canvas.drawCircle(
      Offset(center.dx - r * 0.28, center.dy - r * 0.3),
      r * 0.32,
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );
  }

  void _paintMoon(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.52, size.height * 0.5);
    final r = size.width * 0.24;

    canvas.drawCircle(
      center,
      r * 1.9,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFB3C4FF).withValues(alpha: 0.35),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: r * 1.9)),
    );

    // Crescent: full disc minus offset disc.
    final moon = Path()..addOval(Rect.fromCircle(center: center, radius: r));
    final bite = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(center.dx + r * 0.52, center.dy - r * 0.28),
          radius: r * 0.82,
        ),
      );
    canvas.drawPath(
      Path.combine(PathOperation.difference, moon, bite),
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.3),
          colors: const [Color(0xFFFFFDE7), Color(0xFFE6EBFF)],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );

    // Twinkling stars.
    final stars = [
      Offset(size.width * 0.18, size.height * 0.26),
      Offset(size.width * 0.3, size.height * 0.62),
      Offset(size.width * 0.78, size.height * 0.72),
      Offset(size.width * 0.72, size.height * 0.2),
    ];
    for (var i = 0; i < stars.length; i++) {
      final tw = (math.sin((t * 2 + i * 0.31) * math.pi * 2) + 1) / 2;
      _drawStar(
        canvas,
        stars[i],
        size.width * (0.022 + 0.012 * tw),
        Colors.white.withValues(alpha: 0.45 + 0.55 * tw),
      );
    }
  }

  void _drawStar(Canvas canvas, Offset c, double r, Color color) {
    final p = Paint()
      ..color = color
      ..strokeWidth = r * 0.55
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), p);
    canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), p);
  }

  // ------------------------------------------------------------------ clouds

  void _drawCloud(
    Canvas canvas,
    Offset center,
    double width, {
    required Color top,
    required Color bottom,
    double shadowAlpha = 0.12,
  }) {
    final h = width * 0.6;
    final rect = Rect.fromCenter(center: center, width: width, height: h);

    final path = Path();
    // Base pill.
    path.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy + h * 0.22),
          width: width,
          height: h * 0.52,
        ),
        Radius.circular(h * 0.26),
      ),
    );
    // Two puffs.
    path.addOval(
      Rect.fromCircle(
        center: Offset(center.dx - width * 0.18, center.dy - h * 0.02),
        radius: width * 0.21,
      ),
    );
    path.addOval(
      Rect.fromCircle(
        center: Offset(center.dx + width * 0.13, center.dy - h * 0.12),
        radius: width * 0.26,
      ),
    );

    // Soft drop shadow.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + h * 0.52),
        width: width * 0.8,
        height: h * 0.16,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: shadowAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ).createShader(rect),
    );
  }

  void _paintPartlyCloudy(Canvas canvas, Size size) {
    if (isDay) {
      _paintSun(
        canvas,
        size,
        at: Offset(size.width * 0.36, size.height * 0.36),
        scale: 0.86,
      );
    } else {
      _paintMoon(canvas, size);
    }
    final drift = (_sway - 0.5) * size.width * 0.07;
    _drawCloud(
      canvas,
      Offset(size.width * 0.58 + drift, size.height * 0.66),
      size.width * 0.52,
      top: Colors.white,
      bottom: const Color(0xFFCFD8DC),
    );
  }

  void _paintCloudy(Canvas canvas, Size size) {
    final drift = (_sway - 0.5) * size.width * 0.08;
    _drawCloud(
      canvas,
      Offset(size.width * 0.42 - drift * 0.7, size.height * 0.4),
      size.width * 0.5,
      top: const Color(0xFFE3E8EC),
      bottom: const Color(0xFF9FB2BC),
      shadowAlpha: 0.08,
    );
    _drawCloud(
      canvas,
      Offset(size.width * 0.58 + drift, size.height * 0.64),
      size.width * 0.58,
      top: Colors.white,
      bottom: const Color(0xFFC3CFD6),
    );
  }

  void _paintFoggy(Canvas canvas, Size size) {
    _drawCloud(
      canvas,
      Offset(size.width * 0.5, size.height * 0.34),
      size.width * 0.5,
      top: const Color(0xFFECEFF1),
      bottom: const Color(0xFFB0BEC5),
      shadowAlpha: 0,
    );
    for (var i = 0; i < 3; i++) {
      final shift =
          math.sin((t + i * 0.28) * math.pi * 2) * size.width * 0.07;
      final w = size.width * (0.66 - i * 0.1);
      final y = size.height * (0.58 + i * 0.14);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width * 0.5 + shift, y),
            width: w,
            height: size.height * 0.055,
          ),
          Radius.circular(size.height * 0.03),
        ),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.75 - i * 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }

  // -------------------------------------------------------------------- rain

  void _paintRain(Canvas canvas, Size size, {required bool storm}) {
    final drift = (_sway - 0.5) * size.width * 0.04;

    // Drops behind the cloud edge, fading in/out along their fall.
    final dropPaint = Paint()..strokeCap = StrokeCap.round;
    const dropCount = 7;
    for (var i = 0; i < dropCount; i++) {
      final lane = (i + 0.5) / dropCount;
      final x = size.width * (0.18 + lane * 0.64);
      final phase = (t * 1.6 + i * 0.37) % 1.0;
      final y = size.height * (0.5 + phase * 0.42);
      final fade = phase < 0.15
          ? phase / 0.15
          : (phase > 0.8 ? (1 - phase) / 0.2 : 1.0);
      dropPaint
        ..color = (storm ? const Color(0xFF9BD8FF) : const Color(0xFF6FC7F2))
            .withValues(alpha: 0.9 * fade)
        ..strokeWidth = size.width * 0.032;
      canvas.drawLine(
        Offset(x, y),
        Offset(x - size.width * 0.035, y + size.height * 0.085),
        dropPaint,
      );
    }

    _drawCloud(
      canvas,
      Offset(size.width * 0.5 + drift, size.height * 0.32),
      size.width * 0.58,
      top: storm ? const Color(0xFF90A4AE) : const Color(0xFFE3E8EC),
      bottom: storm ? const Color(0xFF546E7A) : const Color(0xFF90A4AE),
    );

    if (storm) {
      // Bolt flickers twice per cycle with a glow.
      final flick = _boltOpacity(t);
      if (flick > 0) {
        final bolt = Path()
          ..moveTo(size.width * 0.52, size.height * 0.44)
          ..lineTo(size.width * 0.42, size.height * 0.66)
          ..lineTo(size.width * 0.5, size.height * 0.66)
          ..lineTo(size.width * 0.4, size.height * 0.9)
          ..lineTo(size.width * 0.62, size.height * 0.6)
          ..lineTo(size.width * 0.53, size.height * 0.6)
          ..lineTo(size.width * 0.62, size.height * 0.44)
          ..close();
        canvas.drawPath(
          bolt,
          Paint()
            ..color = const Color(0xFFFFD740).withValues(alpha: flick)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        canvas.drawPath(
          bolt,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFE57F), Color(0xFFFFC400)],
            ).createShader(
              Rect.fromLTWH(0, 0, size.width, size.height),
            )
            ..color = Colors.white.withValues(alpha: flick),
        );
      }
    }
  }

  double _boltOpacity(double x) {
    final cycle = (x * 2) % 1.0;
    if (cycle < 0.55) return 1.0;
    if (cycle < 0.62) return 0.25;
    if (cycle < 0.7) return 0.9;
    return 0.0;
  }

  // -------------------------------------------------------------------- snow

  void _paintSnow(Canvas canvas, Size size) {
    final drift = (_sway - 0.5) * size.width * 0.04;

    const flakeCount = 8;
    for (var i = 0; i < flakeCount; i++) {
      final lane = (i + 0.5) / flakeCount;
      final phase = (t * 0.8 + i * 0.29) % 1.0;
      final x = size.width * (0.16 + lane * 0.68) +
          math.sin((t * 2 + i) * math.pi * 2) * size.width * 0.03;
      final y = size.height * (0.48 + phase * 0.44);
      final fade = phase > 0.82 ? (1 - phase) / 0.18 : 1.0;
      final r = size.width * (0.02 + (i % 3) * 0.006);
      _drawFlake(
        canvas,
        Offset(x, y),
        r,
        Colors.white.withValues(alpha: 0.95 * fade),
        rotation: t * math.pi * 2 + i,
      );
    }

    _drawCloud(
      canvas,
      Offset(size.width * 0.5 + drift, size.height * 0.32),
      size.width * 0.56,
      top: Colors.white,
      bottom: const Color(0xFFB6C6CE),
    );
  }

  void _drawFlake(
    Canvas canvas,
    Offset c,
    double r,
    Color color, {
    double rotation = 0,
  }) {
    final p = Paint()
      ..color = color
      ..strokeWidth = r * 0.45
      ..strokeCap = StrokeCap.round;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rotation);
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(Offset(0, -r), Offset(0, r), p);
      canvas.rotate(math.pi / 3);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WeatherScenePainter oldDelegate) {
    return oldDelegate.kind != kind ||
        oldDelegate.t != t ||
        oldDelegate.isDay != isDay;
  }
}

IconData weatherKindIcon(DashboardWeatherKind kind) {
  return switch (kind) {
    DashboardWeatherKind.sunny => Icons.wb_sunny_rounded,
    DashboardWeatherKind.partlyCloudy => Icons.wb_cloudy_rounded,
    DashboardWeatherKind.cloudy => Icons.cloud_rounded,
    DashboardWeatherKind.foggy => Icons.blur_on_rounded,
    DashboardWeatherKind.rainy => Icons.water_drop_rounded,
    DashboardWeatherKind.stormy => Icons.thunderstorm_rounded,
    DashboardWeatherKind.snowy => Icons.ac_unit_rounded,
  };
}
