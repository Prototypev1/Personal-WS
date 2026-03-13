import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

void main() {
  runApp(const NeonApp());
}

class NeonApp extends StatelessWidget {
  const NeonApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: NeonScreen(),
    );
  }
}

const double kTubeHalf = 42.0;
const double kFadeX = 0.20;
const int kLanes = 6;
const double kCollisionStart = 5000 * 0.55;
const double kAtomDuration = (5000 - kCollisionStart) * 0.83;
const int kBlinkMs = 700;

class StreamParticle {
  final int dir;
  final int slot;
  final int total;
  late double baseY;
  double x = 0, y = 0, r = 0, spd = 0;
  int green = 0;
  List<Offset> trail = [];

  StreamParticle(this.dir, this.slot, this.total);

  void init(double W, double cy, {bool initial = true}) {
    final band = (kTubeHalf * 2 - 10) / total;
    baseY = cy - kTubeHalf + 5 + slot * band + band / 2;
    reset(W, cy, initial: initial);
  }

  void reset(double W, double cy, {bool initial = false}) {
    final band = (kTubeHalf * 2 - 10) / total;
    final rng = Random();
    y = baseY + (rng.nextDouble() - 0.5) * band * 0.3;
    spd = 3 + rng.nextDouble() * 2.5;
    r = 1.5 + rng.nextDouble() * 2;
    green = 90 + rng.nextInt(90);
    trail = [];
    x = initial ? rng.nextDouble() * W : (dir == 1 ? -10 : W + 10);
  }

  void update(double W, double cy, double elapsed) {
    final accel = 1 + (elapsed / 5000) * 3;
    trail.insert(0, Offset(x, y));
    if (trail.length > 12) trail.removeLast();
    x += dir * spd * accel;
    if (dir == 1 && x > W + 15) reset(W, cy);
    if (dir == -1 && x < -15) reset(W, cy);
  }
}

class CollisionAtom {
  final int dir;
  double x = 0, y = 0;
  List<Offset> trail = [];

  CollisionAtom(this.dir);

  void reset(double W, double CY) {
    x = dir == 1 ? -20 : W + 20;
    y = CY;
    trail = [];
  }

  void update(double W, double CX, double CY, double prog) {
    final t = prog * prog * prog;
    trail.insert(0, Offset(x, y));
    if (trail.length > 40) trail.removeLast();
    final sx = dir == 1 ? -20.0 : W + 20.0;
    x = sx + (CX - sx) * t;
    y = CY;
  }
}

enum Phase { run, nova, hold, welcome }

class NeonPainter extends CustomPainter {
  final double elapsed;
  final List<StreamParticle> particles;
  final CollisionAtom atomL;
  final CollisionAtom atomR;
  final bool atomsActive;
  final bool blinkOn;
  final Phase phase;
  final double novaRadius;
  final double maxNovaRadius;

  NeonPainter({
    required this.elapsed,
    required this.particles,
    required this.atomL,
    required this.atomR,
    required this.atomsActive,
    required this.blinkOn,
    required this.phase,
    required this.novaRadius,
    required this.maxNovaRadius,
  });

  double _fade(double x, double W) {
    final fw = W * kFadeX;
    if (x < fw) return (x / fw).clamp(0, 1);
    if (x > W - fw) return ((W - x) / fw).clamp(0, 1);
    return 1.0;
  }

  void _drawTube(Canvas canvas, double W, double H, double CX, double CY) {
    final top = CY - kTubeHalf;
    final bot = CY + kTubeHalf;
    final fw = W * kFadeX;

    final grad = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: const [0, 0.06, 0.16, 0.30, 0.42, 0.50, 0.58, 0.70, 0.84, 0.94, 1.0],
      colors: [
        const Color(0xFF1A5028),
        const Color(0xFF164826).withValues(alpha: 0.92),
        const Color(0xFF103A1E).withValues(alpha: 0.72),
        const Color(0xFF0A2814).withValues(alpha: 0.42),
        const Color(0xFF05140A).withValues(alpha: 0.14),
        Colors.transparent,
        const Color(0xFF05140A).withValues(alpha: 0.14),
        const Color(0xFF0A2814).withValues(alpha: 0.42),
        const Color(0xFF103A1E).withValues(alpha: 0.72),
        const Color(0xFF164826).withValues(alpha: 0.92),
        const Color(0xFF1A5028),
      ],
    );

