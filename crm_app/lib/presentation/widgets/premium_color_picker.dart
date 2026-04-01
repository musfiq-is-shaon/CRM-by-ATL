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
    backgroundColor: Colors.transparent,
    // Theme sets BottomSheetThemeData.showDragHandle: true — avoid a second bar in the body.
    showDragHandle: true,
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
  late FocusNode _hexFocusNode;
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
    _hexFocusNode = FocusNode();
    _hexFocusNode.addListener(_onHexFocusChange);
    _rCtrl = TextEditingController();
    _gCtrl = TextEditingController();
    _bCtrl = TextEditingController();
    _hCtrl = TextEditingController();
    _sCtrl = TextEditingController();
    _lCtrl = TextEditingController();
    _syncFields();
  }

  void _onHexFocusChange() {
    if (!_hexFocusNode.hasFocus) {
      _applyHex();
    }
  }

  @override
  void dispose() {
    _hexFocusNode.removeListener(_onHexFocusChange);
    _hexFocusNode.dispose();
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

  /// Parses #RGB, #RRGGBB, RRGGBB, #AARRGGBB / AARRGGBB (no #). Rejects partial/invalid lengths.
  Color? _tryParseUserHex(String raw) {
    var s = raw.trim();
    if (s.startsWith('#')) s = s.substring(1);
    s = s.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (s.isEmpty) return null;
    // CSS-style shorthand #RGB
    if (s.length == 3) {
      final chars = s.split('');
      s = chars.map((c) => '$c$c').join();
    }
    if (s.length == 6) {
      s = 'FF$s';
    } else if (s.length != 8) {
      return null;
    }
    final v = int.tryParse(s, radix: 16);
    if (v == null) return null;
    return Color(v);
  }

  void _applyHex() {
    final c = _tryParseUserHex(_hexCtrl.text);
    if (c != null) {
      _setFromHsv(HSVColor.fromColor(c));
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

  void _commitActiveInput() {
    switch (_inputTab) {
      case 0:
        _applyHex();
        break;
      case 1:
        _applyRgb();
        break;
      case 2:
        _applyHsl();
        break;
    }
  }

  String get _hexLabel {
    final c = _color;
    return '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = Theme.of(context).textTheme;
    final h = MediaQuery.sizeOf(context).height * 0.92;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: h,
        child: Material(
          color: cs.surface,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Accent color',
                      style: tt.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Used for primary actions, toggles, and highlights.',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _color.withValues(alpha: 0.22),
                            cs.surfaceContainerHighest.withValues(alpha: 0.85),
                          ],
                        ),
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.lg,
                          horizontal: AppSpacing.md,
                        ),
                        child: Column(
                          children: [
                            AnimatedContainer(
                              key: ValueKey(_color.toARGB32()),
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: AppElevation.cardDark(_color),
                                border: Border.all(
                                  color: cs.outline.withValues(alpha: 0.35),
                                  width: 3,
                                ),
                                color: _color,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              _hexLabel,
                              style: tt.titleMedium?.copyWith(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.5,
                                color: cs.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _TonalPalettePreview(seedColor: _color),
                    const SizedBox(height: AppSpacing.lg),
                    _HueBar(
                      hsv: _hsv,
                      onChanged: (hue) => _setFromHsv(_hsv.withHue(hue)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SVSquare(
                      hsv: _hsv,
                      onChanged: (s, v) =>
                          _setFromHsv(_hsv.withSaturation(s).withValue(v)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _AlphaSlider(
                      hsv: _hsv,
                      onChanged: (a) => _setFromHsv(_hsv.withAlpha(a)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(child: Divider(color: cs.outlineVariant.withValues(alpha: 0.5))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                          child: Text(
                            'Fine-tune',
                            style: tt.labelLarge?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: cs.outlineVariant.withValues(alpha: 0.5))),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
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
                    const SizedBox(height: AppSpacing.sm),
                    if (_inputTab == 0)
                      TextField(
                        controller: _hexCtrl,
                        focusNode: _hexFocusNode,
                        style: tt.bodyLarge?.copyWith(
                          color: cs.onSurface,
                          fontFamily: 'monospace',
                          letterSpacing: 0.2,
                        ),
                        cursorColor: cs.primary,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.done,
                        keyboardType: TextInputType.visiblePassword,
                        decoration: InputDecoration(
                          labelText: 'HEX',
                          hintText: '#RRGGBB',
                          labelStyle: TextStyle(color: cs.onSurfaceVariant),
                          hintStyle: TextStyle(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9a-fA-F#]'),
                          ),
                        ],
                        onSubmitted: (_) {
                          _applyHex();
                          FocusScope.of(context).unfocus();
                        },
                        onEditingComplete: () {
                          _applyHex();
                          FocusScope.of(context).unfocus();
                        },
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
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Presets',
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
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
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Recent',
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
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
              SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          _commitActiveInput();
                          Navigator.pop(context, _color);
                        },
                        child: const Text('Apply color'),
                      ),
                    ),
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
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(
              color: selected
                  ? cs.primary
                  : cs.outline.withValues(alpha: 0.45),
              width: selected ? 3 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.38),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
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
          style: tt.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: outline.withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              children: [
                for (var i = 0; i < tiles.length; i++)
                  Expanded(
                    child: Tooltip(
                      message: tiles[i].label,
                      child: AspectRatio(
                        aspectRatio: 1.12,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: tiles[i].color,
                            border: Border(
                              right: i < tiles.length - 1
                                  ? BorderSide(
                                      color: outline.withValues(alpha: 0.35),
                                    )
                                  : BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
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
    const thumbR = 11.0;
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final trackW = (w - 2 * thumbR).clamp(0.0, double.infinity);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hue',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm - 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: thumbR),
                  child: SizedBox(
                    height: 28,
                    width: trackW,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _HueGradientPainter(),
                          ),
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 28,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: thumbR,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 16,
                            ),
                          ),
                          child: Slider(
                            value: hsv.hue.clamp(0, 359.99),
                            max: 359.99,
                            onChanged: onChanged,
                          ),
                        ),
                      ],
                    ),
                  ),
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
  /// Full HSV hue sweep (0°→360°): red → yellow → green → cyan → blue → magenta → red.
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    const steps = 6;
    final colors = <Color>[];
    for (var i = 0; i <= steps; i++) {
      final h = (i * 60.0) % 360.0;
      colors.add(HSVColor.fromAHSV(1, h, 1, 1).toColor());
    }
    final shader = LinearGradient(
      colors: colors,
      stops: List<double>.generate(
        colors.length,
        (i) => i / (colors.length - 1),
      ),
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = shader);
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
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: AppSpacing.xs),
        AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (context, c) {
              final sz = c.maxWidth;
              final outline = Theme.of(context).colorScheme.outlineVariant;
              return GestureDetector(
                onPanDown: (d) => _handle(d.localPosition, sz),
                onPanUpdate: (d) => _handle(d.localPosition, sz),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: outline.withValues(alpha: 0.55),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md - 1),
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
                              isDark: Theme.of(context).brightness ==
                                  Brightness.dark,
                            ),
                          ),
                        ],
                      ),
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
  _SVIndicatorPainter({
    required this.saturation,
    required this.value,
    required this.isDark,
  });

  final double saturation;
  final double value;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final x = saturation * size.width;
    final y = (1 - value) * size.height;
    final outer = Paint()
      ..color = isDark ? const Color(0xFFE2E8F0) : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final inner = Paint()
      ..color = Colors.black.withValues(alpha: isDark ? 0.5 : 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(Offset(x, y), 10, outer);
    canvas.drawCircle(Offset(x, y), 9, inner);
  }

  @override
  bool shouldRepaint(covariant _SVIndicatorPainter oldDelegate) =>
      oldDelegate.saturation != saturation ||
      oldDelegate.value != value ||
      oldDelegate.isDark != isDark;
}

class _AlphaSlider extends StatelessWidget {
  const _AlphaSlider({required this.hsv, required this.onChanged});

  final HSVColor hsv;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    const thumbR = 11.0;
    final cs = Theme.of(context).colorScheme;
    final base = hsv.toColor().withValues(alpha: 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Opacity',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final w = c.maxWidth;
                  final trackW = (w - 2 * thumbR).clamp(0.0, double.infinity);
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.55),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm - 1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: thumbR),
                        child: SizedBox(
                          height: 28,
                          width: trackW,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _CheckerboardPainter(),
                                ),
                              ),
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        base.withValues(alpha: 0),
                                        base,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 28,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: thumbR,
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
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 40,
              child: Text(
                '${(hsv.alpha * 100).round()}%',
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
            ),
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
