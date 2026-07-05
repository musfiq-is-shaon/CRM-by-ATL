import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme_colors.dart';
import 'fifa_trionda_ball_view.dart';

/// Startup loader — 3D FIFA Trionda GLB bouncing on the floor.
class AppLaunchLoader extends StatefulWidget {
  const AppLaunchLoader({super.key});

  @override
  State<AppLaunchLoader> createState() => _AppLaunchLoaderState();
}

class _AppLaunchLoaderState extends State<AppLaunchLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController;
  bool _ballReady = false;

  double _ballSize(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w < 480 ? 92.0 : math.min(118.0, math.max(92.0, w * 0.22));
  }

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 960),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void _onBallReady() {
    if (_ballReady || !mounted) return;
    setState(() => _ballReady = true);
    _bounceController.repeat();
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppThemeColors.backgroundColor(context);
    final ballSize = _ballSize(context);
    const bounceHeight = 112.0;
    const surfaceBottom = 16.0;
    final shadowHeight = math.max(7.0, ballSize * 0.072);
    // GLB framing leaves a little empty space under the sphere in the square view.
    const visualContactLift = 4.0;

    return ColoredBox(
      color: bg,
      child: Center(
        child: SizedBox(
          width: ballSize + 24,
          height: ballSize + bounceHeight + surfaceBottom + 8,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _bounceController,
              builder: (context, child) {
                final t = _ballReady ? _bounceController.value : 0.0;
                final phase = t * math.pi;
                final air = math.sin(phase).clamp(0.0, 1.0);
                final lift = math.pow(air, 1.35) * bounceHeight;
                final ground = 1 - air;
                final scaleY = 1.0 - (ground * 0.09) + (air * 0.025);
                final scaleX = 1.0 + (ground * 0.07) - (air * 0.015);
                final shadowScale = 0.38 + (ground * 0.62);
                final maxShadowA = Theme.of(context).brightness == Brightness.dark
                    ? 0.38
                    : 0.22;
                final shadowA = _ballReady
                    ? (math.pow(ground, 0.72) * maxShadowA).clamp(0.0, 1.0)
                    : 0.0;

                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    if (_ballReady)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: surfaceBottom - shadowHeight * 0.62,
                        child: Center(
                          child: _FloorShadow(
                            width: ballSize * 0.74 * shadowScale,
                            height: shadowHeight,
                            opacity: shadowA,
                          ),
                        ),
                      ),
                    if (_ballReady)
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: surfaceBottom,
                        child: Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                AppThemeColors.dividerColor(context)
                                    .withValues(alpha: 0.45),
                                AppThemeColors.dividerColor(context)
                                    .withValues(alpha: 0.45),
                                Colors.transparent,
                              ],
                              stops: const [0, 0.22, 0.78, 1],
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: surfaceBottom + visualContactLift,
                      height: ballSize + bounceHeight,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Transform.translate(
                          offset: Offset(0, -lift),
                          child: Transform(
                            alignment: Alignment.bottomCenter,
                            transform:
                                Matrix4.diagonal3Values(scaleX, scaleY, 1),
                            child: Opacity(
                              opacity: _ballReady ? 1 : 0,
                              child: child,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
              child: FifaTriondaBallView(
                size: ballSize,
                backgroundColor: bg,
                onReady: _onBallReady,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloorShadow extends StatelessWidget {
  const _FloorShadow({
    required this.width,
    required this.height,
    required this.opacity,
  });

  final double width;
  final double height;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _ContactShadowPainter(opacity: opacity),
    );
  }
}

class _ContactShadowPainter extends CustomPainter {
  const _ContactShadowPainter({required this.opacity});

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0.001) return;

    final center = Offset(size.width / 2, size.height * 0.42);
    final outerRect = Rect.fromCenter(
      center: center,
      width: size.width,
      height: size.height,
    );
    final innerRect = Rect.fromCenter(
      center: center,
      width: size.width * 0.52,
      height: size.height * 0.62,
    );

    canvas.drawOval(
      outerRect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.72,
          colors: [
            Colors.black.withValues(alpha: opacity * 0.16),
            Colors.black.withValues(alpha: opacity * 0.08),
            Colors.transparent,
          ],
          stops: const [0.15, 0.55, 1],
        ).createShader(outerRect),
    );

    canvas.drawOval(
      innerRect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.62,
          colors: [
            Colors.black.withValues(alpha: opacity * 0.55),
            Colors.black.withValues(alpha: opacity * 0.28),
            Colors.transparent,
          ],
          stops: const [0, 0.42, 1],
        ).createShader(innerRect),
    );
  }

  @override
  bool shouldRepaint(covariant _ContactShadowPainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}