    final tubeRect = Rect.fromLTWH(0, top, W, kTubeHalf * 2);
    final paint = Paint()..shader = grad.createShader(tubeRect);
    canvas.drawRect(tubeRect, paint);

    final fadeL = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [Colors.black, Colors.transparent],
    );
    canvas.drawRect(
      Rect.fromLTWH(0, top, fw, kTubeHalf * 2),
      Paint()..shader = fadeL.createShader(Rect.fromLTWH(0, top, fw, kTubeHalf * 2)),
    );

    final fadeR = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [Colors.transparent, Colors.black],
    );
    canvas.drawRect(
      Rect.fromLTWH(W - fw, top, fw, kTubeHalf * 2),
      Paint()..shader = fadeR.createShader(Rect.fromLTWH(W - fw, top, fw, kTubeHalf * 2)),
    );

    final edgePaint = Paint()..color = const Color(0xFF28603A).withOpacity(0.8);
    canvas.drawRect(Rect.fromLTWH(fw, top, W - fw * 2, 1.2), edgePaint);
    canvas.drawRect(Rect.fromLTWH(fw, bot - 1.2, W - fw * 2, 1.2), edgePaint);
  }

  void _drawMesh(Canvas canvas, double W, double CY) {
    final fw = W * kFadeX;
    final tubeW = W - fw * 2;
    final diagH = kTubeHalf * 2;
    const spacing = 14.0;
    const steps = 8;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(fw, CY - kTubeHalf, tubeW, kTubeHalf * 2));

    for (final dir in [1, -1]) {
      for (double offset = -diagH; offset < tubeW + diagH; offset += spacing) {
        for (int s = 0; s < steps; s++) {
          final t0 = s / steps;
          final t1 = (s + 1) / steps;
          final x0 = fw + offset + diagH * (dir == 1 ? t0 : (1 - t0));
          final y0 = (CY - kTubeHalf) + diagH * t0;
          final x1 = fw + offset + diagH * (dir == 1 ? t1 : (1 - t1));
          final y1 = (CY - kTubeHalf) + diagH * t1;
          final yMid = (y0 + y1) / 2;
          final dist = (yMid - CY).abs() / kTubeHalf;
          final alpha = dist * dist * 0.28 * _fade((x0 + x1) / 2, W);
          if (alpha < 0.01) continue;
          canvas.drawLine(
            Offset(x0, y0),
            Offset(x1, y1),
            Paint()
              ..color = Color.fromRGBO(150, 148, 142, alpha)
              ..strokeWidth = 0.7
              ..style = PaintingStyle.stroke,
          );
        }
      }
    }
    canvas.restore();
  }

  void _drawStreamParticles(Canvas canvas, double W, double CY) {
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, CY - kTubeHalf, W, kTubeHalf * 2));
    for (final p in particles) {
      final fa = _fade(p.x, W);
      for (int i = 1; i < p.trail.length; i++) {
        final ta = _fade(p.trail[i].dx, W);
        final a = (1 - i / p.trail.length) * 0.35 * min(fa, ta);
        final r = p.r * (1 - i / p.trail.length * 0.5);
        canvas.drawCircle(
          p.trail[i],
          r,
          Paint()..color = Color.fromRGBO(20, p.green, 35, a),
        );
      }
      canvas.drawCircle(
        Offset(p.x, p.y),
        p.r,
        Paint()..color = Color.fromRGBO(20, p.green, 35, fa),
      );
    }
    canvas.restore();
  }

  void _drawAtom(Canvas canvas, CollisionAtom a, double W, double CY) {
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, CY - kTubeHalf, W, kTubeHalf * 2));
    final fa = _fade(a.x, W);
    final trailBase = blinkOn ? const Color.fromRGBO(190, 140, 255, 1) : const Color.fromRGBO(95, 60, 170, 1);

    for (int i = 1; i < a.trail.length - 1; i++) {
      final tf = _fade(a.trail[i].dx, W);
      final frac = i / a.trail.length;
      final alpha = (1 - frac) * 0.85 * min(fa, tf);
      final lw = max(0.3, 3.5 * (1 - frac));
      canvas.drawLine(
        a.trail[i],
        a.trail[i + 1],
        Paint()
          ..color = trailBase.withOpacity(alpha)
          ..strokeWidth = lw
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }

    canvas.drawCircle(
      Offset(a.x, a.y),
      5.5,
      Paint()..color = const Color.fromRGBO(215, 175, 255, 1).withOpacity(fa),
    );
    canvas.drawCircle(
      Offset(a.x, a.y),
      2.8,
      Paint()..color = const Color.fromRGBO(255, 250, 255, 1).withOpacity(fa),
    );
    canvas.restore();
  }

  void _drawNova(Canvas canvas, double W, double H, double CX, double CY) {
    if (phase == Phase.run) return;
    if (phase == Phase.welcome) {
      canvas.drawRect(Rect.fromLTWH(0, 0, W, H), Paint()..color = Colors.white);
      return;
    }

    final r = novaRadius.clamp(0.01, maxNovaRadius);
    final gradient = RadialGradient(
      colors: [
        Colors.white,
        Colors.white.withOpacity(0.97),
        Colors.white.withOpacity(0.7),
        Colors.white.withOpacity(0),
      ],
      stops: const [0, 0.3, 0.7, 1.0],
    );
    final rect = Rect.fromCircle(center: Offset(CX, CY), radius: r);
    canvas.drawCircle(
      Offset(CX, CY),
      r,
      Paint()..shader = gradient.createShader(rect),
    );

    if (r > 10) {
      final ringAlpha = max(0.0, 0.8 - r / maxNovaRadius);
      canvas.drawCircle(
        Offset(CX, CY),
        r * 0.95,
        Paint()
          ..color = const Color.fromRGBO(220, 200, 255, 1).withOpacity(ringAlpha)
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke,
      );
    }

    if (phase == Phase.hold) {
      canvas.drawRect(Rect.fromLTWH(0, 0, W, H), Paint()..color = Colors.white);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final W = size.width;
    final H = size.height;
    final CX = W / 2;
    final CY = H / 2;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, W, H),
      Paint()..color = Colors.black,
    );

    _drawTube(canvas, W, H, CX, CY);
    _drawMesh(canvas, W, CY);
    _drawStreamParticles(canvas, W, CY);

    if (atomsActive) {
      _drawAtom(canvas, atomL, W, CY);
      _drawAtom(canvas, atomR, W, CY);
    }

    _drawNova(canvas, W, H, CX, CY);
  }

  @override
  bool shouldRepaint(NeonPainter old) => true;
}

