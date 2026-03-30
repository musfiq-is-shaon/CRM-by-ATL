import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/theme_extensions.dart';

/// Preset swatches — refined, not oversaturated.
const List<Color> kPresetPalette = [
  Color(0xFF2563EB),
  Color(0xFF34A37C),
  Color(0xFF7C6CF0),
  Color(0xFFD9A23A),
  Color(0xFFE85D5D),
  Color(0xFF2EB8D4),
  Color(0xFF5B8AEE),
  Color(0xFF9B8AF5),
  Color(0xFF4ADE80),
  Color(0xFFF472B6),
  Color(0xFF94A3B8),
  Color(0xFF1E293B),
];

/// Shows a full-featured color picker sheet. Returns the selected color or null if dismissed.
Future<Color?> showPremiumColorPicker(
  BuildContext context, {
  required Color initialColor,
  List<Color>? recentColors,
  void Function(Color)? onColorChanged,
}) {
  return showModalBottomSheet<Color>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    barrierColor: Colors.black54,
    builder: (ctx) => _PremiumColorPickerBody(
      initialColor: initialColor,
      recentColors: recentColors ?? const [],
      onColorChanged: onColorChanged,
    ),
  );
}

class _PremiumColorPickerBody extends StatefulWidget {
  const _PremiumColorPickerBody({
    required this.initialColor,
    required this.recentColors,
    this.onColorChanged,
  });

  final Color initialColor;
  final List<Color> recentColors;
  final void Function(Color)? onColorChanged;

  @override
  State<_PremiumColorPickerBody> createState() =>
      _PremiumColorPickerBodyState();
}

