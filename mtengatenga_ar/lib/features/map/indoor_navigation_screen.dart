import 'dart:math' as math;
import 'package:flutter/material.dart';

class IndoorNavigationScreen extends StatefulWidget {
  const IndoorNavigationScreen({super.key});

  @override
  State<IndoorNavigationScreen> createState() => _IndoorNavigationScreenState();
}

class _IndoorNavigationScreenState extends State<IndoorNavigationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bgMap = Color(0xFFFDF5E6); // map-base :contentReference[oaicite:1]{index=1}
    const dark = Color(0xFF5D4037); // surface-dark :contentReference[oaicite:2]{index=2}
    const accent = Color(0xFFA0522D); // accent :contentReference[oaicite:3]{index=3}

    return Scaffold(
      backgroundColor: bgMap,
      body: Stack(
        children: [
          Column(
            children: [
              _TopBar(
                title: 'Museum Map',
                onBack: () => Navigator.pop(context),
                onInfo: () => _snack(context, 'Info (UI only)'),
              ),
              Expanded(
                child: Stack(
                  children: [
                    // Map area
                    Positioned.fill(
                      child: _MapCanvas(pulse: _pulse),
                    ),

                    // Overlays
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Column(
                          children: [
                            _SearchBar(onTap: () => _snack(context, 'Search (UI only)')),
                            const Spacer(),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Spacer(),
                                _RightControls(
                                  onZoomIn: () => _snack(context, 'Zoom + (UI only)'),
                                  onZoomOut: () => _snack(context, 'Zoom - (UI only)'),
                                  onMyLocation: () => _snack(context, 'My location (UI only)'),
                                  onLayers: () => _snack(context, 'Layers (UI only)'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Start nav button aligned to right (like HTML)
                            Row(
                              children: [
                                const Spacer(),
                                _StartNavButton(onTap: () => _snack(context, 'Start navigation (UI only)')),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Bottom info card
                            const _LocationCard(),
                            const SizedBox(height: 12),

                            // Bottom quick actions
                            _QuickActions(
                              onFind: () => _snack(context, 'Find exhibit (UI only)'),
                              onRestroom: () => _snack(context, 'Restroom (UI only)'),
                              onExit: () => _snack(context, 'Exit (UI only)'),
                              onCafe: () => _snack(context, 'Cafe (UI only)'),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // small bottom strip in HTML
              Container(height: 18, color: const Color(0xFFFAF0E6)), // surface-light :contentReference[oaicite:4]{index=4}
            ],
          ),
        ],
      ),
    );
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.onBack, required this.onInfo});
  final String title;
  final VoidCallback onBack;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    const dark = Color(0xFF5D4037); // surface-dark :contentReference[oaicite:5]{index=5}
    const light = Color(0xFFFAF0E6); // surface-light :contentReference[oaicite:6]{index=6}

    return Container(
      decoration: const BoxDecoration(
        color: dark,
        boxShadow: [BoxShadow(blurRadius: 10, offset: Offset(0, 2), color: Color(0x22000000))],
      ),
      padding: const EdgeInsets.fromLTRB(10, 44, 10, 10),
      child: Row(
        children: [
          _CircleIconButton(icon: Icons.arrow_back, color: light, onTap: onBack),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: light,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _CircleIconButton(icon: Icons.info_outline, color: light, onTap: onInfo),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.color, required this.onTap});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        width: 48,
        height: 48,
        child: Icon(icon, color: color),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFFFAF0E6), // surface-light :contentReference[oaicite:7]{index=7}
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE6DCCA)), // grid line color :contentReference[oaicite:8]{index=8}
          boxShadow: const [BoxShadow(blurRadius: 12, offset: Offset(0, 6), color: Color(0x11000000))],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: const [
            Icon(Icons.search, color: Color(0xFF8D8D8D)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Search exhibits, restrooms...',
                style: TextStyle(
                  color: Color(0xFF9E9E9E),
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RightControls extends StatelessWidget {
  const _RightControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onMyLocation,
    required this.onLayers,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onMyLocation;
  final VoidCallback onLayers;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFAF0E6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE6DCCA)),
            boxShadow: const [BoxShadow(blurRadius: 10, offset: Offset(0, 4), color: Color(0x11000000))],
          ),
          child: Column(
            children: [
              _SquareControl(icon: Icons.add, onTap: onZoomIn),
              Container(height: 1, width: 52, color: const Color(0xFFE6DCCA)),
              _SquareControl(icon: Icons.remove, onTap: onZoomOut),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _FloatingSquare(icon: Icons.my_location, tint: const Color(0xFFA0522D), onTap: onMyLocation),
        const SizedBox(height: 18),
        _FloatingSquare(icon: Icons.layers_outlined, tint: const Color(0xFF6D4C41), onTap: onLayers),
      ],
    );
  }
}

class _SquareControl extends StatelessWidget {
  const _SquareControl({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 52,
        height: 52,
        child: Icon(icon, color: const Color(0xFF6D4C41)),
      ),
    );
  }
}

class _FloatingSquare extends StatelessWidget {
  const _FloatingSquare({required this.icon, required this.tint, required this.onTap});
  final IconData icon;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFFFAF0E6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE6DCCA)),
          boxShadow: const [BoxShadow(blurRadius: 10, offset: Offset(0, 4), color: Color(0x11000000))],
        ),
        child: Icon(icon, color: tint),
      ),
    );
  }
}

