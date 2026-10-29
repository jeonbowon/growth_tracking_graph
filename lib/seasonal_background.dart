import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'app_themes.dart';

// ModalRoute includes popup menus, sheets and dialogs as well as full pages.
final backgroundRouteObserver = RouteObserver<ModalRoute<dynamic>>();

class ThemeBackground extends StatefulWidget {
  const ThemeBackground({
    super.key,
    required this.design,
    this.motion = true,
    required this.child,
    this.enabled = true,
  });

  final BackgroundDesign design;
  final bool motion;
  final Widget child;
  final bool enabled;

  @override
  State<ThemeBackground> createState() => _ThemeBackgroundState();
}

class _ThemeBackgroundState extends State<ThemeBackground>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver, RouteAware {
  late final Ticker _ticker;
  final ValueNotifier<double> _elapsed = ValueNotifier(0);
  Duration? _lastTick;

  ModalRoute<dynamic>? _route;

  bool _visible = true;
  bool _foreground = true;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;

    _ticker = createTicker((elapsed) {
      final previous = _lastTick;
      _lastTick = elapsed;
      if (previous != null) {
        // Do not simulate time spent suspended or a long stalled frame.
        _elapsed.value += math.min(
          (elapsed - previous).inMicroseconds / 1000000,
          0.05,
        );
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (_route != route) {
      backgroundRouteObserver.unsubscribe(this);
      _route = route;
      if (route != null) backgroundRouteObserver.subscribe(this, route);
    }
    _visible = route?.isCurrent ?? true;
    _reduceMotion =
        MediaQuery.of(context).disableAnimations || !TickerMode.of(context);
    _syncTicker();
  }

  @override
  void didUpdateWidget(ThemeBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.design != widget.design) {
      _elapsed.value = 0;
      _lastTick = null;
    }

    _syncTicker();
  }

  void _syncTicker() {
    final run =
        _visible &&
        _foreground &&
        widget.enabled &&
        widget.motion &&
        !_reduceMotion &&
        widget.design.animated;
    if (run && !_ticker.isActive) {
      _lastTick = null;
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
      _lastTick = null;
    }
  }

  @override
  void didPushNext() {
    _visible = false;
    _syncTicker();
  }

  @override
  void didPopNext() {
    _visible = true;

    _syncTicker();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;

    _syncTicker();
  }

  @override
  void dispose() {
    backgroundRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _elapsed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: RepaintBoundary(
                  child: CustomPaint(painter: LandscapePainter(widget.design)),
                ),
              ),
            ),
          ),
          if (widget.design.imageAsset != null)
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: Image.asset(
                    widget.design.imageAsset!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, error, stack) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          if (widget.design.animated)
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _WeatherPainter(widget.design, _elapsed),
                    ),
                  ),
                ),
              ),
            ),
          RepaintBoundary(child: widget.child),
        ],
      ),
    );
  }
}

class LandscapePainter extends CustomPainter {
  LandscapePainter(this.design);
  final BackgroundDesign design;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    if (design.scene == BackgroundScene.original) {
      canvas.drawRect(rect, Paint()..color = design.sky);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.95, -0.85),
            radius: 1.15,
            colors: [Color(0x14E69B70), Color(0x00E69B70)],
          ).createShader(rect),
      );
      canvas.drawRect(
        rect,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(0.95, 0.85),
            radius: 1.1,
            colors: [Color(0x12A64F60), Color(0x00A64F60)],
          ).createShader(rect),
      );
      return;
    }
    final colors = [design.sky, design.horizon, design.ground];
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors.take(2).toList(),
        ).createShader(rect),
    );
    if (design.scene == BackgroundScene.image) return;
    final h = math.min(size.height * 0.13, 65.0);
    final hill = Path()
      ..moveTo(0, size.height - h * 0.7)
      ..cubicTo(
        size.width * 0.3,
        size.height - h * 1.4,
        size.width * 0.65,
        size.height + h * 0.1,
        size.width,
        size.height - h,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(hill, Paint()..color = colors[2]);
    if (design.scene == BackgroundScene.snowyHills) {
      for (final x in [
        size.width * 0.08,
        size.width * 0.9,
        size.width * 0.96,
      ]) {
        final base = size.height - h * 0.5;
        final tree = Path()
          ..moveTo(x, base - h * 0.75)
          ..lineTo(x + h * 0.2, base)
          ..lineTo(x - h * 0.2, base)
          ..close();
        canvas.drawPath(tree, Paint()..color = const Color(0xFFAEC6C4));
        canvas.drawLine(
          Offset(x, base - h * 0.7),
          Offset(x + h * 0.15, base - h * 0.12),
          Paint()
            ..color = const Color(0xFFF9FCFD)
            ..strokeWidth = 3,
        );
      }
    }
  }

  @override
  bool shouldRepaint(LandscapePainter oldDelegate) =>
      oldDelegate.design != design;
}

