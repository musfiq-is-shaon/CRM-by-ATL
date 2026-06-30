import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:image_picker/image_picker.dart';

/// Continuous multi-page camera capture for business cards (front, back, …).
class BusinessCardMultiCapturePage extends StatefulWidget {
  const BusinessCardMultiCapturePage({super.key, this.maxPages = 5});

  final int maxPages;

  @override
  State<BusinessCardMultiCapturePage> createState() =>
      _BusinessCardMultiCapturePageState();
}

class _BusinessCardMultiCapturePageState
    extends State<BusinessCardMultiCapturePage> {
  static final ImagePicker _picker = ImagePicker();

  final List<XFile> _pages = [];
  bool _busy = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _captureNext());
  }

  void _finish() {
    if (_pages.isEmpty) {
      Navigator.pop(context);
    } else {
      Navigator.pop(context, List<XFile>.from(_pages));
    }
  }

  Future<void> _captureNext() async {
    if (_busy || !mounted) return;
    if (_pages.length >= widget.maxPages) {
      _finish();
      return;
    }

    if (!_started) _started = true;
    setState(() => _busy = true);

    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 92,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (!mounted) return;

      if (file == null) {
        setState(() => _busy = false);
        // On iOS a failed re-present can look like cancel; keep captured pages.
        if (_pages.isEmpty) {
          _finish();
        }
        return;
      }

      setState(() {
        _pages.add(file);
        _busy = false;
      });

      if (_pages.length >= widget.maxPages) {
        _finish();
        return;
      }

      await _scheduleNextCapture();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      if (_pages.isEmpty) {
        _finish();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open the camera again. Tap Capture to try the next page.',
          ),
        ),
      );
    }
  }

  /// iOS UIImagePickerController must fully dismiss before it can be shown again.
  Future<void> _scheduleNextCapture() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
    } else {
      await SchedulerBinding.instance.endOfFrame;
    }
    if (!mounted || _busy) return;
    await _captureNext();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pageCount = _pages.length;
    final nextPage = pageCount + 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          pageCount == 0
              ? 'Scan business card'
              : 'Page $pageCount captured',
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _finish,
        ),
        actions: [
          if (pageCount > 0 && !_busy)
            TextButton(
              onPressed: _finish,
              child: const Text('Done'),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                pageCount == 0
                    ? 'Page 1 of up to ${widget.maxPages}'
                    : 'Capture page $nextPage or tap Done',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Photograph each side of the card. After each shot the camera '
                'opens again until you tap Done or reach ${widget.maxPages} pages.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              if (_pages.isNotEmpty)
                SizedBox(
                  height: 88,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _pages.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      return Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(_pages[index].path),
                              width: 120,
                              height: 68,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Page ${index + 1}',
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              const Spacer(),
              if (_busy) ...[
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 16),
                Text(
                  pageCount == 0
                      ? 'Opening camera…'
                      : 'Opening camera for page $nextPage…',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ] else if (pageCount > 0) ...[
                FilledButton.icon(
                  onPressed: _captureNext,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text('Capture page $nextPage'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _finish,
                  child: Text('Done with $pageCount page${pageCount == 1 ? '' : 's'}'),
                ),
              ] else
                const Center(child: CircularProgressIndicator()),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