class NeonScreen extends StatefulWidget {
  const NeonScreen({super.key});
  @override
  State<NeonScreen> createState() => _NeonScreenState();
}

class _NeonScreenState extends State<NeonScreen> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  double _elapsed = 0;
  double? _startMs;

  final List<StreamParticle> _particles = [];
  late CollisionAtom _atomL;
  late CollisionAtom _atomR;

  bool _atomsActive = false;
  bool _colFired = false;
  bool _blinkOn = true;
  double _lastBlink = 0;

  Phase _phase = Phase.run;
  double _novaRadius = 0;
  double _novaMaxRadius = 0;
  double _novaHoldStart = 0;

  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    _atomL = CollisionAtom(1);
    _atomR = CollisionAtom(-1);
    _ticker = createTicker(_onTick)..start();
  }

  void _initParticles(Size size) {
    _particles.clear();
    for (int i = 0; i < kLanes; i++) {
      final p = StreamParticle(1, i, kLanes);
      p.init(size.width, size.height / 2, initial: true);
      _particles.add(p);
    }
    for (int i = 0; i < kLanes; i++) {
      final p = StreamParticle(-1, i, kLanes);
      p.init(size.width, size.height / 2, initial: true);
      _particles.add(p);
    }
    _atomL.reset(size.width, size.height / 2);
    _atomR.reset(size.width, size.height / 2);
    _novaMaxRadius = sqrt(size.width * size.width + size.height * size.height);
  }

  void _restart() {
    _startMs = null;
    _elapsed = 0;
    _atomsActive = false;
    _colFired = false;
    _blinkOn = true;
    _lastBlink = 0;
    _phase = Phase.run;
    _novaRadius = 0;
    _novaHoldStart = 0;
    _initParticles(_size);
  }

  void _onTick(Duration duration) {
    final ms = duration.inMicroseconds / 1000.0;
    _startMs ??= ms;
    final el = ms - _startMs!;
    _elapsed = el;

    if (_phase == Phase.welcome) return;

    final W = _size.width;
    final H = _size.height;
    final CY = H / 2;
    final CX = W / 2;

    if (ms - _lastBlink > kBlinkMs) {
      _blinkOn = !_blinkOn;
      _lastBlink = ms;
    }

    for (final p in _particles) {
      p.update(W, CY, el);
    }

    if (el > kCollisionStart && !_atomsActive && !_colFired) {
      _atomsActive = true;
    }

    if (_atomsActive && !_colFired) {
      final prog = ((el - kCollisionStart) / kAtomDuration).clamp(0.0, 1.0);
      _atomL.update(W, CX, CY, prog);
      _atomR.update(W, CX, CY, prog);
      if (prog >= 0.97) {
        _colFired = true;
        _atomsActive = false;
        _phase = Phase.nova;
        _novaRadius = 0;
      }
    }

    if (_phase == Phase.nova) {
      _novaRadius = min(_novaMaxRadius, _novaRadius + _novaMaxRadius * 0.22);
      if (_novaRadius >= _novaMaxRadius) {
        _phase = Phase.hold;
        _novaHoldStart = ms;
      }
    }

    if (_phase == Phase.hold) {
      if (ms - _novaHoldStart >= 100) {
        _phase = Phase.welcome;
      }
    }

    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxWidth * 0.45);
          if (_size != size && size.width > 0) {
            _size = size;
            SchedulerBinding.instance.addPostFrameCallback((_) {
              if (_particles.isEmpty) _initParticles(size);
            });
          }

          return GestureDetector(
            onTap: () {
              if (_phase == Phase.welcome) {
                setState(() => _restart());
              }
            },
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: Stack(
                children: [
                  CustomPaint(
                    size: size,
                    painter: NeonPainter(
                      elapsed: _elapsed,
                      particles: _particles,
                      atomL: _atomL,
                      atomR: _atomR,
                      atomsActive: _atomsActive,
                      blinkOn: _blinkOn,
                      phase: _phase,
                      novaRadius: _novaRadius,
                      maxNovaRadius: _novaMaxRadius,
                    ),
                  ),
                  if (_phase == Phase.welcome)
                    Container(
                      color: Colors.white,
                      child: Center(
                        child: _BlinkingText(
                          text: 'WELCOME',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 48,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 10,
                            color: Color(0xFF111111),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BlinkingText extends StatefulWidget {
  final String text;
  final TextStyle style;
  const _BlinkingText({required this.text, required this.style});

  @override
  State<_BlinkingText> createState() => _BlinkingTextState();
}

class _BlinkingTextState extends State<_BlinkingText> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..addListener(() {
        final v = _ctrl.value < 0.5;
        if (v != _visible) setState(() => _visible = v);
      })
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: _visible ? 1.0 : 0.0,
      child: Text(widget.text, style: widget.style),
    );
  }
}