class _WeatherPainter extends CustomPainter {
  _WeatherPainter(this.design, this.elapsed) : super(repaint: elapsed);
  final BackgroundDesign design;
  final ValueNotifier<double> elapsed;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final time = elapsed.value * design.speed;
    if (design.effect == BackgroundEffect.clouds) {
      final paint = Paint()..color = design.particle;
      for (var i = 0; i < (4 * design.density).round().clamp(1, 8); i++) {
        final x =
            ((i * 137.0 + time * (2 + i * 0.4)) % (size.width + 100)) - 50;
        final y = size.height * (0.12 + i * 0.19);
        canvas.drawOval(
          Rect.fromCenter(center: Offset(x, y), width: 85, height: 18),
          paint,
        );
        canvas.drawOval(
          Rect.fromCenter(center: Offset(x - 13, y - 7), width: 37, height: 25),
          paint,
        );
        canvas.drawOval(
          Rect.fromCenter(center: Offset(x + 12, y - 5), width: 33, height: 23),
          paint,
        );
      }
      return;
    }
    final winter = design.effect == BackgroundEffect.snow;
    final snowHeight =
        math.min(size.height * 0.06, 24.0) * (time / 75).clamp(0.0, 1.0);
    final baseCount = winter
        ? (size.width * size.height / 8000).round().clamp(20, 35)
        : 12;
    final count = (baseCount * design.density).round().clamp(1, 60);
    for (var i = 0; i < count; i++) {
      final seed = (i * 0.61803398875) % 1;
      final speed = winter ? 13 + (i % 5) * 3.0 : 10 + (i % 4) * 2.0;
      final bottom = size.height - (winter ? snowHeight : 0);
      final y =
          ((seed * (size.height + 20) + time * speed) % (bottom + 20)) - 10;
      final x = ((i * 97.0) % size.width) + math.sin(time * 0.6 + i) * 10;
      if (winter) {
        canvas.drawCircle(
          Offset(x, y),
          1.2 + (i % 4) * 0.45,
          Paint()
            ..color = i.isEven ? design.particle : design.secondaryParticle,
        );
      } else {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(math.sin(time * 0.5 + i) + time * 0.15);
        final paint = Paint()
          ..color = i.isEven ? design.particle : design.secondaryParticle;
        final leaf = Path()
          ..moveTo(0, -5)
          ..quadraticBezierTo(7, -1, 0, 5)
          ..quadraticBezierTo(-5, 1, 0, -5)
          ..close();
        canvas.drawPath(leaf, paint);
        canvas.restore();
      }
    }
    if (winter && snowHeight > 0) {
      final top = size.height - snowHeight;
      final snow = Path()
        ..moveTo(0, top)
        ..cubicTo(
          size.width * 0.25,
          top - snowHeight * 0.15,
          size.width * 0.32,
          top + snowHeight * 0.2,
          size.width * 0.55,
          top,
        )
        ..quadraticBezierTo(
          size.width * 0.8,
          top - snowHeight * 0.2,
          size.width,
          top,
        )
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(snow, Paint()..color = const Color(0xFFFDFEFF));
    }
  }

  @override
  bool shouldRepaint(_WeatherPainter oldDelegate) =>
      oldDelegate.design != design || oldDelegate.elapsed != elapsed;
}
