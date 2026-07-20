import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models/weather_model.dart';

/// Reliable canvas-based weather mood animations (no Lottie dependency).
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
      duration: const Duration(seconds: 4),
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
            painter: _WeatherMoodPainter(
              kind: widget.kind,
              progress: _controller.value,
              isDay: widget.isDay,
            ),
            size: Size.square(widget.size),
          );
        },
      ),
    );
  }
}

class _WeatherMoodPainter extends CustomPainter {
  _WeatherMoodPainter({
    required this.kind,
    required this.progress,
    required this.isDay,
  });

  final DashboardWeatherKind kind;
  final double progress;
  final bool isDay;

  @override
  void paint(Canvas canvas, Size size) {
    switch (kind) {
      case DashboardWeatherKind.sunny:
        _paintSunny(canvas, size);
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

  void _paintSunny(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final pulse = 0.92 + math.sin(progress * math.pi * 2) * 0.08;
    final radius = size.width * 0.22 * pulse;

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFF176).withValues(alpha: isDay ? 0.55 : 0.25),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 2.2));
    canvas.drawCircle(center, radius * 2.2, glow);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(progress * math.pi * 2);
    final rayPaint = Paint()
      ..color = isDay ? const Color(0xFFFFD54F) : const Color(0xFF90CAF9)
      ..strokeWidth = size.width * 0.035
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      canvas.drawLine(
        Offset(0, -radius * 1.35),
        Offset(0, -radius * 1.85),
        rayPaint,
      );
      canvas.rotate(math.pi / 4);
    }
    canvas.restore();

    canvas.drawCircle(
      center,
      radius,
      Paint()..color = isDay ? const Color(0xFFFFCA28) : const Color(0xFF64B5F6),
    );
  }

  void _paintPartlyCloudy(Canvas canvas, Size size) {
    _paintSunny(canvas, size);
    final drift = math.sin(progress * math.pi * 2) * size.width * 0.04;
    _drawCloud(
      canvas,
      Offset(size.width * 0.52 + drift, size.height * 0.58),
      size.width * 0.42,
      const Color(0xFFECEFF1),
      const Color(0xFFB0BEC5),
    );
  }

  void _paintCloudy(Canvas canvas, Size size) {
    final drift = math.sin(progress * math.pi * 2) * size.width * 0.05;
    _drawCloud(
      canvas,
      Offset(size.width * 0.48 + drift, size.height * 0.42),
      size.width * 0.5,
      const Color(0xFFCFD8DC),
      const Color(0xFF90A4AE),
    );
    _drawCloud(
      canvas,
      Offset(size.width * 0.55 - drift * 0.6, size.height * 0.62),
      size.width * 0.38,
      const Color(0xFFECEFF1),
      const Color(0xFFB0BEC5),
    );
  }

  void _paintFoggy(Canvas canvas, Size size) {
    for (var i = 0; i < 4; i++) {
      final y = size.height * (0.35 + i * 0.14);
      final shift = math.sin((progress + i * 0.2) * math.pi * 2) * size.width * 0.08;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.05 + shift,
          y,
          size.width * 0.9,
          size.height * 0.08,
        ),
        Radius.circular(size.height * 0.04),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35 + i * 0.08)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  void _paintRain(Canvas canvas, Size size, {required bool storm}) {
    _drawCloud(
      canvas,
      Offset(size.width * 0.5, size.height * 0.28),
      size.width * 0.52,
      storm ? const Color(0xFF546E7A) : const Color(0xFF78909C),
      storm ? const Color(0xFF37474F) : const Color(0xFF607D8B),
    );

    final dropPaint = Paint()
      ..color = storm ? const Color(0xFF81D4FA) : const Color(0xFF4FC3F7)
      ..strokeWidth = size.width * 0.025
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 14; i++) {
      final seed = i * 17.0;
      final x = (seed * 13.7 % size.width);
      final phase = (progress + seed / 100) % 1.0;
      final yStart = size.height * 0.42 + phase * size.height * 0.55;
      canvas.drawLine(
        Offset(x, yStart),
        Offset(x - size.width * 0.04, yStart + size.height * 0.12),
        dropPaint,
      );
    }

    if (storm) {
      final flash = _lightningOpacity(progress);
      if (flash > 0) {
        canvas.drawRect(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Paint()..color = Colors.white.withValues(alpha: flash),
        );
        final bolt = Path()
          ..moveTo(size.width * 0.62, size.height * 0.18)
          ..lineTo(size.width * 0.54, size.height * 0.42)
          ..lineTo(size.width * 0.6, size.height * 0.42)
          ..lineTo(size.width * 0.48, size.height * 0.72);
        canvas.drawPath(
          bolt,
          Paint()
            ..color = const Color(0xFFFFEB3B)
            ..style = PaintingStyle.stroke
            ..strokeWidth = size.width * 0.04
            ..strokeJoin = StrokeJoin.round,
        );
      }
    }
  }

  void _paintSnow(Canvas canvas, Size size) {
    _drawCloud(
      canvas,
      Offset(size.width * 0.5, size.height * 0.28),
      size.width * 0.48,
      const Color(0xFFECEFF1),
      const Color(0xFFB0BEC5),
    );

    final flakePaint = Paint()..color = Colors.white;
    for (var i = 0; i < 16; i++) {
      final seed = i * 23.0;
      final x = (seed * 11.3 % size.width) +
          math.sin((progress + seed / 50) * math.pi * 2) * 6;
      final phase = (progress * 0.7 + seed / 120) % 1.0;
      final y = size.height * 0.38 + phase * size.height * 0.58;
      canvas.drawCircle(Offset(x, y), size.width * 0.018 + (i % 3) * 0.004, flakePaint);
    }
  }

  double _lightningOpacity(double t) {
    final cycle = (t * 3) % 1.0;
    if (cycle > 0.08 && cycle < 0.14) return 0.35;
    if (cycle > 0.16 && cycle < 0.19) return 0.2;
    return 0;
  }

  void _drawCloud(
    Canvas canvas,
    Offset center,
    double width,
    Color light,
    Color dark,
  ) {
    final h = width * 0.42;
    final puffs = [
      Offset(center.dx - width * 0.22, center.dy + h * 0.1),
      Offset(center.dx, center.dy - h * 0.15),
      Offset(center.dx + width * 0.24, center.dy + h * 0.05),
    ];
    final radii = [width * 0.2, width * 0.26, width * 0.22];

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy + h * 0.15),
          width: width * 0.95,
          height: h * 0.75,
        ),
        Radius.circular(h * 0.35),
      ),
      Paint()..color = dark,
    );

    for (var i = 0; i < puffs.length; i++) {
      canvas.drawCircle(puffs[i], radii[i], Paint()..color = light);
    }
  }

  @override
  bool shouldRepaint(covariant _WeatherMoodPainter oldDelegate) {
    return oldDelegate.kind != kind ||
        oldDelegate.progress != progress ||
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