class _PremiumColorPickerBodyState extends State<_PremiumColorPickerBody> {
  late HSVColor _hsv;
  late TextEditingController _hexCtrl;
  late TextEditingController _rCtrl;
  late TextEditingController _gCtrl;
  late TextEditingController _bCtrl;
  late TextEditingController _hCtrl;
  late TextEditingController _sCtrl;
  late TextEditingController _lCtrl;
  int _inputTab = 0;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initialColor);
    _hexCtrl = TextEditingController();
    _rCtrl = TextEditingController();
    _gCtrl = TextEditingController();
    _bCtrl = TextEditingController();
    _hCtrl = TextEditingController();
    _sCtrl = TextEditingController();
    _lCtrl = TextEditingController();
    _syncFields();
  }

  @override
  void dispose() {
    _hexCtrl.dispose();
    _rCtrl.dispose();
    _gCtrl.dispose();
    _bCtrl.dispose();
    _hCtrl.dispose();
    _sCtrl.dispose();
    _lCtrl.dispose();
    super.dispose();
  }

  Color get _color => _hsv.toColor();

  void _setFromHsv(HSVColor next) {
    setState(() {
      _hsv = next;
      _syncFields();
    });
    widget.onColorChanged?.call(_color);
  }

  void _syncFields() {
    final c = _color;
    _hexCtrl.text =
        '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    final r = (c.r * 255.0).round().clamp(0, 255);
    final g = (c.g * 255.0).round().clamp(0, 255);
    final b = (c.b * 255.0).round().clamp(0, 255);
    _rCtrl.text = r.toString();
    _gCtrl.text = g.toString();
    _bCtrl.text = b.toString();
    final hsl = _rgbToHsl(r, g, b);
    _hCtrl.text = hsl.$1.toStringAsFixed(1);
    _sCtrl.text = hsl.$2.toStringAsFixed(1);
    _lCtrl.text = hsl.$3.toStringAsFixed(1);
  }

  (double, double, double) _rgbToHsl(int r, int g, int b) {
    final rf = r / 255, gf = g / 255, bf = b / 255;
    final max = math.max(rf, math.max(gf, bf));
    final min = math.min(rf, math.min(gf, bf));
    final l = (max + min) / 2;
    if (max == min) return (0, 0, l * 100);
    final d = max - min;
    final s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    double h;
    if (max == rf) {
      h = (gf - bf) / d + (gf < bf ? 6 : 0);
    } else if (max == gf) {
      h = (bf - rf) / d + 2;
    } else {
      h = (rf - gf) / d + 4;
    }
    h /= 6;
    return (h * 360, s * 100, l * 100);
  }

  Color _hslToColor(double h, double s, double l) {
    var hh = h % 360;
    if (hh < 0) hh += 360;
    final ss = (s / 100).clamp(0.0, 1.0);
    final ll = (l / 100).clamp(0.0, 1.0);
    final c = (1 - (2 * ll - 1).abs()) * ss;
    final x = c * (1 - ((hh / 60) % 2 - 1).abs());
    final m = ll - c / 2;
    double rf;
    double gf;
    double bf;
    if (hh < 60) {
      rf = c;
      gf = x;
      bf = 0;
    } else if (hh < 120) {
      rf = x;
      gf = c;
      bf = 0;
    } else if (hh < 180) {
      rf = 0;
      gf = c;
      bf = x;
    } else if (hh < 240) {
      rf = 0;
      gf = x;
      bf = c;
    } else if (hh < 300) {
      rf = x;
      gf = 0;
      bf = c;
    } else {
      rf = c;
      gf = 0;
      bf = x;
    }
    return Color.fromARGB(
      (_hsv.alpha * 255).round(),
      ((rf + m) * 255).round().clamp(0, 255),
      ((gf + m) * 255).round().clamp(0, 255),
      ((bf + m) * 255).round().clamp(0, 255),
    );
  }

  void _applyHex() {
    var s = _hexCtrl.text.trim();
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length == 6) s = 'FF$s';
    final v = int.tryParse(s, radix: 16);
    if (v != null) {
      _setFromHsv(HSVColor.fromColor(Color(v)));
    }
  }

  void _applyRgb() {
    final r = int.tryParse(_rCtrl.text) ?? 0;
    final g = int.tryParse(_gCtrl.text) ?? 0;
    final b = int.tryParse(_bCtrl.text) ?? 0;
    _setFromHsv(
      HSVColor.fromColor(
        Color.fromARGB(
          (_hsv.alpha * 255).round(),
          r.clamp(0, 255),
          g.clamp(0, 255),
          b.clamp(0, 255),
        ),
      ),
    );
  }

  void _applyHsl() {
    final h = double.tryParse(_hCtrl.text) ?? 0;
    final s = double.tryParse(_sCtrl.text) ?? 0;
    final l = double.tryParse(_lCtrl.text) ?? 0;
    final c = _hslToColor(h, s, l);
    _setFromHsv(HSVColor.fromColor(c));
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final h = MediaQuery.sizeOf(context).height * 0.92;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: h,
        child: Material(
          color: cs.surfaceContainerHigh,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Text(
                      'Accent color',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, _color),
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  children: [
                    Center(
                      child: AnimatedContainer(
                        key: ValueKey(_color.toARGB32()),
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: AppElevation.cardDark(_color),
                          border: Border.all(
                            color: cs.outlineVariant,
                            width: 2,
                          ),
                          gradient: RadialGradient(
                            colors: [_color, _color.withOpacity(0.88)],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _TonalPalettePreview(seedColor: _color),
                    const SizedBox(height: 20),
                    _HueBar(
                      hsv: _hsv,
                      onChanged: (hue) => _setFromHsv(_hsv.withHue(hue)),
                    ),
                    const SizedBox(height: 16),
                    _SVSquare(
                      hsv: _hsv,
                      onChanged: (s, v) =>
                          _setFromHsv(_hsv.withSaturation(s).withValue(v)),
                    ),
                    const SizedBox(height: 16),
                    _AlphaSlider(
                      hsv: _hsv,
                      onChanged: (a) => _setFromHsv(_hsv.withAlpha(a)),
                    ),
                    const SizedBox(height: 20),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 0, label: Text('HEX')),
                        ButtonSegment(value: 1, label: Text('RGB')),
                        ButtonSegment(value: 2, label: Text('HSL')),
                      ],
                      selected: {_inputTab},
                      onSelectionChanged: (s) =>
                          setState(() => _inputTab = s.first),
                    ),
                    const SizedBox(height: 12),
                    if (_inputTab == 0)
                      TextField(
                        controller: _hexCtrl,
                        decoration: const InputDecoration(
                          labelText: 'HEX',
                          hintText: '#RRGGBB',
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9a-fA-F#]'),
                          ),
                        ],
                        onSubmitted: (_) => _applyHex(),
                        onEditingComplete: _applyHex,
                      ),
                    if (_inputTab == 1)
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _rCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'R'),
                              onSubmitted: (_) => _applyRgb(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _gCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'G'),
                              onSubmitted: (_) => _applyRgb(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _bCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'B'),
                              onSubmitted: (_) => _applyRgb(),
                            ),
                          ),
                        ],
                      ),
                    if (_inputTab == 2)
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _hCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'H°',
                              ),
                              onSubmitted: (_) => _applyHsl(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _sCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'S%',
                              ),
                              onSubmitted: (_) => _applyHsl(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _lCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'L%',
                              ),
                              onSubmitted: (_) => _applyHsl(),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 24),
                    Text(
                      'Presets',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final p in kPresetPalette)
                          _SwatchDot(
                            color: p,
                            selected: _color.toARGB32() == p.toARGB32(),
                            onTap: () => _setFromHsv(HSVColor.fromColor(p)),
                          ),
                      ],
                    ),
                    if (widget.recentColors.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Recent',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final p in widget.recentColors)
                            _SwatchDot(
                              color: p,
                              selected: _color.toARGB32() == p.toARGB32(),
                              onTap: () => _setFromHsv(HSVColor.fromColor(p)),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwatchDot extends StatelessWidget {
  const _SwatchDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withOpacity(0.4),
            width: selected ? 3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.35),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
}

/// Material 3 tonal roles preview for the chosen seed color (matches system palette feel).
class _TonalPalettePreview extends StatelessWidget {
  const _TonalPalettePreview({required this.seedColor});

  final Color seedColor;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final cs = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    final tt = Theme.of(context).textTheme;
    final outline = Theme.of(context).colorScheme.outlineVariant;
    final tiles = <({Color color, String label})>[
      (color: cs.primary, label: 'Primary'),
      (color: cs.primaryContainer, label: 'Primary c.'),
      (color: cs.secondaryContainer, label: 'Secondary'),
      (color: cs.tertiaryContainer, label: 'Tertiary'),
      (color: cs.error, label: 'Error'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tonal palette',
          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < tiles.length; i++)
              Expanded(
                child: Tooltip(
                  message: tiles[i].label,
                  child: AspectRatio(
                    aspectRatio: 1.15,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: tiles[i].color,
                        border: Border(
                          right: i < tiles.length - 1
                              ? BorderSide(color: outline.withOpacity(0.4))
                              : BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _HueBar extends StatelessWidget {
  const _HueBar({required this.hsv, required this.onChanged});

  final HSVColor hsv;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hue', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: SizedBox(
                height: 28,
                child: Stack(
                  children: [
                    CustomPaint(
                      size: Size(w, 28),
                      painter: _HueGradientPainter(),
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 28,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 11,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 16,
                        ),
                      ),
                      child: Slider(
                        value: hsv.hue.clamp(0, 359.99),
                        max: 359.99,
                        onChanged: (v) => onChanged(v),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HueGradientPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    const colors = [
      Color(0xFFFF0000),
      Color(0xFFFF00FF),
      Color(0xFF0000FF),
      Color(0xFF00FFFF),
      Color(0xFF00FF00),
      Color(0xFFFFFF00),
      Color(0xFFFF0000),
    ];
    final shader = LinearGradient(colors: colors).createShader(rect);
    final paint = Paint()..shader = shader;
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SVSquare extends StatelessWidget {
  const _SVSquare({required this.hsv, required this.onChanged});

  final HSVColor hsv;
  final void Function(double s, double v) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Saturation & brightness',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (context, c) {
              final sz = c.maxWidth;
              return GestureDetector(
                onPanDown: (d) => _handle(d.localPosition, sz),
                onPanUpdate: (d) => _handle(d.localPosition, sz),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: SizedBox(
                    width: sz,
                    height: sz,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CustomPaint(painter: _SVPainter(hue: hsv.hue)),
                        CustomPaint(
                          painter: _SVIndicatorPainter(
                            saturation: hsv.saturation,
                            value: hsv.value,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _handle(Offset pos, double sz) {
    final s = (pos.dx / sz).clamp(0.0, 1.0);
    final v = (1 - pos.dy / sz).clamp(0.0, 1.0);
    onChanged(s, v);
  }
}

class _SVPainter extends CustomPainter {
  _SVPainter({required this.hue});

  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final hColor = HSVColor.fromAHSV(1, hue, 1, 1).toColor();
    final rect = Offset.zero & size;
    final gradH = LinearGradient(
      colors: [Colors.white, hColor],
    ).createShader(rect);
    final gradV = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.transparent, Colors.black],
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = gradH);
    canvas.drawRect(rect, Paint()..shader = gradV);
  }

  @override
  bool shouldRepaint(covariant _SVPainter oldDelegate) =>
      oldDelegate.hue != hue;
}

class _SVIndicatorPainter extends CustomPainter {
  _SVIndicatorPainter({required this.saturation, required this.value});

  final double saturation;
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final x = saturation * size.width;
    final y = (1 - value) * size.height;
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(x, y), 10, paint);
    canvas.drawCircle(
      Offset(x, y),
      9,
      Paint()
        ..color = Colors.black.withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _SVIndicatorPainter oldDelegate) =>
      oldDelegate.saturation != saturation || oldDelegate.value != value;
}

class _AlphaSlider extends StatelessWidget {
  const _AlphaSlider({required this.hsv, required this.onChanged});

  final HSVColor hsv;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final base = hsv.toColor().withOpacity(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Opacity', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final w = c.maxWidth;
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: SizedBox(
                      height: 28,
                      width: w,
                      child: Stack(
                        children: [
                          CustomPaint(
                            size: Size(w, 28),
                            painter: _CheckerboardPainter(),
                          ),
                          Container(
                            height: 28,
                            width: w,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [base.withOpacity(0), base],
                              ),
                            ),
                          ),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 28,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 11,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 16,
                              ),
                            ),
                            child: Slider(
                              value: hsv.alpha.clamp(0, 1),
                              onChanged: onChanged,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Text('${(hsv.alpha * 100).round()}%'),
          ],
        ),
      ],
    );
  }
}

class _CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const a = Color(0xFFE0E0E0);
    const b = Color(0xFFBDBDBD);
    const tile = 6.0;
    for (double y = 0; y < size.height; y += tile) {
      for (double x = 0; x < size.width; x += tile) {
        final i = ((x / tile).floor() + (y / tile).floor()) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(x, y, tile, tile),
          Paint()..color = i ? a : b,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
