import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

/// Renders the bundled FIFA Trionda GLB (`assets/models/fifa_trionda_ball.glb`).
class FifaTriondaBallView extends StatefulWidget {
  const FifaTriondaBallView({
    super.key,
    required this.size,
    required this.backgroundColor,
    this.onReady,
  });

  static const modelAsset = 'assets/models/fifa_trionda_ball.glb';

  final double size;
  final Color backgroundColor;
  final VoidCallback? onReady;

  @override
  State<FifaTriondaBallView> createState() => _FifaTriondaBallViewState();
}

class _FifaTriondaBallViewState extends State<FifaTriondaBallView> {
  bool _modelReady = false;

  static const _hideChromeCss = '''
model-viewer {
  --progress-bar-height: 0px;
  --progress-bar-color: transparent;
  background-color: transparent !important;
}
#default-progress-bar,
.slot.progress-bar {
  display: none !important;
}
''';

  static const _loadListenerJs = '''
document.addEventListener('DOMContentLoaded', () => {
  customElements.whenDefined('model-viewer').then(() => {
    const el = document.querySelector('model-viewer');
    if (!el) return;
    const notify = () => ModelReady.postMessage('loaded');
    if (el.loaded) notify();
    else el.addEventListener('load', notify, { once: true });
  });
});
''';

  void _markReady() {
    if (_modelReady || !mounted) return;
    setState(() => _modelReady = true);
    widget.onReady?.call();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          ClipOval(
            child: ModelViewer(
              src: FifaTriondaBallView.modelAsset,
              alt: 'FIFA Trionda World Cup 2026 football',
              backgroundColor: Colors.transparent,
              ar: false,
              autoRotate: false,
              autoPlay: true,
              cameraControls: false,
              disableZoom: true,
              disablePan: true,
              disableTap: true,
              touchAction: TouchAction.none,
              interactionPrompt: InteractionPrompt.none,
              loading: Loading.eager,
              reveal: Reveal.auto,
              cameraOrbit: '0deg 76deg 128%',
              fieldOfView: '34deg',
              shadowIntensity: 0,
              shadowSoftness: 0,
              exposure: 1.08,
              relatedCss: _hideChromeCss,
              relatedJs: _loadListenerJs,
              debugLogging: false,
              javascriptChannels: {
                JavascriptChannel(
                  'ModelReady',
                  onMessageReceived: (message) {
                    if (message.message == 'loaded') _markReady();
                  },
                ),
              },
            ),
          ),
          if (!_modelReady)
            Positioned.fill(
              child: ClipOval(
                child: ColoredBox(color: widget.backgroundColor),
              ),
            ),
        ],
      ),
    );
  }
}