class _StartNavButton extends StatelessWidget {
  const _StartNavButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const dark = Color(0xFF5D4037); // surface-dark :contentReference[oaicite:9]{index=9}
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: dark,
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [BoxShadow(blurRadius: 16, offset: Offset(0, 8), color: Color(0x22000000))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.near_me, color: Colors.white),
            SizedBox(width: 12),
            Text(
              'Start Navigation',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard();

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFA0522D); // accent :contentReference[oaicite:10]{index=10}
    const dark = Color(0xFF3E2723); // background-dark :contentReference[oaicite:11]{index=11}

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF0E6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x80E6DCCA)),
        boxShadow: const [BoxShadow(blurRadius: 18, offset: Offset(0, 10), color: Color(0x11000000))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'CURRENT LOCATION',
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Hall of Ancestors',
                  style: TextStyle(
                    color: dark,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.directions_walk, size: 16, color: Color(0xFF6D4C41)),
                    SizedBox(width: 8),
                    Text(
                      '2 min to Textiles Gallery',
                      style: TextStyle(
                        color: Color(0xFF6D4C41),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE6DCCA)),
              image: const DecorationImage(
                fit: BoxFit.cover,
                image: NetworkImage(
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuAd5Gia7eWiK5DcR8UjUkfgst5StOLseqckO-0fGk6-DLIorT2Oq4Ux779lm2PbfiQ_sTb0-gx10C5fncu9tok9nFs6MN4zh1mbpoGRaHFMiwiGN5nR6lVkO4BDtpjsjGM8FSNjFb7GqVmjoTDb7ezgcjq0LZHedFBBUmhybJBYXxgHy4PwDuKalAT2Oj4C1MVfGrI6ZqQTyNYmivZE2f3RLdYiYVlc1Krq2_OhCsKP7HmD9QXerKHYldCBbWOwEvtnl3eCWDxB2ohD',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onFind,
    required this.onRestroom,
    required this.onExit,
    required this.onCafe,
  });

  final VoidCallback onFind;
  final VoidCallback onRestroom;
  final VoidCallback onExit;
  final VoidCallback onCafe;

  @override
  Widget build(BuildContext context) {
    const dark = Color(0xFF5D4037);

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _Pill(icon: Icons.search, text: 'Find Exhibit', onTap: onFind, color: dark),
          const SizedBox(width: 10),
          _Pill(icon: Icons.wc, text: 'Restroom', onTap: onRestroom, color: dark),
          const SizedBox(width: 10),
          _Pill(icon: Icons.door_front_door_outlined, text: 'Exit', onTap: onExit, color: dark),
          const SizedBox(width: 10),
          _Pill(icon: Icons.local_cafe, text: 'Cafe', onTap: onCafe, color: dark),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, required this.onTap, required this.color});
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [BoxShadow(blurRadius: 10, offset: Offset(0, 6), color: Color(0x22000000))],
        ),
        child: Row(
          children: [
            const Icon(Icons.circle, size: 0), // keeps layout consistent
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              text,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapCanvas extends StatelessWidget {
  const _MapCanvas({required this.pulse});
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        // grid pattern like .map-pattern :contentReference[oaicite:12]{index=12}
        color: Color(0xFFFDF5E6),
      ),
      child: CustomPaint(
        painter: _GridPainter(),
        child: Center(
          child: SizedBox(
            width: 800,
            height: 800,
            child: Stack(
              children: [
                // “Rooms” + corridors
                Positioned.fill(
                  child: CustomPaint(
                    painter: _RoomsPainter(),
                  ),
                ),

                // You are here with pulse ring
                Positioned(
                  left: 250 - 14,
                  top: 550 - 14,
                  child: AnimatedBuilder(
                    animation: pulse,
                    builder: (_, __) {
                      final t = pulse.value;
                      final scale = 0.33 + 0.90 * t;
                      final opacity = (1.0 - t).clamp(0.0, 1.0);

                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Opacity(
                            opacity: 0.6 * opacity,
                            child: Transform.scale(
                              scale: scale,
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFB22222), // you-are-here :contentReference[oaicite:13]{index=13}
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: const Color(0xFFB22222),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: const [
                                BoxShadow(blurRadius: 10, offset: Offset(0, 4), color: Color(0x22000000)),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // Destination pin
                Positioned(
                  left: 550 - 18,
                  top: 250 - 36,
                  child: _BouncingPin(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BouncingPin extends StatefulWidget {
  @override
  State<_BouncingPin> createState() => _BouncingPinState();
}

class _BouncingPinState extends State<_BouncingPin> with SingleTickerProviderStateMixin {
  late final AnimationController c;
  late final Animation<double> a;

  @override
  void initState() {
    super.initState();
    c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    a = CurvedAnimation(parent: c, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: a,
      builder: (_, __) {
        final dy = -6 * a.value;
        return Transform.translate(
          offset: Offset(0, dy),
          child: const Icon(Icons.location_on, color: Color(0xFFA0522D), size: 44),
        );
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE6DCCA)
      ..strokeWidth = 1;

    const step = 40.0; // background-size 40px 40px :contentReference[oaicite:14]{index=14}
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RoomsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // This is a Flutter version of the SVG in your HTML. :contentReference[oaicite:15]{index=15}
    final border = Paint()
      ..color = const Color(0xFF8B4513)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final outer = Rect.fromLTWH(100, 100, 600, 600);
    canvas.drawRect(outer, Paint()..color = const Color(0xFFFFF8DC));
    canvas.drawRect(outer, border);

    void room(Rect r, Color c) {
      final p = Paint()..color = c.withOpacity(0.40);
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(8));
      canvas.drawRRect(rr, p);
    }

    room(const Rect.fromLTWH(120, 120, 260, 260), const Color(0xFFA0522D)); // hall
    room(const Rect.fromLTWH(400, 120, 280, 200), const Color(0xFFDAA520)); // textiles
    room(const Rect.fromLTWH(400, 340, 280, 340), const Color(0xFFCD5C5C)); // pottery
    room(const Rect.fromLTWH(120, 400, 260, 280), const Color(0xFF556B2F)); // entrance

    // corridors cross
    final corridor = Paint()
      ..color = const Color(0xFF5D4037)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(const Offset(380, 120), const Offset(380, 700), corridor);
    canvas.drawLine(const Offset(120, 380), const Offset(700, 380), corridor);

    // “gaps” blocks (doors)
    canvas.drawRect(const Rect.fromLTWH(360, 240, 40, 12), Paint()..color = const Color(0xFFFDF5E6));
    canvas.drawRect(const Rect.fromLTWH(240, 374, 60, 12), Paint()..color = const Color(0xFFFDF5E6));

    // dashed route
    final dashPaint = Paint()
      ..color = const Color(0xFF5D4037).withOpacity(0.70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(250, 550)
      ..lineTo(250, 250)
      ..lineTo(550, 250);

    _drawDashedPath(canvas, path, dashPaint, dash: 15, gap: 10);

    // arrows (triangles)
    _triangle(canvas, const Offset(250, 400), 0);
    _triangle(canvas, const Offset(250, 300), 0);
    _triangle(canvas, const Offset(400, 250), math.pi / 2); // rotated
  }

  void _triangle(Canvas canvas, Offset center, double rotation) {
    final p = Paint()..color = const Color(0xFF5D4037);
    final path = Path()
      ..moveTo(center.dx, center.dy - 12)
      ..lineTo(center.dx - 10, center.dy + 4)
      ..lineTo(center.dx + 10, center.dy + 4)
      ..close();

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawPath(path, p);
    canvas.restore();
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint, {required double dash, required double gap}) {
    for (final metric in path.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        final len = math.min(dash, metric.length - dist);
        final seg = metric.extractPath(dist, dist + len);
        canvas.drawPath(seg, paint);
        dist += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
